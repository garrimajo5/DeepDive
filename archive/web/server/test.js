'use strict';
/* Тесты сервера синхронизации: node server/test.js. Клиент WebSocket написан тут же, без библиотек. */
const http = require('http'), https = require('https'), crypto = require('crypto'), assert = require('assert'), fs = require('fs'), os = require('os'), path = require('path');
const { createServer } = require('./server');

function client(port) {
  return new Promise((resolve, reject) => {
    const key = crypto.randomBytes(16).toString('base64');
    const req = http.request({ host: '127.0.0.1', port, path: '/ws', headers: { Connection: 'Upgrade', Upgrade: 'websocket', 'Sec-WebSocket-Key': key, 'Sec-WebSocket-Version': '13' } });
    req.on('upgrade', (res, sock) => {
      const want = crypto.createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
      assert.strictEqual(res.headers['sec-websocket-accept'], want, 'неверный ответ рукопожатия');
      const c = { sock, inbox: [], waiters: [], buf: Buffer.alloc(0) };
      sock.on('data', d => {
        c.buf = Buffer.concat([c.buf, d]);
        for (;;) {
          const b = c.buf; if (b.length < 2) break;
          let len = b[1] & 0x7f, off = 2; if (len === 126) { len = b.readUInt16BE(2); off = 4; }
          if (b.length < off + len) break;
          const op = b[0] & 0x0f, data = b.subarray(off, off + len); c.buf = b.subarray(off + len);
          const m = op === 0x1 ? JSON.parse(data.toString()) : op === 0xA ? { t: 'pong' } : null;
          if (m) { const w = c.waiters.findIndex(x => x.t === m.t); if (w >= 0) c.waiters.splice(w, 1)[0].res(m); else c.inbox.push(m); }
        }
      });
      c.send = (o, op) => { const p = Buffer.from(op ? '' : JSON.stringify(o)), m = crypto.randomBytes(4), h = p.length < 126 ? Buffer.from([0x80 | (op || 1), 0x80 | p.length]) : Buffer.from([0x80 | (op || 1), 0x80 | 126, p.length >> 8, p.length & 255]); const x = Buffer.from(p); for (let i = 0; i < x.length; i++) x[i] ^= m[i & 3]; sock.write(Buffer.concat([h, m, x])); };
      c.next = (t, ms) => new Promise((res, rej) => { const i = c.inbox.findIndex(x => x.t === t); if (i >= 0) return res(c.inbox.splice(i, 1)[0]); const w = { t, res }; c.waiters.push(w); setTimeout(() => { const j = c.waiters.indexOf(w); if (j >= 0) { c.waiters.splice(j, 1); rej(new Error('нет сообщения ' + t)); } }, ms || 1000); });
      c.none = (t, ms) => new Promise(res => setTimeout(() => res(!c.inbox.some(x => x.t === t)), ms || 150));
      c.close = () => sock.destroy();
      resolve(c);
    });
    req.on('error', reject); req.end();
  });
}
const wait = ms => new Promise(r => setTimeout(r, ms));

