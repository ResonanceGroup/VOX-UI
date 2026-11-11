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

// RG Link (agent-sdk-mobile-app) voice-mode web build — routed by path so the
// public hostname serves both apps. The bridge path carries a random gate
// secret; the bridge itself stays loopback-bound and token-injecting.
const RGLINK_PORT        = 8085;
const RGLINK_BRIDGE_PORT = 4613;
// The bridge path is an access secret (it is the only gate on the bridge), so
// it lives in gitignored proxy.env next to this file, never in the repo.
function loadProxyEnv() {
  try {
    for (const line of fs.readFileSync(path.join(__dirname, 'proxy.env'), 'utf8').split('\n')) {
      const m = line.match(/^([A-Z_][A-Z0-9_]*)=(.*)$/);
      if (m && !(m[1] in process.env)) process.env[m[1]] = m[2];
    }
  } catch (e) { /* no env file: fall through to the explicit error below */ }
}
loadProxyEnv();
const RGLINK_BRIDGE_PATH = process.env.RGLINK_BRIDGE_PATH || '';
if (!RGLINK_BRIDGE_PATH) console.error('WARNING: RGLINK_BRIDGE_PATH unset (create proxy.env) — RG Link bridge routing disabled');
const RGLINK_PREFIXES = ['/node_modules/', '/_expo/', '/__bloop/', '/agents', '/chat'];

function isRglinkPath(url) {
  const [p, q] = (url || '').split('?');
  // /assets/ is shared: VoxUI's Flutter assets (incl. its orb at
  // /assets/assets/orb/orb.html) must stay static; only Expo Router asset
  // requests (which always carry ?unstable_path=) go to RG Link.
  if (p === '/assets' || p === '/assets/') return (q || '').includes('unstable_path=');
  return RGLINK_PREFIXES.some((prefix) => p === prefix || p.startsWith(prefix));
}

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

  // Image proxy — fetches external URLs server-side, bypassing browser CORS
  // Usage: GET /img?url=<encodeURIComponent(externalImageUrl)>
  if (req.url.startsWith('/img')) {
    const parsed = new URL(req.url, 'http://localhost');
    const target = parsed.searchParams.get('url');
    if (!target || !target.match(/^https?:\/\//)) {
      res.writeHead(400, {'Content-Type': 'text/plain'}).end('Bad url');
      return;
    }
    function fetchImg(url, hops) {
      if (hops > 5) { res.writeHead(502).end('Too many redirects'); return; }
      const mod = url.startsWith('https') ? require('https') : http;
      mod.get(url, { headers: { 'User-Agent': 'Mozilla/5.0 VoxUI-ImageProxy/1.0',
                                'Accept': 'image/*,*/*;q=0.8' } }, (imgRes) => {
        if ((imgRes.statusCode === 301 || imgRes.statusCode === 302 ||
             imgRes.statusCode === 303 || imgRes.statusCode === 307 ||
             imgRes.statusCode === 308) && imgRes.headers.location) {
          imgRes.resume();
          fetchImg(imgRes.headers.location, hops + 1);
          return;
        }
        const ct = imgRes.headers['content-type'] || 'image/jpeg';
        res.writeHead(imgRes.statusCode === 200 ? 200 : imgRes.statusCode, {
          'Content-Type': ct,
          'Cache-Control': 'public, max-age=3600',
          'Access-Control-Allow-Origin': '*',
        });
        imgRes.pipe(res);
      }).on('error', (e) => {
        console.error('[IMG] fetch error:', e.message);
        if (!res.headersSent) res.writeHead(502).end();
      });
    }
    fetchImg(target, 0);
    return;
  }

  // RG Link web build (page routes, Expo assets, orb, bloop proxy paths)
  if (isRglinkPath(req.url)) return proxyHttp(req, res, RGLINK_PORT);

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
  const stream = fs.createReadStream(filePath);
  stream.on('error', (e) => { console.error('[STATIC] read error', filePath, e.message); try { res.end(); } catch(_) {} });
  stream.pipe(res);
});

// WebSocket proxies:
//   /bridge-<secret> → RG Link bridge :4613 (gated by unguessable path)
//   /rtc*            → LiveKit :7880 (unchanged)
//   everything else  → RG Link web proxy :8085 (Metro HMR etc.)
const wss = new WebSocketServer({ noServer: true });

function pipeWs(ws, upstreamUrl, wsOptions) {
  const upstream = new WebSocket(upstreamUrl, wsOptions?.protocols || [], wsOptions?.headers ? { headers: wsOptions.headers } : undefined);
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
}

server.on('upgrade', (req, socket, head) => {
  console.log('[WS] upgrade: ' + req.url);
  const upgradePath = (req.url || '').split('?')[0];
  const protocols = (req.headers['sec-websocket-protocol'] || '')
    .split(',').map((x) => x.trim()).filter(Boolean);

  if (RGLINK_BRIDGE_PATH && upgradePath === RGLINK_BRIDGE_PATH) {
    // Gate = the unguessable path. Origin is rewritten to loopback because the
    // bridge only accepts loopback origins; the capability token never leaves the box.
    wss.handleUpgrade(req, socket, head, (ws) =>
      pipeWs(ws, `ws://127.0.0.1:${RGLINK_BRIDGE_PORT}${req.url}`, {
        protocols,
        headers: { Origin: `http://127.0.0.1:${RGLINK_BRIDGE_PORT}` },
      }));
    return;
  }

  if (upgradePath.startsWith('/rtc')) {
    wss.handleUpgrade(req, socket, head, (ws) => {
      // iOS Safari + livekit-client sometimes produces /rtc/rtc — normalise to /rtc
      const lkPath = req.url.startsWith('/rtc/rtc') ? req.url.replace('/rtc/rtc', '/rtc') : req.url;
      if (lkPath !== req.url) console.log('[WS] normalised double-rtc path → ' + lkPath);
      pipeWs(ws, `ws://127.0.0.1:${LK_PORT}${lkPath}`);
    });
    return;
  }

  // Default: RG Link web proxy (Metro HMR, Expo dev websockets)
  wss.handleUpgrade(req, socket, head, (ws) =>
    pipeWs(ws, `ws://127.0.0.1:${RGLINK_PORT}${req.url}`));
});

server.listen(SERVE_PORT, () => console.log(`VoxUI proxy listening on :${SERVE_PORT}`));
