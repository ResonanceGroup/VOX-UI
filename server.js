const express = require('express');
const path = require('path');
const https = require('https');
const http = require('http');
const fs = require('fs');
const settingsApiRouter = require('./src/server/settingsApi'); // Import the settings API router
const WebSocket = require('ws');
const initializeWebSocketHandling = require('./src/server/webSocketHandler'); // Import the WebSocket handler
const app = express();

// Add JSON body parser
app.use(express.json());

// Mount the settings API router
app.use('/api/settings', settingsApiRouter);

// Settings file path is now managed in src/server/settingsApi.js

// Settings initialization is now handled in src/server/settingsApi.js
// Settings GET endpoint is now handled by src/server/settingsApi.js
// Settings POST endpoint is now handled by src/server/settingsApi.js
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
const httpsServer = https.createServer(sslOptions, app); // Get a reference to the server
httpsServer.listen(HTTPS_PORT, '0.0.0.0', () => {
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


// WebSocket Server Setup
const wss = new WebSocket.Server({ server: httpsServer });

// Initialize WebSocket handling using the dedicated module
initializeWebSocketHandling(wss);

console.log(`WebSocket Server attached to HTTPS server on port ${HTTPS_PORT}`);
console.log('\nStatic files served from:', path.join(__dirname, 'src'));
