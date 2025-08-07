// Theme initialization
document.addEventListener('DOMContentLoaded', function() {
    // Apply saved theme or default to light
    const savedTheme = localStorage.getItem('theme') || 'light';
    document.documentElement.setAttribute('data-theme', savedTheme);
});