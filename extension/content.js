(function() {
    'use strict';

    if (window.__remExtensionInitialized) return;
    window.__remExtensionInitialized = true;

    document.addEventListener('keydown', handleKeyDown, true);

    function handleKeyDown(e) {
        const isCmdOrCtrl = e.ctrlKey || e.metaKey;
        const isShift = e.shiftKey;

        if (isCmdOrCtrl && isShift && e.key === 's') {
            e.preventDefault();
            e.stopPropagation();

            saveCurrentPage();
            return false;
        }
    }

    function saveCurrentPage() {
        const pageData = {
            url: window.location.href,
            title: document.title,
            contentType: detectContentType(),
        };

        chrome.runtime.sendMessage({
            type: 'SAVE_ITEM',
            ...pageData
        }, (response) => {
            if (chrome.runtime.lastError) {
                showNotification('Failed to save - extension error', 'error');
                return;
            }

            if (response?.success) {
                showNotification('Saved to rem', 'success');
            } else {
                showNotification(response?.error || 'Failed to save', 'error');
            }
        });
    }

    function detectContentType() {
        const url = window.location.href.toLowerCase();

        if (document.contentType?.startsWith('image/') ||
            /\.(jpg|jpeg|png|gif|webp|svg)(\?.*)?$/i.test(url)) {
            return 'image';
        }

        if (document.querySelector('video') ||
            /youtube\.com|youtu\.be|vimeo\.com|tiktok\.com/i.test(url)) {
            return 'video';
        }

        return 'link';
    }

    function showNotification(message, type) {
        const existing = document.getElementById('rem-notification');
        if (existing) existing.remove();

        const notification = document.createElement('div');
        notification.id = 'rem-notification';

        const colors = type === 'success'
            ? { bg: '#2FBF9A', text: '#1F1F1F' }
            : { bg: '#FF3B30', text: '#FFFFFF' };

        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: ${colors.bg};
            color: ${colors.text};
            padding: 12px 20px;
            border-radius: 8px;
            font-family: 'DM Sans', -apple-system, BlinkMacSystemFont, sans-serif;
            font-size: 14px;
            font-weight: 500;
            z-index: 2147483647;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
            animation: rem-slide-in 0.3s ease;
            pointer-events: none;
        `;

        notification.textContent = message;

        if (!document.getElementById('rem-styles')) {
            const styles = document.createElement('style');
            styles.id = 'rem-styles';
            styles.textContent = `
                @keyframes rem-slide-in {
                    from {
                        transform: translateX(100px);
                        opacity: 0;
                    }
                    to {
                        transform: translateX(0);
                        opacity: 1;
                    }
                }
                @keyframes rem-fade-out {
                    from { opacity: 1; }
                    to { opacity: 0; }
                }
            `;
            document.head.appendChild(styles);
        }

        document.body.appendChild(notification);

        setTimeout(() => {
            notification.style.animation = 'rem-fade-out 0.3s ease forwards';
            setTimeout(() => notification.remove(), 300);
        }, 3000);
    }

    chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
        if (message.type === 'GET_PAGE_DATA') {
            const metadata = extractPageMetadata();
            sendResponse({
                url: window.location.href,
                title: document.title,
                ...metadata
            });
            return true;
        }

        if (message.type === 'SHOW_NOTIFICATION') {
            showNotification(message.message, message.notificationType);
            sendResponse({ success: true });
            return true;
        }
    });

    function extractPageMetadata() {
        const getMeta = (selectors) => {
            for (const selector of selectors) {
                const el = document.querySelector(selector);
                if (el?.getAttribute('content')) {
                    return el.getAttribute('content');
                }
            }
            return '';
        };

        const description = getMeta([
            'meta[name="description"]',
            'meta[property="og:description"]',
            'meta[name="twitter:description"]',
        ]);

        let thumbnailUrl = getMeta([
            'meta[property="og:image:secure_url"]',
            'meta[property="og:image"]',
            'meta[name="twitter:image"]',
        ]);

        if (thumbnailUrl && !thumbnailUrl.startsWith('http')) {
            try {
                thumbnailUrl = new URL(thumbnailUrl, window.location.href).href;
            } catch {
                thumbnailUrl = '';
            }
        }

        return {
            description: description.slice(0, 500),
            thumbnailUrl: thumbnailUrl.slice(0, 1000),
        };
    }
})();
