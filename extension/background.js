const CONFIG = {
    API_ENDPOINTS: {
        items: '/api/items',
        me: '/api/me',
    },
};

chrome.runtime.onInstalled.addListener((details) => {
    setupContextMenus();
});

function setupContextMenus() {
    chrome.contextMenus.removeAll(() => {
        chrome.contextMenus.create({
            id: 'save-to-rem',
            title: 'Save to rem',
            contexts: ['page', 'link', 'image', 'selection'],
        });

        chrome.contextMenus.create({
            id: 'save-high',
            parentId: 'save-to-rem',
            title: 'High Priority',
            contexts: ['page', 'link', 'image'],
        });

        chrome.contextMenus.create({
            id: 'save-medium',
            parentId: 'save-to-rem',
            title: 'Medium Priority',
            contexts: ['page', 'link', 'image'],
        });

        chrome.contextMenus.create({
            id: 'save-low',
            parentId: 'save-to-rem',
            title: 'Low Priority',
            contexts: ['page', 'link', 'image'],
        });

        chrome.contextMenus.create({
            id: 'separator-1',
            parentId: 'save-to-rem',
            type: 'separator',
            contexts: ['page', 'link', 'image'],
        });

        chrome.contextMenus.create({
            id: 'save-selection',
            parentId: 'save-to-rem',
            title: 'Save as Note',
            contexts: ['selection'],
        });
    });
}

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
    let priority = 'medium';
    let type = 'link';
    let url = info.pageUrl;
    let title = tab?.title || 'Untitled';
    let description = '';

    if (info.menuItemId === 'save-high') priority = 'high';
    else if (info.menuItemId === 'save-medium') priority = 'medium';
    else if (info.menuItemId === 'save-low') priority = 'low';

    if (info.menuItemId === 'save-selection') {
        type = 'note';
        title = `Note from ${new URL(tab.url).hostname}`;
        description = info.selectionText?.slice(0, 1000) || '';
        url = undefined;
    } else if (info.linkUrl) {
        url = info.linkUrl;
        title = info.linkText || url;
        type = detectContentType(url);
    } else if (info.srcUrl) {
        url = info.srcUrl;
        title = 'Image';
        type = info.mediaType === 'image' ? 'image' : detectContentType(url);
    }

    showBadge('...', '#6B7280');

    try {
        await saveToRem({
            url,
            title,
            description,
            type,
            priority,
        });
        showBadge('ok', '#2FBF9A');
    } catch (error) {
        showBadge('!', '#FF3B30');
    }

    setTimeout(() => {
        chrome.action.setBadgeText({ text: '' });
    }, 2000);
});

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'SAVE_ITEM') {
        saveToRem({
            url: message.url,
            title: message.title,
            description: message.description,
            thumbnailUrl: message.thumbnailUrl,
            type: message.contentType || 'link',
            priority: message.priority || 'medium',
            tags: message.tags || [],
        })
            .then(result => sendResponse({ success: true, data: result }))
            .catch(error => sendResponse({ success: false, error: error.message }));
        return true;
    }

    if (message.type === 'FETCH_METADATA') {
        fetchMetadata(message.url)
            .then(metadata => sendResponse({ success: true, metadata }))
            .catch(error => sendResponse({ success: false, error: error.message }));
        return true;
    }
});

async function saveToRem(itemData) {
    const { authToken, convexUrl } = await chrome.storage.sync.get(['authToken', 'convexUrl']);

    if (!authToken || !convexUrl) {
        throw new Error('Not authenticated. Please configure the extension.');
    }

    const payload = {
        url: itemData.url,
        title: itemData.title,
        description: itemData.description,
        thumbnailUrl: itemData.thumbnailUrl,
        type: itemData.type,
        priority: itemData.priority || 'medium',
        tags: itemData.tags || [],
    };

    Object.keys(payload).forEach(key => {
        if (payload[key] === undefined) delete payload[key];
    });

    const response = await fetch(`${convexUrl}${CONFIG.API_ENDPOINTS.items}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${authToken}`,
        },
        body: JSON.stringify(payload),
    });

    if (response.status === 401) {
        throw new Error('Authentication expired. Please sign in again.');
    }

    if (response.status === 409) {
        throw new Error('This item is already in your vault.');
    }

    if (!response.ok) {
        const error = await response.json().catch(() => ({ error: 'Unknown error' }));
        throw new Error(error.error || `Server error: ${response.status}`);
    }

    return await response.json();
}

