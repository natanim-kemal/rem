// REM Browser Extension - Background Service Worker

// Context menu for right-click save
chrome.runtime.onInstalled.addListener(() => {
    chrome.contextMenus.create({
        id: 'save-to-rem',
        title: 'Save to REM',
        contexts: ['page', 'link', 'image']
    });
});

// Handle context menu clicks
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
    if (info.menuItemId === 'save-to-rem') {
        const url = info.linkUrl || info.srcUrl || info.pageUrl;
        const title = tab?.title || 'Saved from context menu';

        await saveToRem(url, title, detectType(info));
    }
});

// Detect content type from context
function detectType(info) {
    if (info.srcUrl && info.mediaType === 'image') return 'image';
    if (info.srcUrl && info.mediaType === 'video') return 'video';
    return 'link';
}

// Save to REM via Convex HTTP
async function saveToRem(url, title, type) {
    try {
        const { authToken, convexUrl } = await chrome.storage.sync.get(['authToken', 'convexUrl']);

        if (!authToken || !convexUrl) {
            showNotification('Please log in to REM', 'error');
            return;
        }

        const response = await fetch(`${convexUrl}/api/items`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
            },
            body: JSON.stringify({
                url,
                title,
                type,
                priority: 'medium'
            })
        });

        if (response.ok) {
            showNotification('Saved to REM!', 'success');
        } else {
            throw new Error('Save failed');
        }
    } catch (error) {
        console.error('Save error:', error);
        showNotification('Failed to save', 'error');
    }
}

// Show notification badge
function showNotification(message, type) {
    const color = type === 'success' ? '#10b981' : '#ef4444';
    chrome.action.setBadgeText({ text: type === 'success' ? '✓' : '!' });
    chrome.action.setBadgeBackgroundColor({ color });

    setTimeout(() => {
        chrome.action.setBadgeText({ text: '' });
    }, 2000);
}

// Handle messages from popup/content scripts
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'SAVE_ITEM') {
        saveToRem(message.url, message.title, message.contentType)
            .then(() => sendResponse({ success: true }))
            .catch(() => sendResponse({ success: false }));
        return true; // Keep channel open for async response
    }
});
