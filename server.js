const express = require('express');
const path = require('path');
const app = express();

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

// Start server
const PORT = 3001;
app.listen(PORT, '0.0.0.0', () => {
    const ifaces = require('os').networkInterfaces();
    console.log(`\nServer running at:`);
    console.log(`- Local: http://localhost:${PORT}`);
    
    // List all network interfaces
    Object.keys(ifaces).forEach((ifname) => {
        ifaces[ifname].forEach((iface) => {
            // Skip internal and non-IPv4 addresses
            if (iface.family !== 'IPv4' || iface.internal) {
                return;
            }
            console.log(`- Network: http://${iface.address}:${PORT}`);
        });
    });
    
    console.log('\nStatic files served from:', path.join(__dirname, 'src'));
});
