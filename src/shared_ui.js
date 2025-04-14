// src/shared_ui.js

document.addEventListener('DOMContentLoaded', () => {
    // --- Sidebar Logic ---
    const sidebarToggle = document.getElementById('sidebar-toggle');
    const sidebar = document.querySelector('.sidebar');
    const overlay = document.querySelector('.overlay');
    let isSidebarOpen = false;

    function toggleSidebar() {
        isSidebarOpen = !isSidebarOpen;
        if (sidebar) sidebar.classList.toggle('open', isSidebarOpen);
        if (overlay) overlay.classList.toggle('visible', isSidebarOpen);
        if (sidebarToggle) sidebarToggle.setAttribute('aria-expanded', isSidebarOpen);
    }

    if (sidebarToggle && overlay && sidebar) {
        sidebarToggle.addEventListener('click', toggleSidebar);
        overlay.addEventListener('click', toggleSidebar);
    }
});

// --- Toast Notification Logic ---
function showToast(message, duration = 3000) {
    // Remove existing toast if any
    const existingToast = document.querySelector('.toast-notification');
    if (existingToast) {
        existingToast.remove();
    }

    // Create toast element
    const toast = document.createElement('div');
    toast.className = 'toast-notification';
    toast.textContent = message;

    // Style the toast (basic example)
    toast.style.position = 'fixed';
    toast.style.bottom = '20px';
    toast.style.left = '50%';
    toast.style.transform = 'translateX(-50%)';
    toast.style.backgroundColor = 'rgba(0, 0, 0, 0.7)';
    toast.style.color = 'white';
    toast.style.padding = '10px 20px';
    toast.style.borderRadius = '5px';
    toast.style.zIndex = '1000';
    toast.style.opacity = '0';
    toast.style.transition = 'opacity 0.5s ease-in-out';

    // Add to body and fade in
    document.body.appendChild(toast);
    setTimeout(() => { toast.style.opacity = '1'; }, 50); // Small delay for transition

    // Fade out and remove after duration
    setTimeout(() => {
        toast.style.opacity = '0';
        setTimeout(() => {
            if (toast.parentNode) {
                toast.remove();
            }
        }, 500); // Wait for fade out transition
    }, duration);
}

// --- Theme Application Logic ---
function applyTheme(theme) {
    const effectiveTheme = theme === 'system' ?
        window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
        : theme;
    document.documentElement.dataset.theme = effectiveTheme;
    console.log('[shared_ui] Applied theme:', theme, '(effective:', effectiveTheme, ')');
}

// Listen for system theme changes
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
    // Re-apply theme if current setting is 'system'
    const currentTheme = document.querySelector('input[name="theme"]:checked')?.value || 'system'; // Or get from settings if available
    if (currentTheme === 'system') {
        applyTheme('system');
    }
});