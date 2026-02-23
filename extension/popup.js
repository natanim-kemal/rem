let currentPriority = 'medium';
let pageData = { title: '', url: '', description: '', thumbnailUrl: '' };
let authState = { token: null, convexUrl: null };
let cryptoKey = null;

const ENCRYPTION_KEY_NAME = 'rem_encryption_key';

async function migrateFromSyncStorage() {
    const syncStorage = await chrome.storage.sync.get(['authToken', 'convexUrl']);
    const localStorage = await chrome.storage.local.get(['authToken', 'convexUrl']);
    
    if (syncStorage.authToken && !localStorage.authToken) {
        const encryptedToken = await encryptToken(syncStorage.authToken);
        await chrome.storage.local.set({ authToken: encryptedToken });
        await chrome.storage.sync.remove(['authToken']);
    }
    
    if (syncStorage.convexUrl && !localStorage.convexUrl) {
        await chrome.storage.local.set({ convexUrl: syncStorage.convexUrl });
        await chrome.storage.sync.remove(['convexUrl']);
    }
}

async function getOrCreateEncryptionKey() {
    if (cryptoKey) return cryptoKey;
    
    const stored = await chrome.storage.local.get([ENCRYPTION_KEY_NAME]);
    
    if (stored[ENCRYPTION_KEY_NAME]) {
        const keyData = Uint8Array.from(atob(stored[ENCRYPTION_KEY_NAME]), c => c.charCodeAt(0));
        cryptoKey = await crypto.subtle.importKey(
            'raw',
            keyData,
            { name: 'AES-GCM' },
            false,
            ['encrypt', 'decrypt']
        );
        return cryptoKey;
    }
    
    cryptoKey = await crypto.subtle.generateKey(
        { name: 'AES-GCM', length: 256 },
        true,
        ['encrypt', 'decrypt']
    );
    
    const exportedKey = await crypto.subtle.exportKey('raw', cryptoKey);
    const keyBase64 = btoa(String.fromCharCode(...new Uint8Array(exportedKey)));
    await chrome.storage.local.set({ [ENCRYPTION_KEY_NAME]: keyBase64 });
    
    return cryptoKey;
}

async function encryptToken(token) {
    if (!token) return null;
    const key = await getOrCreateEncryptionKey();
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const encoder = new TextEncoder();
    const data = encoder.encode(token);
    
    const encrypted = await crypto.subtle.encrypt(
        { name: 'AES-GCM', iv: iv },
        key,
        data
    );
    
    const combined = new Uint8Array(iv.length + encrypted.byteLength);
    combined.set(iv, 0);
    combined.set(new Uint8Array(encrypted), iv.length);
    
    return btoa(String.fromCharCode(...combined));
}

async function decryptToken(encryptedToken) {
    if (!encryptedToken) return null;
    try {
        const key = await getOrCreateEncryptionKey();
        const combined = Uint8Array.from(atob(encryptedToken), c => c.charCodeAt(0));
        
        const iv = combined.slice(0, 12);
        const data = combined.slice(12);
        
        const decrypted = await crypto.subtle.decrypt(
            { name: 'AES-GCM', iv: iv },
            key,
            data
        );
        
        const decoder = new TextDecoder();
        return decoder.decode(decrypted);
    } catch (e) {
        return null;
    }
}

const views = {
    main: document.getElementById('main-view'),
    auth: document.getElementById('auth-view'),
    settings: document.getElementById('settings-view'),
    success: document.getElementById('success-view'),
    pairing: document.getElementById('pairing-view'),
};

let pairingInterval = null;
let currentPairingCode = null;

function showToast(message) {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.classList.add('show');
    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
}

document.addEventListener('DOMContentLoaded', async () => {
    await initializeExtension();
    setupEventListeners();
});

