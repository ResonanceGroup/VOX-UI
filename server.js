const express = require('express');
const path = require('path');
const https = require('https');
const fs = require('fs');
const forge = require('node-forge');
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

// Generate self-signed certificate if it doesn't exist
const certDir = path.join(__dirname, 'cert');
const keyPath = path.join(certDir, 'key.pem');
const certPath = path.join(certDir, 'cert.pem');

if (!fs.existsSync(certDir)) {
    fs.mkdirSync(certDir);
}

if (!fs.existsSync(keyPath) || !fs.existsSync(certPath)) {
    console.log('Generating self-signed certificate...');
    
    try {
        // Generate a new key pair
        const keys = forge.pki.rsa.generateKeyPair(2048);
        
        // Create a new certificate
        const cert = forge.pki.createCertificate();
        cert.publicKey = keys.publicKey;
        cert.serialNumber = '01';
        cert.validity.notBefore = new Date();
        cert.validity.notAfter = new Date();
        cert.validity.notAfter.setFullYear(cert.validity.notBefore.getFullYear() + 1);
        
        // Add attributes
        const attrs = [{
            name: 'commonName',
            value: 'localhost'
        }, {
            name: 'countryName',
            value: 'US'
        }, {
            shortName: 'ST',
            value: 'Virginia'
        }, {
            name: 'localityName',
            value: 'Blacksburg'
        }, {
            name: 'organizationName',
            value: 'Test'
        }, {
            shortName: 'OU',
            value: 'Test'
        }];
        
        cert.setSubject(attrs);
        cert.setIssuer(attrs);
        
        // Sign the certificate
        cert.sign(keys.privateKey);
        
        // Convert to PEM format
        const privateKeyPem = forge.pki.privateKeyToPem(keys.privateKey);
        const certPem = forge.pki.certificateToPem(cert);
        
        // Save the files
        fs.writeFileSync(keyPath, privateKeyPem);
        fs.writeFileSync(certPath, certPem);
        
        console.log('Certificate generated successfully');
    } catch (error) {
        console.error('Error generating certificate:', error);
        process.exit(1);
    }
}

// HTTPS options
const httpsOptions = {
    key: fs.readFileSync(keyPath),
    cert: fs.readFileSync(certPath)
};

// Start HTTPS server
const PORT = 3001;
const server = https.createServer(httpsOptions, app);

server.listen(PORT, '0.0.0.0', () => {
    const ifaces = require('os').networkInterfaces();
    console.log(`\nServer running at:`);
    console.log(`- Local: https://localhost:${PORT}`);
    
    // List all network interfaces
    Object.keys(ifaces).forEach((ifname) => {
        ifaces[ifname].forEach((iface) => {
            // Skip internal and non-IPv4 addresses
            if (iface.family !== 'IPv4' || iface.internal) {
                return;
            }
            console.log(`- Network: https://${iface.address}:${PORT}`);
        });
    });
    
    console.log('\nNote: You will need to accept the self-signed certificate warning in your browser.');
    console.log('Static files served from:', path.join(__dirname, 'src'));
});
