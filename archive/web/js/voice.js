'use strict';
/* Голосовая связь экипажа по внутренней связи корабля. Звук идёт напрямую между телефонами (WebRTC),
   сервер только передаёт приглашения (сообщения rtc). Каждый с каждым, до пяти человек.
   Говорить — удерживать кнопку «Связь» (или V). Микрофон спрашивается при первом нажатии.
   Пока кнопка отпущена, микрофон молчит. Кто говорит, видно на приборах. */
(function (G) {
  const Vo = G.Voice = { pcs: new Map(), track: null, talking: false, asking: false, speakers: new Map(), RTC: null, media: null, audio: [] };
  const N = () => G.Net;
  const RTC = () => Vo.RTC || window.RTCPeerConnection;
  Vo.supported = () => !!RTC();
  /* соединение с одним членом экипажа; звонит тот, у кого id меньше. Звонящий сам заводит звуковой канал,
     отвечающий берёт канал из приглашения — иначе у него будет второй, несогласованный канал и его не услышат */
  Vo.pc = function (id, caller) {
    if (Vo.pcs.has(id)) return Vo.pcs.get(id);
    const Pc = RTC(); if (!Pc) return null;
    const pc = new Pc({ iceServers: [] }); // в одной Wi‑Fi сети хватает своих адресов, внешних серверов нет
    const ent = { pc, sender: null, id };
    if (caller) Vo.useSender(ent, pc.addTransceiver('audio', { direction: 'sendrecv' }));
    Vo.pcs.set(id, ent);
    pc.onicecandidate = e => { if (e.candidate) N().send({ t: 'rtc', to: id, data: { ice: e.candidate.toJSON ? e.candidate.toJSON() : e.candidate } }); };
    pc.ontrack = e => {
      const a = new Audio(); a.autoplay = true; a.srcObject = e.streams && e.streams[0] ? e.streams[0] : new MediaStream([e.track]);
      ent.audio = a; Vo.audio.push(a); const p = a.play && a.play(); if (p && p.catch) p.catch(() => {});
    };
    return ent;
  };
  Vo.useSender = function (ent, tr) { ent.sender = tr.sender; if (Vo.track) tr.sender.replaceTrack(Vo.track); };
  Vo.offer = async function (id) {
    const ent = Vo.pc(id, true); if (!ent) return;
    const o = await ent.pc.createOffer(); await ent.pc.setLocalDescription(o);
    N().send({ t: 'rtc', to: id, data: { sdp: { type: o.type, sdp: o.sdp } } });
  };
  /* сообщения сервера */
  Vo.onRtc = async function (m) {
    const id = m.from, d = m.data || {}; if (!id) return;
    const ent = Vo.pc(id, false); if (!ent) return;
    try {
      if (d.sdp) {
        await ent.pc.setRemoteDescription(d.sdp);
        if (d.sdp.type === 'offer' && !ent.sender) { // канал из приглашения: и слушаем, и говорим
          const tr = ent.pc.getTransceivers().find(t => t.receiver && t.receiver.track && t.receiver.track.kind === 'audio');
          if (tr) { tr.direction = 'sendrecv'; Vo.useSender(ent, tr); }
        }
        if (d.sdp.type === 'offer') { const a = await ent.pc.createAnswer(); await ent.pc.setLocalDescription(a); N().send({ t: 'rtc', to: id, data: { sdp: { type: a.type, sdp: a.sdp } } }); }
      } else if (d.ice) await ent.pc.addIceCandidate(d.ice);
    } catch (e) { console.warn('rtc', e); }
  };
  /* новый член экипажа: звонит тот, у кого id меньше, чтобы не было встречных предложений */
  Vo.onJoin = function (id) { if (Vo.supported() && N().id < id) Vo.offer(id); };
  Vo.onLeave = function (id) {
    const ent = Vo.pcs.get(id); if (ent) { try { ent.pc.close(); } catch (_) {} if (ent.audio) ent.audio.srcObject = null; Vo.pcs.delete(id); }
    Vo.speakers.delete(id); Vo.hud();
  };
  Vo.onTalk = function (m) { if (m.on) Vo.speakers.set(m.from, m.name); else Vo.speakers.delete(m.from); Vo.hud(); };
  /* микрофон: один раз, по первому нажатию кнопки */
  Vo.mic = async function () {
    if (Vo.track || Vo.asking) return Vo.track;
    const md = Vo.media || (navigator.mediaDevices); if (!md || !md.getUserMedia) { G.Game.toast('Нет микрофона', 'Браузер не даёт доступ к микрофону. Нужен HTTPS или адрес в одной сети.'); return null; }
    Vo.asking = true;
    try {
      const st = await md.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true } });
      Vo.track = st.getAudioTracks()[0]; Vo.track.enabled = Vo.talking;
      Vo.pcs.forEach(ent => { if (ent.sender) ent.sender.replaceTrack(Vo.track); });
    } catch (e) { G.Game.toast('Микрофон закрыт', 'Без микрофона вас не слышно, но экипаж вы слышите.'); }
    Vo.asking = false; return Vo.track;
  };
  /* каждый кадр: кнопка «Связь» включает и выключает микрофон */
  Vo.update = function () {
    const want = !!(G.Ctl.talkDown && N().on);
    if (want === Vo.talking) return;
    Vo.talking = want;
    if (want && !Vo.track) Vo.mic();
    if (Vo.track) Vo.track.enabled = want;
    N().send({ t: 'talk', on: want });
    if (want) G.Audio.beep(1200);
    Vo.hud();
  };
  Vo.hud = function () {
    const b = document.getElementById('b-talk'); if (b) { b.hidden = !N().on; b.classList.toggle('on', Vo.talking); }
    const el = document.getElementById('s-talk'); if (!el) return;
    const names = [...Vo.speakers.values()];
    el.hidden = !names.length && !Vo.talking;
    el.textContent = Vo.talking ? 'Связь: вы говорите' : names.length ? 'Связь: ' + names.join(', ') : '';
  };
  Vo.reset = function () {
    [...Vo.pcs.keys()].forEach(Vo.onLeave);
    if (Vo.track) { try { Vo.track.stop(); } catch (_) {} Vo.track = null; }
    Vo.talking = false; Vo.speakers.clear(); Vo.audio.length = 0; Vo.hud();
  };
})(window.G);
