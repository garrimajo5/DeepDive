'use strict';
/* Сервер синхронизации «Погружения»: раздаёт игру по HTTP и держит комнаты экипажей по WebSocket.
   Без внешних библиотек: только модули Node.js. Запуск: node server/server.js [порт] (по умолчанию 8787).
   Авторитетный хост: первый в комнате считает мир и рассылает состояние, остальные шлют ему свой ввод.
   Если хост ушёл, хостом становится следующий по очереди.

   Протокол (JSON в текстовых кадрах):
     клиент → {t:'join', room, name}            сервер → {t:'joined', id, room, host, peers:[{id,name}]}
     хост   → {t:'state', s}                    → остальным в комнате {t:'state', s, from}
     гость  → {t:'input', i}                    → хосту {t:'input', i, from}
     любой  → {t:'rtc', to, data}               → только адресату {t:'rtc', from, data} (WebRTC: sdp, ice)
     любой  → {t:'talk', on}                    → остальным {t:'talk', from, name, on}
     любой  → {t:'role', role}                  → всем в комнате {t:'peer', ev:'role', id, name, role}
     сервер → {t:'peer', ev:'join'|'leave', id, name}, {t:'host', id}, {t:'error', msg}
   Роли: pilot, sonar, eng, bio — у каждой роли один хозяин; пустая строка снимает роль. */
const http = require('http'), https = require('https'), crypto = require('crypto'), fs = require('fs'), path = require('path');

const ROOT = path.resolve(__dirname, '..');
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.json': 'application/json', '.md': 'text/markdown; charset=utf-8' };
const MAX_MSG = 64 * 1024, RATE = 60, ROOM_MAX = 5;

