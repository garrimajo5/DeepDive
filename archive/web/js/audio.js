'use strict';
/* Процедурный звук на WebAudio: гул воды, двигатель, сонар, удары, песни ледокрылов */
(function (G) {
  const A = G.Audio = { ctx: null, on: false, muted: false, vol: 0.7 };
  A.init = function () {
    if (A.ctx) { if (A.ctx.state === 'suspended') A.ctx.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return;
    const c = A.ctx = new AC();
    A.master = c.createGain(); A.master.gain.value = A.muted ? 0 : A.vol; A.master.connect(c.destination);
    A.wet = c.createGain(); A.wet.gain.value = 0.5;
    const dl = c.createDelay(1.5); dl.delayTime.value = 0.31;
    const fb = c.createGain(); fb.gain.value = 0.42;
    const lp = c.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 1400;
    A.wet.connect(dl); dl.connect(lp); lp.connect(fb); fb.connect(dl); lp.connect(A.master);
    const len = c.sampleRate * 3, brown = c.createBuffer(1, len, c.sampleRate), white = c.createBuffer(1, c.sampleRate, c.sampleRate);
    const bd = brown.getChannelData(0), wd = white.getChannelData(0);
    let last = 0;
    for (let i = 0; i < len; i++) { const w = Math.random() * 2 - 1; last = (last + 0.02 * w) / 1.02; bd[i] = last * 3.2; }
    for (let i = 0; i < wd.length; i++) wd[i] = Math.random() * 2 - 1;
    A.white = white;
    const amb = c.createBufferSource(); amb.buffer = brown; amb.loop = true;
    const af = c.createBiquadFilter(); af.type = 'lowpass'; af.frequency.value = 420;
    const ag = c.createGain(); ag.gain.value = 0.32;
    amb.connect(af); af.connect(ag); ag.connect(A.master); amb.start();
    const dr = c.createOscillator(); dr.frequency.value = 46;
    const dg = c.createGain(); dg.gain.value = 0.045; dr.connect(dg); dg.connect(A.master); dr.start();
    const lfo = c.createOscillator(); lfo.frequency.value = 0.07;
    const lg = c.createGain(); lg.gain.value = 0.03; lfo.connect(lg); lg.connect(dg.gain); lfo.start();
    const eo = c.createOscillator(); eo.type = 'sawtooth'; eo.frequency.value = 40;
    const ef = c.createBiquadFilter(); ef.type = 'lowpass'; ef.frequency.value = 160;
    const eg = c.createGain(); eg.gain.value = 0;
    eo.connect(ef); ef.connect(eg); eg.connect(A.master); eo.start();
    A.eng = { o: eo, g: eg };
    A.on = true;
  };
  function osc(type, f0, f1, t0, dur, vol, wet) {
    const c = A.ctx, o = c.createOscillator(), g = c.createGain();
    o.type = type; o.frequency.setValueAtTime(f0, t0);
    if (f1 !== f0) o.frequency.exponentialRampToValueAtTime(f1, t0 + dur);
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(vol, t0 + Math.min(0.03, dur * 0.2));
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    o.connect(g); g.connect(A.master); if (wet) g.connect(A.wet);
    o.start(t0); o.stop(t0 + dur + 0.05);
  }
  function noise(t0, dur, vol, type, f0, f1, q) {
    const c = A.ctx, s = c.createBufferSource(); s.buffer = A.white; s.loop = true;
    const f = c.createBiquadFilter(); f.type = type; f.frequency.setValueAtTime(f0, t0); f.frequency.exponentialRampToValueAtTime(f1, t0 + dur); f.Q.value = q || 1;
    const g = c.createGain(); g.gain.setValueAtTime(0.0001, t0); g.gain.exponentialRampToValueAtTime(vol, t0 + 0.02); g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    s.connect(f); f.connect(g); g.connect(A.master); s.start(t0); s.stop(t0 + dur + 0.05);
  }
  const ok = () => A.on && !A.muted;
  const now = () => A.ctx.currentTime;
  A.engine = l => { if (!A.on) return; const t = now(); A.eng.g.gain.setTargetAtTime(A.muted ? 0 : 0.015 + l * 0.08, t, 0.3); A.eng.o.frequency.setTargetAtTime(36 + l * 34, t, 0.4); };
  A.ping = () => { if (!ok()) return; const t = now(); osc('sine', 1250, 1180, t, 0.9, 0.3, true); osc('sine', 2500, 2400, t, 0.3, 0.05, true); };
  A.thud = () => { if (!ok()) return; const t = now(); osc('sine', 90, 35, t, 0.7, 0.6); noise(t, 0.5, 0.4, 'lowpass', 900, 120); osc('triangle', 300, 120, t, 0.4, 0.08, true); };
  A.beep = f => { if (!ok()) return; osc('square', f || 600, f || 600, now(), 0.09, 0.05); };
  A.door = () => { if (!ok()) return; const t = now(); noise(t, 0.7, 0.18, 'bandpass', 300, 1200, 2); osc('sine', 120, 80, t, 0.5, 0.1); };
  A.zap = () => { if (!ok()) return; const t = now(); noise(t, 0.6, 0.35, 'highpass', 3000, 600, 1); osc('sawtooth', 80, 40, t, 0.6, 0.25); osc('square', 1800, 200, t, 0.3, 0.06); };
  let lastTick = -1;
  A.scanTick = p => { if (!ok()) return; const step = Math.floor(p * 8); if (step !== lastTick) { lastTick = step; osc('sine', 800 + step * 90, 800 + step * 90, now(), 0.06, 0.05); } };
  A.scanDone = () => { if (!ok()) return; const t = now(); [660, 880, 1320].forEach((f, i) => osc('sine', f, f, t + i * 0.09, 0.25, 0.12, true)); };
  A.discover = () => { if (!ok()) return; const t = now(); [392, 523, 659, 784].forEach((f, i) => osc('triangle', f, f, t + i * 0.14, 0.7, 0.1, true)); };
  A.whale = d => { if (!ok()) return; const t = now(), v = 0.25 * Math.max(0.15, 1 - d / 120); osc('sine', 210, 120, t, 2.6, v, true); osc('sine', 315, 180, t + 0.3, 2.2, v * 0.4, true); };
  A.creak = () => { if (!ok()) return; const t = now(); noise(t, 1.4, 0.08, 'bandpass', 180, 90, 8); osc('sawtooth', 55, 48, t, 1.2, 0.03); };
  A.latch = () => { if (!ok()) return; const t = now(); noise(t, 0.8, 0.3, 'bandpass', 1500, 400, 6); osc('square', 60, 30, t, 0.8, 0.1); };
  /* гул трубного органа: низкий аккорд, громкость 0..1 по расстоянию до губки */
  A.organ = l => {
    if (!A.on) return;
    if (!A.org) {
      const c = A.ctx, g = c.createGain(); g.gain.value = 0; g.connect(A.master); g.connect(A.wet);
      [55, 82.4, 110.3].forEach((f, i) => { const o = c.createOscillator(); o.type = i ? 'triangle' : 'sine'; o.frequency.value = f; const og = c.createGain(); og.gain.value = i ? 0.25 : 0.5; o.connect(og); og.connect(g); o.start(); });
      A.org = g;
    }
    A.org.gain.setTargetAtTime(A.muted ? 0 : l * l * 0.12, A.ctx.currentTime, 0.5);
  };
  /* сирена пробоины: два тона, пока level > 0 */
  A.siren = (level, t) => {
    if (!A.on) return;
    if (!A.sir) { const c = A.ctx, o = c.createOscillator(), g = c.createGain(); o.type = 'square'; o.frequency.value = 620; g.gain.value = 0; o.connect(g); g.connect(A.master); o.start(); A.sir = { o, g }; }
    const on = level > 0 && !A.muted, now = A.ctx.currentTime;
    A.sir.g.gain.setTargetAtTime(on ? (Math.sin((t || 0) * 6) > 0 ? 0.05 : 0.012) : 0, now, 0.02);
    if (on) A.sir.o.frequency.setTargetAtTime(Math.sin((t || 0) * 3) > 0 ? 620 : 780, now, 0.01);
  };
  /* песня ледокрыла: ноты с глиссандо, слева или справа, тише издалека */
  A.raySong = (notes, d, pan) => {
    if (!ok()) return;
    const c = A.ctx, t0 = now(), v = 0.22 * Math.max(0.12, 1 - d / 160);
    const p = c.createStereoPanner ? c.createStereoPanner() : null; if (p) { p.pan.value = pan || 0; p.connect(A.master); p.connect(A.wet); }
    notes.forEach((f, i) => {
      const o = c.createOscillator(), g = c.createGain(), t = t0 + i * 0.9;
      o.type = 'sine'; o.frequency.setValueAtTime(f * 1.06, t); o.frequency.exponentialRampToValueAtTime(f, t + 0.25); o.frequency.exponentialRampToValueAtTime(f * 0.92, t + 1.3);
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(v, t + 0.2); g.gain.exponentialRampToValueAtTime(0.0001, t + 1.4);
      o.connect(g); g.connect(p || A.master); if (!p) g.connect(A.wet); o.start(t); o.stop(t + 1.5);
    });
  };
  /* гул рифа: мягкий аккорд и шорох, громкость 0..1 */
  A.reefHum = l => {
    if (!A.on) return;
    if (!A.reef) {
      const c = A.ctx, g = c.createGain(); g.gain.value = 0; g.connect(A.master);
      [82.4, 123.5, 164.8].forEach((f, i) => { const o = c.createOscillator(); o.type = 'sine'; o.frequency.value = f; const og = c.createGain(); og.gain.value = [0.5, 0.3, 0.2][i]; const lfo = c.createOscillator(); lfo.frequency.value = 0.11 + i * 0.07; const lg = c.createGain(); lg.gain.value = og.gain.value * 0.5; lfo.connect(lg); lg.connect(og.gain); lfo.start(); o.connect(og); og.connect(g); o.start(); });
      const s = c.createBufferSource(); s.buffer = A.white; s.loop = true; const f = c.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 900; f.Q.value = 0.8; const sg = c.createGain(); sg.gain.value = 0.08; s.connect(f); f.connect(sg); sg.connect(g); s.start();
      A.reef = g;
    }
    A.reef.gain.setTargetAtTime(A.muted ? 0 : l * 0.09, A.ctx.currentTime, 0.6);
  };
  /* короткие сигналы тревоги на разные беды */
  A.alarmCue = name => {
    if (!ok()) return; const t = now();
    if (name === 'hull') { osc('square', 440, 440, t, 0.12, 0.05); osc('square', 330, 330, t + 0.18, 0.14, 0.05); }
    else if (name === 'charge') osc('sawtooth', 520, 900, t, 0.35, 0.04);
    else if (name === 'latch') noise(t, 0.25, 0.12, 'highpass', 4000, 2500, 2);
    else if (name === 'energy') osc('sine', 660, 520, t, 0.25, 0.04);
    else if (name === 'heat') { osc('triangle', 880, 880, t, 0.1, 0.05); osc('triangle', 880, 880, t + 0.16, 0.1, 0.05); }
  };
  A.alarm = () => { if (!ok()) return; osc('square', 880, 660, now(), 0.35, 0.05); };
  A.toggleMute = () => { A.muted = !A.muted; if (A.master) A.master.gain.value = A.muted ? 0 : A.vol; return A.muted; };
  /* громкость 0..1 из настроек; 0 — звук выключен */
  A.setVolume = v => { A.vol = Math.max(0, Math.min(1, v)); A.muted = A.vol === 0; if (A.master) A.master.gain.value = A.muted ? 0 : A.vol; };
})(window.G);
