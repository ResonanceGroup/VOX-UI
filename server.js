const express = require('express');
const path = require('path');
const https = require('https');
const http = require('http');
const fs = require('fs');
const app = express();

// Add JSON body parser
app.use(express.json());

// Settings file path
const SETTINGS_FILE = path.join(__dirname, 'settings.json');

// Initialize settings file if it doesn't exist
if (!fs.existsSync(SETTINGS_FILE)) {
    fs.writeFileSync(SETTINGS_FILE, JSON.stringify({
        theme: 'light',
        n8nwebhook: '',
        ultravoxurl: ''
    }));
}

// Load settings
app.get('/api/settings', (req, res) => {
    try {
        const settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
        res.json(settings);
    } catch (err) {
        console.error('Error loading settings:', err);
        res.status(500).json({ error: 'Failed to load settings' });
    }
});

// Save settings
app.post('/api/settings', (req, res) => {
    try {
        fs.writeFileSync(SETTINGS_FILE, JSON.stringify(req.body, null, 2));
        res.json({ success: true });
    } catch (err) {
        console.error('Error saving settings:', err);
        res.status(500).json({ error: 'Failed to save settings' });
    }
});

// SSL configuration
const sslOptions = {
    key: fs.readFileSync(path.join(__dirname, 'cert', 'key.pem')),
    cert: fs.readFileSync(path.join(__dirname, 'cert', 'cert.pem'))
};

// Log all requests
app.use((req, res, next) => {
    console.log(`${req.method} ${req.url}`);
    next();
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Error:', err);
    res.status(500).send('Internal Server Error');
});

// Serve static files from src directory with detailed logging
app.use(express.static(path.join(__dirname, 'src'), {
    setHeaders: (res, filePath) => {
        console.log('Serving static file:', filePath);
    }
}));

// Serve index.html for root path
app.get('/', (req, res) => {
    const indexPath = path.join(__dirname, 'src', 'index.html');
    console.log('Serving index.html from:', indexPath);
    res.sendFile(indexPath, (err) => {
        if (err) {
            console.error('Error sending index.html:', err);
            res.status(err.status).end();
        } else {
            console.log('Successfully sent index.html');
        }
    });
});

// Handle 404s
app.use((req, res) => {
    console.log('404 Not Found:', req.url);
    res.status(404).send('Not Found');
});

// Start both HTTP and HTTPS servers
const HTTP_PORT = 3001;
const HTTPS_PORT = 3002;

// HTTP Server (for local development)
http.createServer(app).listen(HTTP_PORT, '0.0.0.0', () => {
    const ifaces = require('os').networkInterfaces();
    console.log(`\nHTTP Server running at:`);
    console.log(`- Local: http://localhost:${HTTP_PORT}`);
    
    Object.keys(ifaces).forEach((ifname) => {
        ifaces[ifname].forEach((iface) => {
            if (iface.family !== 'IPv4' || iface.internal) return;
            console.log(`- Network: http://${iface.address}:${HTTP_PORT}`);
        });
    });
});

// HTTPS Server (for production/mobile)
https.createServer(sslOptions, app).listen(HTTPS_PORT, '0.0.0.0', () => {
    const ifaces = require('os').networkInterfaces();
    console.log(`\nHTTPS Server running at:`);
    console.log(`- Local: https://localhost:${HTTPS_PORT}`);
    
    Object.keys(ifaces).forEach((ifname) => {
        ifaces[ifname].forEach((iface) => {
            if (iface.family !== 'IPv4' || iface.internal) return;
            console.log(`- Network: https://${iface.address}:${HTTPS_PORT}`);
        });
    });
});

console.log('\nStatic files served from:', path.join(__dirname, 'src'));
