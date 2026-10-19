'use strict';
/* Сетевой экипаж: клиент сервера синхронизации (сокет подменён заглушкой) */
T.describe('Экипаж по сети', () => {
  const N = () => G.Net, S = () => G.Ship, D = () => G.Game.debug;
  class FakeWS {
    constructor(url) { this.url = url; this.sent = []; this.readyState = 1; FakeWS.last = this; setTimeout(() => {}, 0); }
    send(s) { this.sent.push(JSON.parse(s)); }
    close() { this.readyState = 3; this.onclose && this.onclose(); }
    open() { this.onopen(); }
    msg(o) { this.onmessage({ data: JSON.stringify(o) }); }
  }
  const join = (host) => { N().connect('ws://test/ws', 'ковчег', 'Тест', FakeWS); const ws = FakeWS.last; ws.open(); ws.msg({ t: 'joined', id: host ? 1 : 2, room: 'КОВЧЕГ', host, hostId: 1, peers: host ? [] : [{ id: 1, name: 'Хост' }] }); return ws; };
  const leave = () => { if (N().ws) { N().ws.onclose = null; } Object.assign(N(), { ws: null, on: false, host: false, status: 'off', target: null, remote: null, peers: [] }); N().hud(); };
  const quiet = () => G.Eco.preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });

  T.test('подключение: вход в комнату и строка экипажа на приборах', () => {
    const ws = join(true);
    T.eq(ws.sent[0].t, 'join'); T.eq(ws.sent[0].room, 'ковчег');
    T.ok(N().host); T.ok(!document.getElementById('s-net').hidden);
    T.ok(document.getElementById('s-net').textContent.includes('хост'));
    ws.msg({ t: 'peer', ev: 'join', id: 2, name: 'Сонарщик' });
    T.eq(N().peers.length, 1); T.ok(document.getElementById('s-net').textContent.includes('· 2 ·'));
    leave();
  });

  T.test('хост 10 раз в секунду рассылает корабль', () => {
    quiet(); const ws = join(true); ws.sent.length = 0;
    D().frame(20); // 1 с
    const st = ws.sent.filter(m => m.t === 'state');
    T.ok(st.length >= 9 && st.length <= 11, 'состояний за секунду: ' + st.length);
    T.near(st[st.length - 1].s.p[0], S().pos.x, 0.1); // последний снимок — до 0,1 с назад, корабль сносит течением
    leave();
  });

  T.test('гость тянет корабль к состоянию хоста и шлёт свой ввод', () => {
    quiet(); const ws = join(false); ws.sent.length = 0;
    const target = { p: [S().pos.x + 10, S().pos.y, S().pos.z], yaw: 0.5, sp: 1, vy: 0, hull: 77, en: 66, light: false };
    ws.msg({ t: 'state', s: target });
    D().frame(30);
    T.near(S().pos.x, target.p[0], 0.5, 'корабль гостя не догнал хоста');
    T.eq(S().hull, 77); T.ok(!S().light);
    G.Game.toggleHelm(); G.Ctl.padMove.y = 1; D().frame(4); G.Ctl.padMove.y = 0; D().frame(1);
    const inp = ws.sent.filter(m => m.t === 'input');
    T.gt(inp.length, 0, 'гость не шлёт ввод'); T.gt(inp[0].i.th, 0);
    G.Game.toggleHelm(); leave();
  });

  T.test('хост применяет ввод гостя, пока свой молчит', () => {
    quiet(); const ws = join(true);
    S().pos.set(-110, -12, -30); S().pos.y = Math.max(S().pos.y, G.World.height(-110, -30) + 12); S().yaw = 0; S().speed = 0; S().applyTransform();
    for (let i = 0; i < 40; i++) { ws.msg({ t: 'input', i: { th: 1, tu: 0, ve: 0 }, from: 2 }); D().frame(1); }
    T.gt(S().speed, 1, 'ввод гостя не разогнал корабль');
    const sp = S().speed; D().frame(60);
    T.lt(S().speed, sp, 'корабль разгоняется без ввода');
    leave();
  });

  T.test('без комнаты в адресе игра одиночная (контроль)', () => {
    T.ok(!N().auto(), 'подключилась без ?room');
    T.ok(!N().on); T.ok(document.getElementById('s-net').hidden);
  });
});
