'use strict';
/* Звуковая картина: песни ледокрылов (с направлением и расстоянием), гул рифа у кораллов,
   тревоги корабля. Логика здесь, звук — в G.Audio. Каждый звуковой сигнал пишется в G.Sound.log,
   чтобы тесты могли проверить, что и когда прозвучало, даже без звуковой карты. */
(function (G) {
  const SONG_R = 160, NOTE_R = 110, REEF_R = 30;
  /* лад песни ледокрыла: низкие ноты пентатоники */
  const SCALE = [110, 123.5, 146.8, 164.8, 196, 220];
  const Snd = G.Sound = { log: [], songCd: 8, creakCd: 20, reef: 0, alarmT: {}, phrase: 0 };
  Snd.cue = function (name, a, b) { Snd.log.push({ name, t: G.Game.t, a, b }); if (Snd.log.length > 200) Snd.log.shift(); };
  Snd.reset = function () { Snd.log.length = 0; Snd.songCd = 8; Snd.creakCd = 20; Snd.reef = 0; Snd.alarmT = {}; Snd.phrase = 0; };
  /* песня — 3–5 нот с глиссандо, у каждого ската свой мотив */
  Snd.song = function (ray, d) {
    const local = G.Ship.group.worldToLocal(ray.p.clone());
    const pan = Math.max(-1, Math.min(1, local.x / 40)); // слева или справа от корабля
    const n = 3 + ((ray.i + Snd.phrase) % 3), notes = [];
    for (let k = 0; k < n; k++) notes.push(SCALE[(ray.i * 2 + k * 3 + Snd.phrase) % SCALE.length] * (ray.i ? 1 : 0.75));
    Snd.phrase++;
    Snd.cue('song', d, pan);
    if (G.Audio.raySong) G.Audio.raySong(notes, d, pan);
    if (d < NOTE_R) G.Eco.emit('ray', 'song', ray.p, () => `${G.cap(G.nm('ray'))} поёт где-то ${pan < -0.3 ? 'слева' : pan > 0.3 ? 'справа' : 'рядом'} — низкий голос слышен сквозь корпус`);
  };
  /* тревога раз в period секунд, пока условие держится */
  function alarm(name, on, period, dt) {
    const t = Snd.alarmT;
    if (!on) { t[name] = 0; return; }
    t[name] = (t[name] || 0) - dt;
    if (t[name] <= 0) { t[name] = period; Snd.cue(name); if (G.Audio.alarmCue) G.Audio.alarmCue(name); }
  }
  Snd.update = function (dt) {
    const S = G.Ship, E = G.Eco;
    /* песни ледокрылов */
    Snd.songCd -= dt; Snd.creakCd -= dt;
    if (Snd.songCd <= 0) {
      Snd.songCd = 14 + (Snd.phrase % 4) * 3;
      let best = null, bd = SONG_R;
      E.rays.forEach(r => { const d = r.p.distanceTo(S.center); if (d < bd) { bd = d; best = r; } });
      if (best) Snd.song(best, bd);
    }
    if (Snd.creakCd <= 0) { Snd.creakCd = 25; Snd.cue('creak'); G.Audio.creak(); } // корпус поскрипывает от давления
    /* гул рифа: чем ближе к кораллам, тем громче */
    let dc = 1e9;
    for (const c of G.World.coralSpots) { const d = Math.hypot(c.x - S.pos.x, c.z - S.pos.z); if (d < dc) dc = d; }
    const flower = G.World.pois.find(p => p.key === 'flower');
    const want = Math.max(0, 1 - dc / REEF_R) * 0.7 + (flower ? Math.max(0, 1 - Math.hypot(flower.pos.x - S.pos.x, flower.pos.z - S.pos.z) / 60) * 0.3 : 0);
    Snd.reef += (want - Snd.reef) * Math.min(1, dt * 0.8);
    if (G.Audio.reefHum) G.Audio.reefHum(Snd.reef);
    /* тревоги */
    let charge = 0; E.preds.forEach(p => { if (p.state === 'charge') charge = Math.max(charge, 1 - p.p.distanceTo(S.center) / 40); });
    alarm('hull', S.hull > 0 && S.hull < 25, 2.2, dt);
    alarm('charge', charge > 0.2, 0.9, dt);
    alarm('latch', !!E.latched, 1.6, dt);
    alarm('energy', S.energy < 15, 4, dt);
    alarm('heat', G.Power.hot && G.Power.heat > 60, Math.max(0.5, 2.2 - G.Power.heat / 60), dt);
  };
})(window.G);
