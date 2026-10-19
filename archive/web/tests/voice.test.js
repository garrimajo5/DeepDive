'use strict';
/* Голосовая связь экипажа: WebRTC и микрофон подменены заглушками */
T.describe('Голосовая связь', () => {
  const N = () => G.Net, Vo = () => G.Voice, D = () => G.Game.debug, C = () => G.Ctl;
  const tick = () => new Promise(r => setTimeout(r, 0));
  class FakeWS {
    constructor() { this.sent = []; this.readyState = 1; FakeWS.last = this; }
    send(s) { this.sent.push(JSON.parse(s)); }
    close() {}
    msg(o) { this.onmessage({ data: JSON.stringify(o) }); }
  }
  class FakePC {
    constructor(cfg) { this.cfg = cfg; this.closed = false; this.ice = []; this.senders = []; this.trs = []; FakePC.all.push(this); }
    addTransceiver(kind, o) {
      this.kind = kind; this.dir = o.direction;
      const s = { track: null, replaceTrack(t) { this.track = t; return Promise.resolve(); } }; this.senders.push(s);
      const tr = { direction: o.direction, sender: s, receiver: { track: { kind } } }; this.trs.push(tr); return tr;
    }
    getTransceivers() { return this.trs; }
    async createOffer() { return { type: 'offer', sdp: 'o' }; }
    async createAnswer() { return { type: 'answer', sdp: 'a' }; }
    async setLocalDescription(d) { this.local = d; }
    async setRemoteDescription(d) { this.remote = d; if (d.type === 'offer' && !this.trs.length) this.addTransceiver('audio', { direction: 'recvonly' }); } // как в браузере: канал из приглашения
    async addIceCandidate(c) { this.ice.push(c); }
    close() { this.closed = true; }
  }
  let micAsked = 0;
  const track = { enabled: true, stop() {} };
  const setup = () => {
    FakePC.all = []; micAsked = 0; track.enabled = true;
    Vo().RTC = FakePC; Vo().media = { getUserMedia: async () => { micAsked++; return { getAudioTracks: () => [track] }; } };
  };
  const join = (id, peers) => {
    N().connect('ws://test/ws', 'ковчег', 'Я', FakeWS); const ws = FakeWS.last; ws.onopen();
    ws.msg({ t: 'joined', id, room: 'КОВЧЕГ', host: !peers.length, hostId: peers.length ? peers[0].id : id, peers });
    ws.sent.length = 0; return ws;
  };
  const leave = () => { Vo().reset(); if (N().ws) N().ws.onclose = null; Object.assign(N(), { ws: null, on: false, host: false, status: 'off', peers: [] }); G.Roles.reset(); N().hud(); C().talkDown = false; Vo().RTC = null; Vo().media = null; };
  const rtc = ws => ws.sent.filter(m => m.t === 'rtc');

  T.test('новый член экипажа: звонит тот, у кого id меньше', async () => {
    setup(); const ws = join(1, []);
    ws.msg({ t: 'peer', ev: 'join', id: 2, name: 'Лёва' }); await tick();
    T.eq(FakePC.all.length, 1); T.eq(FakePC.all[0].kind, 'audio'); T.eq(FakePC.all[0].dir, 'sendrecv');
    T.eq(FakePC.all[0].cfg.iceServers.length, 0, 'внешний сервер в настройках связи');
    const o = rtc(ws); T.eq(o.length, 1); T.eq(o[0].to, 2); T.eq(o[0].data.sdp.type, 'offer');
    leave();
  });

  T.test('пришло приглашение — уходит ответ, адреса принимаются', async () => {
    setup(); const ws = join(5, [{ id: 1, name: 'Маша' }]);
    ws.msg({ t: 'peer', ev: 'join', id: 7, name: 'Новый' }); await tick();
    T.eq(rtc(ws).filter(m => m.to === 7).length, 1, 'не позвонил новичку с большим id');
    ws.sent.length = 0;
    ws.msg({ t: 'rtc', from: 1, data: { sdp: { type: 'offer', sdp: 'o' } } }); await tick(); await tick();
    const a = rtc(ws).find(m => m.to === 1); T.ok(a, 'нет ответа'); T.eq(a.data.sdp.type, 'answer');
    const pc1 = Vo().pcs.get(1).pc;
    T.eq(pc1.remote.type, 'offer');
    T.eq(pc1.trs.length, 1, 'у отвечающего лишний звуковой канал — его не услышат');
    T.eq(pc1.trs[0].direction, 'sendrecv', 'отвечающий только слушает');
    T.eq(Vo().pcs.get(1).sender, pc1.trs[0].sender);
    ws.msg({ t: 'rtc', from: 1, data: { ice: { candidate: 'c1' } } }); await tick();
    T.eq(Vo().pcs.get(1).pc.ice[0].candidate, 'c1');
    /* свой адрес — адресату */
    Vo().pcs.get(1).pc.onicecandidate({ candidate: { candidate: 'mine' } });
    T.eq(rtc(ws).slice(-1)[0].data.ice.candidate, 'mine');
    leave();
  });

  T.test('кнопка «Связь»: микрофон работает только пока её держат', async () => {
    setup(); const ws = join(1, []);
    ws.msg({ t: 'peer', ev: 'join', id: 2, name: 'Лёва' }); await tick();
    T.ok(!document.getElementById('b-talk').hidden, 'нет кнопки в экипаже');
    T.eq(micAsked, 0, 'микрофон спрошен без нажатия');
    C().talkDown = true; D().frame(1); await tick(); await tick();
    T.eq(micAsked, 1); T.ok(track.enabled, 'микрофон молчит при нажатой кнопке');
    T.eq(FakePC.all[0].senders[0].track, track, 'звук не отдан в соединение');
    T.ok(ws.sent.some(m => m.t === 'talk' && m.on)); T.ok(document.getElementById('s-talk').textContent.includes('вы говорите'));
    C().talkDown = false; D().frame(1);
    T.ok(!track.enabled, 'микрофон открыт после отпускания');
    T.ok(ws.sent.some(m => m.t === 'talk' && !m.on));
    C().talkDown = true; D().frame(1); await tick(); T.eq(micAsked, 1, 'микрофон спрашивается каждый раз');
    leave();
  });

  T.test('кто говорит — видно на приборах; ушёл — соединение закрыто', async () => {
    setup(); const ws = join(1, []);
    ws.msg({ t: 'peer', ev: 'join', id: 2, name: 'Лёва' }); await tick();
    ws.msg({ t: 'talk', from: 2, name: 'Лёва', on: true });
    const el = document.getElementById('s-talk'); T.ok(!el.hidden); T.ok(el.textContent.includes('Лёва'));
    ws.msg({ t: 'talk', from: 2, name: 'Лёва', on: false }); T.ok(el.hidden);
    const pc = Vo().pcs.get(2).pc;
    ws.msg({ t: 'talk', from: 2, name: 'Лёва', on: true });
    ws.msg({ t: 'peer', ev: 'leave', id: 2, name: 'Лёва' });
    T.ok(pc.closed, 'соединение не закрыто'); T.ok(!Vo().pcs.has(2)); T.ok(el.hidden, 'ушедший всё ещё «говорит»');
    leave();
  });

  T.test('в одиночной игре связи нет (контроль)', () => {
    T.ok(!N().on); T.ok(document.getElementById('b-talk').hidden);
    C().talkDown = true; D().frame(1); T.ok(!Vo().talking); C().talkDown = false;
  });
});
