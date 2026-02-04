document.addEventListener('keydown', (e) => {
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
