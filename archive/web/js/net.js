'use strict';
/* Сетевой экипаж (клиент сервера server/server.js). Подключение по адресу игры с ?room=КОВЧЕГ&name=Имя.
   Хост (первый в комнате) ведёт настоящий корабль и 10 раз в секунду рассылает его состояние.
   Гости видят тот же корабль и шлют хосту свой ввод с крестовины и кнопок: управлять может любой.
   Пока синхронизируется корабль; существа у каждого считаются свои. */
(function (G) {
  const RATE = 0.1;
  const N = G.Net = { ws: null, on: false, host: false, id: 0, room: '', name: '', peers: [], sendT: 0, target: null, remote: null, lastState: 0, status: 'off' };

  N.connect = function (url, room, name, WS) {
    WS = WS || window.WebSocket; if (!WS) return false;
    N.room = room; N.name = name || 'Гость'; N.status = 'connecting';
    const ws = N.ws = new WS(url);
    ws.onopen = () => { N.on = true; N.status = 'open'; ws.send(JSON.stringify({ t: 'join', room: N.room, name: N.name })); };
    ws.onmessage = e => { let m; try { m = JSON.parse(e.data); } catch (_) { return; } N.handle(m); };
    ws.onclose = () => { N.on = false; N.status = 'off'; N.host = false; G.Roles.reset(); G.Voice.reset(); N.hud(); G.Game.toast && G.Game.toast('Связь потеряна', 'Корабль снова только ваш.'); };
    N.hud(); return true;
  };
  N.handle = function (m) {
    if (m.t === 'joined') {
      N.id = m.id; N.host = m.host; N.peers = m.peers || []; N.room = m.room; N.status = 'joined';
      G.Game.toast('Экипаж: ' + m.room, m.host ? 'Вы хост: ваш корабль — общий. Остальные подключатся по той же ссылке.' : 'Вы на борту. Корабль считает игра хоста, а посты делятся по ролям.');
      G.Roles.reset(); G.Roles.pick(); // первая свободная роль: хосту — пилот
    } else if (m.t === 'peer') {
      if (m.ev === 'role') G.Roles.onPeer(m);
      else if (m.ev === 'join') { N.peers.push({ id: m.id, name: m.name }); G.Voice.onJoin(m.id); G.Game.feedMsg && G.Game.feedMsg(`На борт поднялся: ${m.name}`, true); }
      else { N.peers = N.peers.filter(p => p.id !== m.id); G.Voice.onLeave(m.id); G.Game.feedMsg && G.Game.feedMsg(`Экипаж покинул: ${m.name}`); }
    } else if (m.t === 'host') {
      N.host = m.id === N.id;
      if (N.host) G.Game.toast('Вы теперь хост', 'Прежний хост ушёл — корабль ведёт ваша игра.');
    } else if (m.t === 'state' && !N.host) { N.target = m.s; N.lastState = G.Game.t; }
    else if (m.t === 'input' && N.host) N.remote = Object.assign({ t: G.Game.t }, m.i);
    else if (m.t === 'error') G.Roles.onError(m);
    else if (m.t === 'rtc') G.Voice.onRtc(m);
    else if (m.t === 'talk') G.Voice.onTalk(m);
    N.hud();
  };
  N.send = o => { if (N.ws && N.on && N.ws.readyState === 1) N.ws.send(JSON.stringify(o)); };
  N.stateOf = function () {
    const S = G.Ship;
    return { p: [S.pos.x, S.pos.y, S.pos.z].map(v => +v.toFixed(2)), yaw: +S.yaw.toFixed(3), sp: +S.speed.toFixed(2), vy: +S.vy.toFixed(2), hull: Math.round(S.hull), en: Math.round(S.energy), light: S.light };
  };
  /* до физики корабля: хост берёт ввод гостя, если свой молчит */
  N.beforeShip = function () {
    if (!N.on || !N.host || !N.remote) return;
    const r = N.remote, S = G.Ship;
    if (G.Game.t - r.t > 0.5) { N.remote = null; return; } // гость отпустил крестовину
    if (!S.input.thrust && !S.input.turn && !S.input.vert) { S.input.thrust = r.th || 0; S.input.turn = r.tu || 0; S.input.vert = r.ve || 0; }
    if (r.light !== undefined && r.light !== S.light && r.lightT !== N.lightT) { N.lightT = r.lightT; G.Game.toggleLight(); }
    if (r.pingT && r.pingT !== N.pingT) { N.pingT = r.pingT; G.Sonar.ping(); }
  };
  /* после кадра: хост рассылает состояние, гость тянет корабль к состоянию хоста и шлёт свой ввод */
  N.update = function (dt) {
    if (!N.on) return;
    const S = G.Ship;
    N.sendT -= dt;
    if (N.host) { if (N.sendT <= 0) { N.sendT = RATE; N.send({ t: 'state', s: N.stateOf() }); } return; }
    const st = N.target;
    if (st) {
      const k = Math.min(1, dt * 8);
      S.pos.x += (st.p[0] - S.pos.x) * k; S.pos.y += (st.p[1] - S.pos.y) * k; S.pos.z += (st.p[2] - S.pos.z) * k;
      let dy = st.yaw - S.yaw; dy = Math.atan2(Math.sin(dy), Math.cos(dy)); S.yaw += dy * k;
      S.speed = st.sp; S.vy = st.vy; S.hull = st.hull; S.energy = st.en; S.light = st.light;
      S.applyTransform();
    }
    if (N.sendT <= 0) {
      N.sendT = RATE;
      const i = S.input;
      if (i.thrust || i.turn || i.vert || N.pendingLight || N.pendingPing) { N.send({ t: 'input', i: { th: i.thrust, tu: i.turn, ve: i.vert, light: N.pendingLight ? !S.light : undefined, lightT: N.pendingLight, pingT: N.pendingPing } }); N.pendingLight = 0; N.pendingPing = 0; }
    }
  };
  N.isGuest = () => N.on && !N.host && N.status === 'joined';
  N.hud = function () {
    const el = document.getElementById('s-net'); if (!el) return;
    el.hidden = !N.on && N.status === 'off';
    el.textContent = N.status === 'connecting' ? 'Экипаж: подключение…' : `Экипаж ${N.room} · ${N.peers.length + 1} · ${N.host ? 'хост' : 'гость'}${G.Roles.mine ? ' · ' + G.Roles.get(G.Roles.mine).name : ''}`;
    el.title = 'Коснитесь, чтобы сменить роль';
    G.Voice.hud();
  };
  /* ?room=...&name=... в адресе — подключиться к серверу, с которого открыта игра */
  N.auto = function () {
    const q = new URLSearchParams(location.search), room = q.get('room');
    if (!room || location.protocol === 'file:') return false;
    return N.connect((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws', room, q.get('name') || 'Гость');
  };
})(window.G);
