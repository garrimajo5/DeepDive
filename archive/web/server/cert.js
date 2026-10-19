'use strict';
/* Самоподписанный сертификат для HTTPS без openssl и пакетов: X.509 собирается вручную (ASN.1 DER),
   подписывается встроенным crypto. Телефон даёт микрофон и AR только по HTTPS, поэтому сервер в Wi‑Fi
   нужно открывать по https://адрес:порт. Браузер один раз предупредит о сертификате — «Дополнительно → Перейти».
   В сертификат вписаны localhost и все адреса компьютера в сети. */
const crypto = require('crypto'), os = require('os'), fs = require('fs'), path = require('path');

const len = n => (n < 128 ? Buffer.from([n]) : n < 256 ? Buffer.from([0x81, n]) : Buffer.from([0x82, n >> 8, n & 255]));
const tlv = (tag, ...parts) => { const b = Buffer.concat(parts.map(p => (Buffer.isBuffer(p) ? p : Buffer.from(p)))); return Buffer.concat([Buffer.from([tag]), len(b.length), b]); };
const seq = (...p) => tlv(0x30, ...p), set = (...p) => tlv(0x31, ...p);
const int = b => tlv(0x02, b[0] & 0x80 ? Buffer.concat([Buffer.from([0]), b]) : b);
const oid = s => {
  const a = s.split('.').map(Number), out = [a[0] * 40 + a[1]];
  for (const v of a.slice(2)) { const st = []; let x = v; do { st.unshift(x & 0x7f); x >>= 7; } while (x); st.forEach((d, i) => out.push(i < st.length - 1 ? d | 0x80 : d)); }
  return tlv(0x06, Buffer.from(out));
};
const utf8 = s => tlv(0x0c, Buffer.from(s, 'utf8'));
const time = d => tlv(0x17, Buffer.from(d.toISOString().replace(/[-:T]/g, '').slice(2, 14) + 'Z'));
const bits = b => tlv(0x03, Buffer.from([0]), b);
const octets = b => tlv(0x04, b);
const ctx = (n, ...p) => tlv(0xa0 + n, ...p);

/* адреса компьютера в сети (IPv4) */
function lanAddrs() {
  const out = [];
  Object.values(os.networkInterfaces()).forEach(list => (list || []).forEach(a => { if ((a.family === 'IPv4' || a.family === 4) && !a.internal) out.push(a.address); }));
  return out;
}

function generate(ips, days) {
  ips = ['127.0.0.1'].concat(ips || lanAddrs()).filter((v, i, a) => a.indexOf(v) === i);
  const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
  const alg = seq(oid('1.2.840.113549.1.1.11'), tlv(0x05)); // sha256WithRSAEncryption
  const name = seq(set(seq(oid('2.5.4.3'), utf8('Погружение — локальный сервер'))));
  const now = Date.now(), from = new Date(now - 864e5), to = new Date(now + (days || 825) * 864e5);
  const san = seq(tlv(0x82, Buffer.from('localhost')), ...ips.map(ip => tlv(0x87, Buffer.from(ip.split('.').map(Number))))); // dNSName, iPAddress
  const ext = ctx(3, seq(
    seq(oid('2.5.29.17'), octets(san)),
    seq(oid('2.5.29.37'), octets(seq(oid('1.3.6.1.5.5.7.3.1')))), // только для сервера
    seq(oid('2.5.29.19'), octets(seq())) // не центр сертификации
  ));
  const serial = crypto.randomBytes(16); serial[0] &= 0x7f;
  const tbs = seq(ctx(0, int(Buffer.from([2]))), int(serial), alg, name, seq(time(from), time(to)), name, publicKey.export({ type: 'spki', format: 'der' }), ext);
  const sig = crypto.sign('sha256', tbs, privateKey);
  const der = seq(tbs, alg, bits(sig));
  const cert = '-----BEGIN CERTIFICATE-----\n' + der.toString('base64').match(/.{1,64}/g).join('\n') + '\n-----END CERTIFICATE-----\n';
  return { cert, key: privateKey.export({ type: 'pkcs8', format: 'pem' }), ips };
}

/* сертификат в server/cert/: создаётся один раз; если у компьютера новый адрес — пересоздаётся */
function load(dir) {
  dir = dir || path.join(__dirname, 'cert');
  const cf = path.join(dir, 'cert.pem'), kf = path.join(dir, 'key.pem'), ips = lanAddrs();
  try {
    const cert = fs.readFileSync(cf, 'utf8'), key = fs.readFileSync(kf, 'utf8'), x = new crypto.X509Certificate(cert);
    const fresh = new Date(x.validTo) > new Date(Date.now() + 864e5) && ips.every(ip => x.checkIP(ip));
    if (fresh) return { cert, key, ips, made: false };
  } catch (_) { /* нет или битый — создаём */ }
  const g = generate(ips);
  fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(cf, g.cert); fs.writeFileSync(kf, g.key, { mode: 0o600 });
  return Object.assign(g, { made: true });
}

module.exports = { generate, load, lanAddrs };
