let currentPriority = 'medium';
let pageData = { title: '', url: '', description: '', thumbnailUrl: '' };
let authState = { token: null, convexUrl: null };

const views = {
    main: document.getElementById('main-view'),
    auth: document.getElementById('auth-view'),
    settings: document.getElementById('settings-view'),
    success: document.getElementById('success-view'),
};

document.addEventListener('DOMContentLoaded', async () => {
    await initializeExtension();
    setupEventListeners();
});

async function initializeExtension() {
    const storage = await chrome.storage.sync.get(['authToken', 'convexUrl']);
    authState.token = storage.authToken || null;
    authState.convexUrl = storage.convexUrl || null;

    if (!authState.token || !authState.convexUrl) {
        showView('auth');
        return;
    }

    const isValid = await verifyAuthToken();
    if (!isValid) {
        showView('auth');
        return;
    }

    await loadPageInfo();
    showView('main');
}

async function verifyAuthToken() {
    try {
        const response = await fetch(`${authState.convexUrl}/api/me`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${authState.token}`,
            },
        });
        return response.ok;
    } catch (error) {
        return false;
    }
}

async function loadPageInfo() {
    try {
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

        if (!tab || !tab.url || tab.url.startsWith('chrome://') || tab.url.startsWith('chrome-extension://')) {
            document.getElementById('page-title').textContent = 'No page available';
            document.getElementById('page-url').textContent = 'Navigate to a webpage to save it';
            document.getElementById('save-btn').disabled = true;
            return;
        }

        pageData = {
            title: tab.title || 'Untitled',
            url: tab.url,
            description: '',
            thumbnailUrl: '',
        };

        document.getElementById('page-title').textContent = pageData.title;
        document.getElementById('page-url').textContent = new URL(pageData.url).hostname;

        fetchMetadata(tab.url).then(metadata => {
            if (metadata) {
                pageData.description = metadata.description || '';
                pageData.thumbnailUrl = metadata.thumbnailUrl || '';
            }
        });
    } catch (error) {
        document.getElementById('page-title').textContent = 'Unknown page';
    }
}

async function fetchMetadata(url) {
    try {
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                'Accept': 'text/html',
            },
        });

        if (!response.ok) return null;

        const html = await response.text();
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, 'text/html');

        const getMeta = (name) => {
            const meta = doc.querySelector(`meta[name="${name}"], meta[property="og:${name}"], meta[property="twitter:${name}"]`);
            return meta?.getAttribute('content') || '';
        };

        const description = getMeta('description') || getMeta('og:description');
        const thumbnailUrl = getMeta('image') || getMeta('og:image') || getMeta('twitter:image');

        const resolveUrl = (relativeUrl) => {
            if (!relativeUrl) return '';
            if (relativeUrl.startsWith('http')) return relativeUrl;
            try {
                return new URL(relativeUrl, url).href;
            } catch {
                return '';
            }
        };

        return {
            description: description.slice(0, 500),
            thumbnailUrl: resolveUrl(thumbnailUrl),
        };
    } catch (error) {
        return null;
    }
}

function setupEventListeners() {
    document.querySelectorAll('.priority-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.priority-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            currentPriority = btn.dataset.priority;
        });
    });

    document.getElementById('save-btn')?.addEventListener('click', saveItem);

    document.getElementById('auth-btn')?.addEventListener('click', () => {
        chrome.tabs.create({ url: 'https://rem.app/auth' });
    });

    document.getElementById('open-settings')?.addEventListener('click', () => {
        showView('settings');
        loadSettings();
    });

    document.getElementById('back-btn')?.addEventListener('click', () => {
        if (authState.token && authState.convexUrl) {
            showView('main');
        } else {
            showView('auth');
        }
    });

    document.getElementById('save-settings-btn')?.addEventListener('click', saveSettings);
}

function showView(viewName) {
    Object.values(views).forEach(view => view.classList.add('hidden'));
    views[viewName].classList.remove('hidden');
}

function loadSettings() {
    document.getElementById('convex-url').value = authState.convexUrl || '';
    document.getElementById('auth-token').value = authState.token || '';
}

async function saveSettings() {
    const convexUrl = document.getElementById('convex-url').value.trim();
    const authToken = document.getElementById('auth-token').value.trim();

    if (!convexUrl || !authToken) {
        alert('Please enter both Convex URL and Auth Token');
        return;
    }

    try {
        new URL(convexUrl);
    } catch {
        alert('Please enter a valid Convex URL');
        return;
    }

    await chrome.storage.sync.set({
        convexUrl: convexUrl,
        authToken: authToken,
    });

    authState.convexUrl = convexUrl;
    authState.token = authToken;

    const isValid = await verifyAuthToken();
    if (isValid) {
        showView('main');
        await loadPageInfo();
    } else {
        alert('Authentication failed. Please check your credentials.');
    }
}

async function saveItem() {
    const saveBtn = document.getElementById('save-btn');
    const originalText = saveBtn.innerHTML;

    saveBtn.disabled = true;
    saveBtn.innerHTML = '<span class="spinner"></span> Saving...';

    try {
        const type = detectContentType(pageData.url);

        const payload = {
            url: pageData.url,
            title: pageData.title,
            description: pageData.description || undefined,
            thumbnailUrl: pageData.thumbnailUrl || undefined,
            type: type,
            priority: currentPriority,
            tags: [],
        };

        const response = await fetch(`${authState.convexUrl}/api/items`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authState.token}`,
            },
            body: JSON.stringify(payload),
        });

        if (response.status === 401) {
            showView('auth');
            return;
        }

        if (response.status === 409) {
            alert('This URL is already in your vault.');
            saveBtn.disabled = false;
            saveBtn.innerHTML = originalText;
            return;
        }

        if (!response.ok) {
            const error = await response.json().catch(() => ({ error: 'Unknown error' }));
            throw new Error(error.error || `HTTP ${response.status}`);
        }

        showView('success');

        setTimeout(() => window.close(), 2000);

    } catch (error) {
        saveBtn.disabled = false;
        saveBtn.innerHTML = originalText;
        alert(`Failed to save: ${error.message}`);
    }
}

function detectContentType(url) {
    const urlLower = url.toLowerCase();

    if (/\.(jpg|jpeg|png|gif|webp|svg|bmp|ico)(\?.*)?$/i.test(urlLower)) {
        return 'image';
    }

    if (/\.(mp4|webm|ogg|mov|avi|mkv)(\?.*)?$/i.test(urlLower)) {
        return 'video';
    }

    if (/youtube\.com|youtu\.be|vimeo\.com|tiktok\.com|instagram\.com\/reels?/i.test(urlLower)) {
        return 'video';
    }

    if (/amazon\.com.*\/dp\/|goodreads\.com|books\.google/i.test(urlLower)) {
        return 'book';
    }

    if (/unsplash\.com|pexels\.com|imgur\.com|giphy\.com/i.test(urlLower)) {
        return 'image';
    }

    return 'link';
}
