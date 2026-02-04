// REM Browser Extension - Content Script

// This script runs on every page and can interact with page content
// Currently minimal - can be expanded for:
// - Keyboard shortcuts (Ctrl+Shift+S to save)
// - Highlight text to save as note
// - Auto-detect certain content types

// Keyboard shortcut handler
document.addEventListener('keydown', (e) => {
    // Ctrl+Shift+S to save current page
    if (e.ctrlKey && e.shiftKey && e.key === 'S') {
        e.preventDefault();
        savePage();
    }
});

async function savePage() {
    chrome.runtime.sendMessage({
        type: 'SAVE_ITEM',
        url: window.location.href,
        title: document.title,
        contentType: 'link'
    });
}