async function initializeExtension() {
    await migrateFromSyncStorage();
    
    const storage = await chrome.storage.local.get(['authToken', 'convexUrl']);
    authState.convexUrl = storage.convexUrl || null;
    authState.token = storage.authToken ? await decryptToken(storage.authToken) : null;

    if (!authState.convexUrl) {
        showView('settings');
        loadSettings();
        return;
    }

    if (!authState.token) {
        showView('auth');
        return;
    }

    const result = await verifyAuthToken();
    if (!result.success) {
        showView('auth');
        return;
    }

    await loadPageInfo();
    showView('main');
}

async function verifyAuthToken() {
    try {
        const response = await fetch(`${authState.convexUrl}/api/query`, {
            method: 'POST',
            headers: { 
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authState.token}`
            },
            body: JSON.stringify({
                path: 'users:getCurrentUser',
                args: {}
            })
        });

        const text = await response.text();
        if (!text) {
            return { success: false, message: "Empty response" };
        }

        const data = JSON.parse(text);

        if (data.status === 'success' && data.value) {
            return { success: true, data: data.value };
        }

        return { success: false, message: "User not found" };
    } catch (error) {
        return { success: false, message: error.message };
    }
}

async function loadPageInfo() {
    try {
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

        const isInternalPage = !tab || !tab.url ||
            tab.url.startsWith('chrome://') ||
            tab.url.startsWith('edge://') ||
            tab.url.startsWith('about:') ||
            tab.url.startsWith('chrome-extension://');

        if (isInternalPage) {
            document.getElementById('page-title').textContent = 'Restricted Page';
            document.getElementById('page-url').textContent = 'Browser settings and internal pages cannot be saved.';
            document.getElementById('save-btn').disabled = true;
            return;
        }

        pageData = {
            title: cleanTitle(tab.title) || 'Untitled',
            url: tab.url,
            description: '',
            thumbnailUrl: '',
        };

        document.getElementById('page-title').textContent = pageData.title;
        document.getElementById('page-url').textContent = new URL(pageData.url).hostname;

        fetchMetadata(tab.url).then(metadata => {
            if (metadata) {
                if (metadata.title) {
                    pageData.title = metadata.title;
                    document.getElementById('page-title').textContent = metadata.title;
                }
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
        if (!url.startsWith('http')) return null;

        const isTikTok = url.includes('tiktok.com') || url.includes('vm.tiktok.com') || url.includes('vt.tiktok.com');
        const isX = url.includes('x.com') || url.includes('twitter.com') || url.includes('mobile.twitter.com');

        let title = '';
        let thumbnailUrl = '';
        let description = '';

        if (isTikTok) {
            const oembedUrl = `https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`;
            try {
                const oembedResp = await fetch(oembedUrl);
                if (oembedResp.ok) {
                    const oembedData = await oembedResp.json();
                    title = oembedData.title || '';
                    thumbnailUrl = oembedData.thumbnail_url || '';
                }
            } catch (e) {}
        } else if (isX) {
            const oembedUrl = `https://publish.twitter.com/oembed?url=${encodeURIComponent(url)}`;
            try {
                const oembedResp = await fetch(oembedUrl);
                if (oembedResp.ok) {
                    const oembedData = await oembedResp.json();
                    title = oembedData.title || '';
                }
            } catch (e) {}
        }

        if (!title) {
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

            const metadataTitle = getMeta('title') || getMeta('og:title') || getMeta('twitter:title') || doc.title || '';
            description = getMeta('description') || getMeta('og:description');
            
            if (!thumbnailUrl) {
                thumbnailUrl = getMeta('image') || getMeta('og:image') || getMeta('twitter:image');
            }

            if (isTikTok) {
                title = metadataTitle;
            } else if (isX) {
                title = pickXTitle(metadataTitle, description, html);
            } else {
                title = metadataTitle;
            }

            if (title && !isGenericTitle(title, isX)) {
                title = stripHashtags(title);
            } else {
                title = '';
            }
        }

        return {
            title: cleanTitle(title),
            description: description.slice(0, 500),
            thumbnailUrl: resolveUrl(thumbnailUrl, url),
        };
    } catch (error) {
        return null;
    }
}

function resolveUrl(relativeUrl, baseUrl) {
    if (!relativeUrl) return '';
    if (relativeUrl.startsWith('http')) return relativeUrl;
    try {
        return new URL(relativeUrl, baseUrl).href;
    } catch {
        return '';
    }
}

function pickXTitle(title, description, html) {
    const trimmedTitle = (title || '').trim();
    if (trimmedTitle && !isGenericXTitle(trimmedTitle.toLowerCase())) {
        return trimmedTitle;
    }
    
    const htmlText = extractXPostText(html);
    if (htmlText) {
        return takeWords(htmlText, 5);
    }
    
    const trimmedDesc = (description || '').trim();
    if (trimmedDesc) {
        return takeWords(trimmedDesc, 5);
    }
    
    return '';
}

function extractXPostText(html) {
    if (!html) return null;
    const match = html.match(/<p[^>]*>([\s\S]*?)<\/p>/);
    if (!match) return null;
    const raw = match[1] || '';
    const noTags = raw.replace(/<[^>]+>/g, ' ');
    const normalized = noTags.replace(/\s+/g, ' ').trim();
    return normalized;
}

function isGenericTitle(title, isX) {
    const normalized = (title || '').trim().toLowerCase();
    if (!normalized) return true;
    if (normalized === 'tiktok - make your day' || normalized === 'tiktok' || normalized === 'make your day') return true;
    if (isX && isGenericXTitle(normalized)) return true;
    return false;
}

function isGenericXTitle(title) {
    return title === 'x' || title === 'twitter' || title === 'x / twitter' || title === 'twitter / x';
}

function takeWords(text, count) {
    if (!text) return '';
    const words = text.split(/\s+/);
    return words.slice(0, count).join(' ').trim();
}

function stripHashtags(title) {
    const trimmed = (title || '').trim();
    if (!trimmed) return '';
    const parts = trimmed.split(/\s+/);
    const kept = parts.filter(part => !part.startsWith('#'));
    return kept.join(' ').trim();
}

function cleanTitle(title) {
    if (!title) return '';
    
    let cleaned = title.trim();
    
    const separators = [' | ', ' - ', ' — ', ' :: ', ' « ', ' » '];
    for (const sep of separators) {
        const idx = cleaned.lastIndexOf(sep);
        if (idx > 10) {
            cleaned = cleaned.substring(0, idx);
            break;
        }
    }
    
    cleaned = cleaned.replace(/[|\-—:»«]$/, '').trim();
    
    if (cleaned.length > 100) {
        cleaned = cleaned.substring(0, 100);
    }
    
    return cleaned;
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

    document.getElementById('show-manual-input')?.addEventListener('click', () => {
        document.getElementById('manual-url-section').classList.remove('hidden');
        document.getElementById('manual-toggle').classList.add('hidden');
        document.getElementById('manual-url-input').focus();
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

    document.getElementById('link-device-btn')?.addEventListener('click', startPairing);

    document.getElementById('cancel-pairing-btn')?.addEventListener('click', () => {
        stopPolling();
        showView('auth');
    });
}

function showView(viewName) {
    Object.values(views).forEach(view => view.classList.add('hidden'));
    views[viewName].classList.remove('hidden');
}

function loadSettings() {
    const convexUrlInput = document.getElementById('convex-url');
    if (convexUrlInput) convexUrlInput.value = authState.convexUrl || '';
}

async function saveSettings() {
    const convexUrlInput = document.getElementById('convex-url');

    if (!convexUrlInput) {
        showToast('Settings form not loaded correctly');
        return;
    }

    const convexUrl = convexUrlInput.value.trim();

    if (!convexUrl) {
        showToast('Please enter a Convex URL');
        return;
    }

    try {
        new URL(convexUrl);
    } catch {
        showToast('Please enter a valid Convex URL');
        return;
    }

    await chrome.storage.local.set({
        convexUrl: convexUrl,
    });

    authState.convexUrl = convexUrl;
    
    showView('auth');
}

async function saveItem() {
    const saveBtn = document.getElementById('save-btn');
    const originalText = saveBtn.innerHTML;

    saveBtn.disabled = true;
    saveBtn.innerHTML = '<span class="spinner"></span> Saving...';

    try {
        const manualUrlInput = document.getElementById('manual-url-input');
        const manualUrl = manualUrlInput?.value.trim();
        
        const urlToSave = manualUrl || pageData.url;
        const titleToSave = manualUrl ? manualUrl : pageData.title;

        if (!urlToSave) {
            throw new Error("No URL to save");
        }

        const type = detectContentType(urlToSave);

        const payload = {
            url: urlToSave,
            title: titleToSave,
            description: pageData.description || undefined,
            thumbnailUrl: pageData.thumbnailUrl || undefined,
            type: type,
            priority: currentPriority,
            tags: [],
        };

        const response = await fetch(`${authState.convexUrl}/api/mutation`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authState.token}`,
            },
            body: JSON.stringify({
                path: 'items:createItem',
                args: payload
            })
        });

        const data = await response.json();

        if (data.status === 'success') {
            showView('success');
            setTimeout(() => window.close(), 2000);
            return;
        }

        throw new Error(data.errorMessage || 'Failed to save');

    } catch (error) {
        saveBtn.disabled = false;
        saveBtn.innerHTML = originalText;
        showToast(`Failed to save: ${error.message}`);
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

function generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 8; i++) {
        if (i === 4) code += '-';
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
}

async function startPairing() {
    if (!authState.convexUrl) {
        showToast("Please set up Convex URL in Settings first.");
        showView('settings');
        loadSettings();
        return;
    }

    showView('pairing');
    
    currentPairingCode = generateCode();
    document.getElementById('pairing-code').textContent = currentPairingCode;
    document.getElementById('pairing-status').textContent = 'Waiting for approval...';
    
    startPolling();
}

function startPolling() {
    if (!authState.convexUrl) {
        document.getElementById('pairing-status').textContent = 'Error: Convex URL not set.';
        return;
    }

    if (pairingInterval) clearInterval(pairingInterval);
    
    pairingInterval = setInterval(async () => {
        if (!currentPairingCode) return;

        try {
            const response = await fetch(`${authState.convexUrl}/api/query`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    path: 'pairing:getPairingStatus',
                    args: { code: currentPairingCode }
                })
            });

            if (!response.ok) {
                document.getElementById('pairing-status').textContent = 'Connection error: ' + response.status;
                return;
            }

            const data = await response.json();

            if (data.status === 'success' && data.value) {
                const status = data.value.status;
                const token = data.value.token;

                if (status === 'approved' && token) {
                    stopPolling();
                    document.getElementById('pairing-status').textContent = 'Approved! Linking...';
                    await saveTokenAndLogin(token);
                } else if (status === 'expired') {
                    stopPolling();
                    document.getElementById('pairing-status').textContent = 'Code expired.';
                    setTimeout(() => showView('auth'), 2000);
                }
            }
        } catch (e) {
        }
    }, 2000);
}

function stopPolling() {
    if (pairingInterval) {
        clearInterval(pairingInterval);
        pairingInterval = null;
    }
    currentPairingCode = null;
}

async function saveTokenAndLogin(token) {
    try {
        const encryptedToken = await encryptToken(token);
        await chrome.storage.local.set({ authToken: encryptedToken });
        authState.token = token;
        
        for (let i = 0; i < 3; i++) {
            const result = await verifyAuthToken();
            
            if (result.success) {
                document.getElementById('pairing-status').textContent = 'Linked Successfully!';
                await new Promise(r => setTimeout(r, 1000));
                await initializeExtension();
                return;
            }
            
            if (i < 2) {
                await new Promise(r => setTimeout(r, 2000));
            }
        }
        
        showToast("Link failed: Could not verify user.");
        showView('auth');
    } catch (e) {
        showToast("Error saving token: " + e.message);
        showView('auth');
    }
}