(async () => {
  const srv = createServer(); await new Promise(r => srv.listen(0, '127.0.0.1', r)); const port = srv.address().port;
  let ok = 0; const t = async (name, fn) => { await fn(); ok++; console.log('  ✓ ' + name); };
  try {
    await t('раздаёт игру по HTTP', async () => {
      const body = await new Promise((res, rej) => http.get({ host: '127.0.0.1', port, path: '/' }, r => { let s = ''; r.on('data', d => s += d); r.on('end', () => res([r.statusCode, s])); }).on('error', rej));
      assert.strictEqual(body[0], 200); assert.ok(body[1].includes('Погружение'));
      const bad = await new Promise(res => http.get({ host: '127.0.0.1', port, path: '/../../etc/passwd' }, r => res(r.statusCode)));
      assert.notStrictEqual(bad, 200, 'отдал файл вне папки игры');
    });
    let a, b, c, ida, idb;
    await t('первый в комнате — хост, второй — гость', async () => {
      a = await client(port); a.send({ t: 'join', room: 'ковчег', name: 'Пилот' });
      const ja = await a.next('joined'); assert.strictEqual(ja.host, true); assert.strictEqual(ja.room, 'КОВЧЕГ');
      b = await client(port); b.send({ t: 'join', room: 'Ковчег', name: 'Сонарщик' });
      const jb = await b.next('joined'); ida = ja.id; idb = jb.id; assert.strictEqual(jb.host, false); assert.strictEqual(jb.hostId, ja.id);
      assert.deepStrictEqual(jb.peers.map(p => p.name), ['Пилот']);
      const pj = await a.next('peer'); assert.strictEqual(pj.ev, 'join'); assert.strictEqual(pj.name, 'Сонарщик');
    });
    await t('хост рассылает состояние, гость шлёт ввод только хосту', async () => {
      a.send({ t: 'state', s: { x: 1, hull: 90 } });
      const st = await b.next('state'); assert.deepStrictEqual(st.s, { x: 1, hull: 90 });
      b.send({ t: 'input', i: { ping: true } });
      const inp = await a.next('input'); assert.deepStrictEqual(inp.i, { ping: true });
      b.send({ t: 'state', s: { x: 999 } }); // гость не может навязать мир
      assert.ok(await a.none('state'), 'хост получил состояние от гостя');
    });
    await t('роли: у поста один хозяин, роль видят все', async () => {
      a.send({ t: 'role', role: 'pilot' });
      const ra = await b.next('peer'); assert.strictEqual(ra.ev, 'role'); assert.strictEqual(ra.role, 'pilot'); assert.strictEqual(ra.name, 'Пилот');
      await a.next('peer'); // себе тоже — подтверждение
      b.send({ t: 'role', role: 'pilot' });
      const e = await b.next('error'); assert.strictEqual(e.role, 'pilot');
      b.send({ t: 'role', role: 'sonar' }); const rb = await a.next('peer'); assert.strictEqual(rb.role, 'sonar'); await b.next('peer');
      b.send({ t: 'role', role: 'капитан' }); const rx = await a.next('peer'); assert.strictEqual(rx.role, '', 'неизвестная роль не снята'); await b.next('peer');
      b.send({ t: 'role', role: 'sonar' }); await a.next('peer'); await b.next('peer');
      const late = await client(port); late.send({ t: 'join', room: 'КОВЧЕГ', name: 'Поздний' });
      const jl = await late.next('joined'); assert.deepStrictEqual(jl.peers.map(p => p.role), ['pilot', 'sonar']);
      late.close(); await a.next('peer'); await a.next('peer'); await b.next('peer'); await b.next('peer');
    });
    await t('комнаты не смешиваются', async () => {
      c = await client(port); c.send({ t: 'join', room: 'другая', name: 'Чужой' });
      const jc = await c.next('joined'); assert.strictEqual(jc.host, true);
      a.send({ t: 'state', s: { x: 2 } }); await b.next('state');
      assert.ok(await c.none('state'), 'состояние ушло в чужую комнату');
    });
    await t('голосовая связь: приглашения только адресату, «говорю» — всем остальным', async () => {
      a.send({ t: 'rtc', to: idb, data: { sdp: { type: 'offer', sdp: 'v=0' } } });
      const r = await b.next('rtc'); assert.strictEqual(r.from, ida); assert.strictEqual(r.data.sdp.type, 'offer');
      assert.ok(await c.none('rtc'), 'приглашение ушло в чужую комнату');
      a.send({ t: 'rtc', to: 99999, data: {} }); assert.ok(await a.none('error'));
      b.send({ t: 'talk', on: true });
      const tk = await a.next('talk'); assert.strictEqual(tk.on, true); assert.strictEqual(tk.name, 'Сонарщик');
      assert.ok(await b.none('talk'), 'говорящему пришло его же «говорю»');
    });
    await t('ушёл хост — хостом становится следующий', async () => {
      a.close();
      const lv = await b.next('peer'); assert.strictEqual(lv.ev, 'leave');
      const h = await b.next('host'); assert.ok(h.id > 0);
      b.send({ t: 'state', s: { x: 3 } }); // теперь b — хост; некому слать, но и ошибки нет
      assert.ok(await b.none('error'));
    });
    await t('пинг получает понг, мусор не роняет сервер', async () => {
      b.send(null, 0x9); await b.next('pong');
      b.sock.write(Buffer.from([0x81, 0x83, 1, 2, 3, 4, 0x7a, 0x7b, 0x7c])); // не JSON
      await b.next('error');
      const d = await client(port); d.send({ t: 'join', room: 'КОВЧЕГ', name: 'Инженер' }); const jd = await d.next('joined'); assert.strictEqual(jd.host, false);
      d.close();
    });
    await t('в экипаже не больше пяти', async () => {
      const crew = []; for (let i = 0; i < 5; i++) { const x = await client(port); x.send({ t: 'join', room: 'полный', name: 'м' + i }); await x.next('joined'); crew.push(x); }
      const extra = await client(port); extra.send({ t: 'join', room: 'полный', name: 'шестой' });
      const e = await extra.next('error'); assert.ok(e.msg.includes('пять'));
      crew.concat(extra).forEach(x => x.close()); await wait(50);
      assert.ok(!srv.rooms.has('ПОЛНЫЙ'), 'пустая комната не удалена');
    });
    await t('папку сервера не отдаёт: ключ сертификата не утечёт', async () => {
      for (const p of ['/server/cert/key.pem', '/server/server.js', '/server']) {
        const code = await new Promise(res => http.get({ host: '127.0.0.1', port, path: p }, r => { r.resume(); res(r.statusCode); }));
        assert.notStrictEqual(code, 200, 'отдал ' + p);
      }
    });
    await t('HTTPS: свой сертификат с адресами в сети, браузерный клиент ему верит', async () => {
      const { generate, load } = require('./cert');
      const g = generate(['192.168.1.50'], 30), x = new crypto.X509Certificate(g.cert);
      assert.ok(x.checkIP('192.168.1.50') && x.checkIP('127.0.0.1') && x.checkHost('localhost'), 'нет адресов в сертификате');
      assert.ok(x.verify(x.publicKey), 'подпись не сходится'); assert.ok(!x.ca, 'сертификат центра сертификации');
      const s2 = createServer({ tls: g }); await new Promise(r => s2.listen(0, '127.0.0.1', r)); const p2 = s2.address().port;
      const code = await new Promise((res, rej) => https.get({ host: '127.0.0.1', port: p2, path: '/', ca: g.cert }, r => { r.resume(); res(r.statusCode); }).on('error', rej)); // проверка по имени и цепочке включена
      assert.strictEqual(code, 200);
      const up = await new Promise((res, rej) => { const q = https.request({ host: '127.0.0.1', port: p2, path: '/ws', ca: g.cert, headers: { Connection: 'Upgrade', Upgrade: 'websocket', 'Sec-WebSocket-Key': crypto.randomBytes(16).toString('base64'), 'Sec-WebSocket-Version': '13' } }); q.on('upgrade', (r, sock) => { sock.destroy(); res(r.statusCode); }); q.on('error', rej); q.end(); });
      assert.strictEqual(up, 101, 'нет WebSocket по wss');
      s2.close();
      const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pogr-cert-'));
      const l1 = load(dir), l2 = load(dir);
      assert.ok(l1.made && !l2.made, 'сертификат пересоздаётся каждый запуск'); assert.strictEqual(l1.cert, l2.cert);
      fs.rmSync(dir, { recursive: true, force: true });
    });
    b.close(); c.close();
    console.log(`\nТестов сервера: ${ok}, все прошли`);
    srv.close(); process.exit(0);
  } catch (e) { console.error('  ✗', e.message); srv.close(); process.exit(1); }
})();