async function fetchMetadata(url) {
    try {
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                'Accept': 'text/html, application/xhtml+xml, application/xml;q=0.9, */*;q=0.8',
            },
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const html = await response.text();
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, 'text/html');

        const getMeta = (selectors) => {
            for (const selector of selectors) {
                const el = doc.querySelector(selector);
                if (el?.getAttribute('content')) {
                    return el.getAttribute('content');
                }
            }
            return '';
        };

        const title = getMeta([
            'meta[property="og:title"]',
            'meta[name="twitter:title"]',
            'meta[property="twitter:title"]',
        ]) || doc.title || '';

        const description = getMeta([
            'meta[name="description"]',
            'meta[property="og:description"]',
            'meta[name="twitter:description"]',
            'meta[property="twitter:description"]',
        ]);

        let thumbnailUrl = getMeta([
            'meta[property="og:image:secure_url"]',
            'meta[property="og:image"]',
            'meta[name="twitter:image"]',
            'meta[property="twitter:image"]',
            'meta[name="thumbnail"]',
        ]);

        if (thumbnailUrl && !thumbnailUrl.startsWith('http')) {
            try {
                thumbnailUrl = new URL(thumbnailUrl, url).href;
            } catch {
                thumbnailUrl = '';
            }
        }

        return {
            title: title.slice(0, 200),
            description: description.slice(0, 500),
            thumbnailUrl: thumbnailUrl.slice(0, 1000),
        };
    } catch (error) {
        return null;
    }
}

function detectContentType(url) {
    if (!url) return 'link';

    const urlLower = url.toLowerCase();
    const pathname = new URL(url).pathname.toLowerCase();

    const imageExts = /\.(jpg|jpeg|png|gif|webp|svg|bmp|ico|avif)(\?.*)?$/i;
    const imageHosts = /unsplash\.com|pexels\.com|imgur\.com|giphy\.com|cloudinary\.com/i;

    if (imageExts.test(pathname) || imageHosts.test(urlLower)) {
        return 'image';
    }

    const videoExts = /\.(mp4|webm|ogg|ogv|mov|mkv|avi)(\?.*)?$/i;
    const videoHosts = /youtube\.com|youtu\.be|vimeo\.com|tiktok\.com|twitch\.tv/i;
    const videoPaths = /\/video\/|\/watch\/|\/embed\/|\/player\//i;

    if (videoExts.test(pathname) || videoHosts.test(urlLower) || videoPaths.test(pathname)) {
        return 'video';
    }

    const bookHosts = /amazon\.com|goodreads\.com|books\.google|openlibrary\.org|gutenberg\.org/i;
    const bookPaths = /\/dp\/|\/book\/|\/isbn\/|\/title\//i;

    if (bookHosts.test(urlLower) || bookPaths.test(pathname)) {
        return 'book';
    }

    return 'link';
}

function showBadge(text, color) {
    chrome.action.setBadgeText({ text });
    chrome.action.setBadgeBackgroundColor({ color });
}

chrome.commands?.onCommand?.addListener((command) => {
    if (command === 'save-current-page') {
        chrome.tabs.query({ active: true, currentWindow: true }, async (tabs) => {
            const tab = tabs[0];
            if (!tab || tab.url?.startsWith('chrome://')) return;

            showBadge('...', '#6B7280');

            try {
                await saveToRem({
                    url: tab.url,
                    title: tab.title,
                    type: detectContentType(tab.url),
                    priority: 'medium',
                });
                showBadge('ok', '#2FBF9A');
            } catch (error) {
                showBadge('!', '#FF3B30');
            }

            setTimeout(() => {
                chrome.action.setBadgeText({ text: '' });
            }, 2000);
        });
    }
});
