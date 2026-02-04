// REM Browser Extension - Popup Script

let currentPriority = 'medium';
let pageData = { title: '', url: '' };

// Initialize
document.addEventListener('DOMContentLoaded', async () => {
    await loadPageInfo();
    setupEventListeners();
});

// Get current tab info
async function loadPageInfo() {
    try {
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

        pageData = {
            title: tab.title || 'Untitled',
            url: tab.url || ''
        };

        document.getElementById('page-title').textContent = pageData.title;
        document.getElementById('page-url').textContent = new URL(pageData.url).hostname;
    } catch (error) {
        console.error('Failed to get page info:', error);
        document.getElementById('page-title').textContent = 'Unknown page';
    }
}

// Event listeners
function setupEventListeners() {
    // Priority buttons
    document.querySelectorAll('.priority-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.priority-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            currentPriority = btn.dataset.priority;
        });
    });

    // Save button
    document.getElementById('save-btn').addEventListener('click', saveItem);
}

// Save to REM
async function saveItem() {
    const saveBtn = document.getElementById('save-btn');
    saveBtn.disabled = true;
    saveBtn.textContent = 'Saving...';

    try {
        // Get auth token from storage
        const { authToken, convexUrl } = await chrome.storage.sync.get(['authToken', 'convexUrl']);

        if (!authToken || !convexUrl) {
            alert('Please log in to REM first');
            return;
        }

        // Call Convex HTTP endpoint
        const response = await fetch(`${convexUrl}/api/items`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
            },
            body: JSON.stringify({
                url: pageData.url,
                title: pageData.title,
                type: 'link',
                priority: currentPriority
            })
        });

        if (!response.ok) {
            throw new Error('Failed to save');
        }

        // Show success
        document.getElementById('main-view').classList.add('hidden');
        document.getElementById('success-view').classList.remove('hidden');

        // Close popup after delay
        setTimeout(() => window.close(), 1500);

    } catch (error) {
        console.error('Save failed:', error);
        saveBtn.disabled = false;
        saveBtn.textContent = 'Save to Vault';
        alert('Failed to save. Please try again.');
    }
}