function createServer(opts) {
  opts = opts || {};
  const ROLES = ['pilot', 'sonar', 'eng', 'bio'];
  const rooms = new Map(); // room → { peers: [client], host: client }
  let nextId = 1;

  const handler = (req, res) => { // статика: index.html, js, css, lib, docs
    let p = decodeURIComponent((req.url || '/').split('?')[0]);
    if (p === '/') p = '/index.html';
    const file = path.resolve(ROOT, '.' + p);
    if (!file.startsWith(ROOT + path.sep) || /[\\/]\./.test(p) || /^\/server(\/|$)/.test(p)) { res.writeHead(403); res.end('нельзя'); return; } // папку сервера (ключ сертификата) не отдаём
    fs.readFile(file, (err, data) => {
      if (err) { res.writeHead(404); res.end('не найдено'); return; }
      res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' }); res.end(data);
    });
  };
  const srv = opts.tls ? https.createServer({ key: opts.tls.key, cert: opts.tls.cert }, handler) : http.createServer(handler); // HTTPS — для микрофона и AR на телефоне

  srv.on('upgrade', (req, sock) => {
    const key = req.headers['sec-websocket-key'];
    if (!key || (req.url || '').split('?')[0] !== '/ws') { sock.destroy(); return; }
    const accept = crypto.createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
    sock.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
    sock.setNoDelay(true);
    const c = { id: nextId++, sock, name: '', room: null, buf: Buffer.alloc(0), sent: 0, win: Date.now() };
    sock.on('data', d => { c.buf = Buffer.concat([c.buf, d]); if (c.buf.length > MAX_MSG * 2) return drop(c); readFrames(c); });
    sock.on('end', () => { leave(c); sock.end(); }); // клиент закрыл соединение (сокеты апгрейда полуоткрытые)
    sock.on('close', () => leave(c));
    sock.on('error', () => leave(c));
  });

  /* ---------- кадры WebSocket (RFC 6455): только то, что нужно игре ---------- */
  function readFrames(c) {
    for (;;) {
      const b = c.buf; if (b.length < 2) return;
      const op = b[0] & 0x0f, masked = b[1] & 0x80; let len = b[1] & 0x7f, off = 2;
      if (len === 126) { if (b.length < 4) return; len = b.readUInt16BE(2); off = 4; }
      else if (len === 127) { if (b.length < 10) return; len = Number(b.readBigUInt64BE(2)); off = 10; }
      if (len > MAX_MSG) return drop(c);
      const need = off + (masked ? 4 : 0) + len; if (b.length < need) return;
      let data = b.subarray(off + (masked ? 4 : 0), need);
      if (masked) { const m = b.subarray(off, off + 4); data = Buffer.from(data); for (let i = 0; i < data.length; i++) data[i] ^= m[i & 3]; }
      c.buf = b.subarray(need);
      if (op === 0x8) { leave(c); try { c.sock.end(frame(Buffer.alloc(0), 0x8)); } catch (_) {} return; }
      if (op === 0x9) { send(c, data, 0xA); continue; } // пинг → понг
      if (op === 0x1) onText(c, data.toString('utf8'));
    }
  }
  function frame(payload, op) {
    const n = payload.length, head = n < 126 ? Buffer.from([0x80 | op, n]) : n < 65536 ? Buffer.from([0x80 | op, 126, n >> 8, n & 255]) : null;
    if (!head) { const h = Buffer.alloc(10); h[0] = 0x80 | op; h[1] = 127; h.writeBigUInt64BE(BigInt(n), 2); return Buffer.concat([h, payload]); }
    return Buffer.concat([head, payload]);
  }
  function send(c, data, op) { if (c.sock.destroyed) return; try { c.sock.write(frame(Buffer.isBuffer(data) ? data : Buffer.from(data), op || 0x1)); } catch (_) {} }
  const sendJ = (c, o) => send(c, JSON.stringify(o));
  function drop(c) { leave(c); c.sock.destroy(); }

  /* ---------- комнаты ---------- */
  function onText(c, txt) {
    const now = Date.now(); if (now - c.win > 1000) { c.win = now; c.sent = 0; }
    if (++c.sent > RATE) return; // слишком часто — лишнее молча отбрасываем
    let m; try { m = JSON.parse(txt); } catch (_) { return sendJ(c, { t: 'error', msg: 'не JSON' }); }
    if (!m || typeof m.t !== 'string') return;
    if (m.t === 'join') return join(c, m);
    const r = c.room && rooms.get(c.room); if (!r) return sendJ(c, { t: 'error', msg: 'сначала join' });
    if (m.t === 'state' && r.host === c) r.peers.forEach(p => { if (p !== c) sendJ(p, { t: 'state', s: m.s, from: c.id }); });
    else if (m.t === 'input' && r.host !== c) sendJ(r.host, { t: 'input', i: m.i, from: c.id });
    else if (m.t === 'rtc') { const to = r.peers.find(p => p.id === m.to); if (to && to !== c) sendJ(to, { t: 'rtc', from: c.id, data: m.data }); } // приглашения голосовой связи — только адресату
    else if (m.t === 'talk') r.peers.forEach(p => { if (p !== c) sendJ(p, { t: 'talk', from: c.id, name: c.name, on: !!m.on }); });
    else if (m.t === 'role') {
      const role = ROLES.includes(m.role) ? m.role : '';
      if (role && r.peers.some(p => p !== c && p.role === role)) return sendJ(c, { t: 'error', msg: 'этот пост уже занят', role });
      c.role = role; r.peers.forEach(p => sendJ(p, { t: 'peer', ev: 'role', id: c.id, name: c.name, role }));
    }
  }
  function join(c, m) {
    const room = String(m.room || '').toUpperCase().replace(/[^A-ZА-ЯЁ0-9]/g, '').slice(0, 8);
    if (!room) return sendJ(c, { t: 'error', msg: 'нужно имя комнаты' });
    if (c.room) leave(c);
    let r = rooms.get(room); if (!r) { r = { peers: [], host: null }; rooms.set(room, r); }
    if (r.peers.length >= ROOM_MAX) return sendJ(c, { t: 'error', msg: 'в экипаже уже пять человек' });
    c.name = String(m.name || 'Гость').slice(0, 24); c.room = room;
    r.peers.push(c); if (!r.host) r.host = c;
    sendJ(c, { t: 'joined', id: c.id, room, host: r.host === c, hostId: r.host.id, peers: r.peers.filter(p => p !== c).map(p => ({ id: p.id, name: p.name, role: p.role || '' })) });
    r.peers.forEach(p => { if (p !== c) sendJ(p, { t: 'peer', ev: 'join', id: c.id, name: c.name }); });
  }
  function leave(c) {
    const key = c.room, r = key && rooms.get(key); if (!r) return;
    r.peers = r.peers.filter(p => p !== c); c.room = null;
    if (!r.peers.length) { rooms.delete(key); return; }
    r.peers.forEach(p => sendJ(p, { t: 'peer', ev: 'leave', id: c.id, name: c.name }));
    if (r.host === c) { r.host = r.peers[0]; r.peers.forEach(p => sendJ(p, { t: 'host', id: r.host.id })); } // хост ушёл — следующий по очереди
  }
  srv.rooms = rooms;
  return srv;
}

module.exports = { createServer };
if (require.main === module) {
  /* node server/server.js [порт] [--https] */
  const args = process.argv.slice(2), secure = args.includes('--https');
  const port = +args.find(a => /^\d+$/.test(a)) || +process.env.PORT || 8787;
  let tls = null;
  if (secure) { tls = require('./cert').load(); if (tls.made) console.log('Создан сертификат: server/cert/cert.pem'); }
  const proto = secure ? 'https' : 'http';
  createServer({ tls }).listen(port, () => {
    console.log(`Погружение: ${proto}://localhost:${port}/`);
    require('./cert').lanAddrs().forEach(ip => console.log(`  в Wi‑Fi: ${proto}://${ip}:${port}/index.html?room=КОВЧЕГ&name=Имя`));
    if (secure) console.log('  Браузер один раз предупредит о сертификате: «Дополнительно» → «Перейти на сайт».');
    else console.log('  Микрофон и AR на телефоне работают только по HTTPS: запустите с --https');
  });
}
