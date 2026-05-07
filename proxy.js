// VoxUI reverse proxy — serves on port 3000
// Routes: /rtc* (WebSocket) → LiveKit :7880
//         /api/* → Token service :7882
//         /* → Flutter static files (from STATIC_DIR)
const http = require('http');
const path = require('path');
const fs   = require('fs');
const net  = require('net');
const { WebSocketServer, WebSocket } = require('/home/rgadmin/.npm-global/lib/node_modules/ws');

const STATIC_DIR  = '/home/rgadmin/repos/VOX-UI/frontend/build/web';
const TOKEN_PORT  = 7882;
const LK_PORT     = 7880;
const SERVE_PORT  = 3000;

const MIME = {
  '.html': 'text/html', '.js': 'application/javascript',
  '.css': 'text/css',   '.png': 'image/png',
  '.ico': 'image/x-icon', '.json': 'application/json',
  '.wasm': 'application/wasm', '.map': 'application/json',
  '.ttf': 'font/ttf', '.svg': 'image/svg+xml',
};

function proxyHttp(req, res, targetPort, stripPrefix) {
  const targetPath = stripPrefix ? req.url.replace(stripPrefix, '') || '/' : req.url;
  const opts = { hostname: '127.0.0.1', port: targetPort, path: targetPath,
    method: req.method, headers: { ...req.headers, host: `localhost:${targetPort}` } };
  const pr = http.request(opts, (pr2) => {
    res.writeHead(pr2.statusCode, pr2.headers);
    pr2.pipe(res);
  });
  console.log('[HTTP] ' + req.method + ' ' + req.url);
  pr.on('error', (e) => { console.error('[HTTP] error ' + req.url + ': ' + e.message); res.writeHead(502).end(); });
  req.pipe(pr);
}

const server = http.createServer((req, res) => {
  // API proxy
  if (req.url.startsWith('/api/')) return proxyHttp(req, res, TOKEN_PORT, '/api');

  // Static files
  let filePath = path.join(STATIC_DIR, req.url === '/' ? '/index.html' : req.url.split('?')[0]);
  if (!fs.existsSync(filePath)) filePath = path.join(STATIC_DIR, 'index.html');
  const ext = path.extname(filePath);
  const isFlutterAsset = ['.js', '.html', '.json'].includes(ext);
  res.writeHead(200, {
    'Content-Type': MIME[ext] || 'application/octet-stream',
    'Cache-Control': isFlutterAsset ? 'no-store, no-cache, must-revalidate' : 'public, max-age=86400',
    'CDN-Cache-Control': 'no-store',
    'Cloudflare-CDN-Cache-Control': 'no-store',
  });
  fs.createReadStream(filePath).pipe(res);
});

// WebSocket proxy for /rtc* → LiveKit
const wss = new WebSocketServer({ noServer: true });
server.on('upgrade', (req, socket, head) => {
  console.log('[WS] upgrade: ' + req.url);
  wss.handleUpgrade(req, socket, head, (ws) => {
    // iOS Safari + livekit-client sometimes produces /rtc/rtc — normalise to /rtc
    const lkPath = req.url.startsWith('/rtc/rtc') ? req.url.replace('/rtc/rtc', '/rtc') : req.url;
    if (lkPath !== req.url) console.log('[WS] normalised double-rtc path → ' + lkPath);
    const upstream = new WebSocket(`ws://127.0.0.1:${LK_PORT}${lkPath}`);
    upstream.on('open', () => {
      ws.on('message', (d, binary) => upstream.readyState === 1 && upstream.send(d, { binary }));
      upstream.on('message', (d, binary) => ws.readyState === 1 && ws.send(d, { binary }));
    });
    const close = (code, reason) => {
      try { ws.close(code, reason); } catch(_) {}
      try { upstream.close(); } catch(_) {}
    };
    ws.on('close', close); upstream.on('close', close);
    ws.on('error', (e) => { console.error('client ws error', e.message); close(1011); });
    upstream.on('error', (e) => { console.error('upstream ws error', e.message); close(1011); });
  });
});

server.listen(SERVE_PORT, () => console.log(`VoxUI proxy listening on :${SERVE_PORT}`));
