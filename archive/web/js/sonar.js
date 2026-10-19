'use strict';
/* Сонар: карта рельефа на голостоле, импульс показывает существ и необычные места */
(function (G) {
  const So = G.Sonar = { blips: [], pingT: -99, range: 110 };

  So.init = function () {
    const N = 256, base = document.createElement('canvas'); base.width = base.height = N;
    const x = base.getContext('2d'), img = x.createImageData(N, N), d = img.data;
    for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) {
      const wx = -350 + (i + 0.5) / N * 700, wz = -350 + (j + 0.5) / N * 700;
      const h = G.World.height(wx, wz);
      const t = G.clamp((h + 110) / 104, 0, 1);
      const band = ((h % 6) + 6) % 6, line = band < 0.55 ? 1 : 0;
      const k = (j * N + i) * 4;
      d[k] = 6 + 28 * t + line * 35; d[k + 1] = 38 + 150 * t + line * 60; d[k + 2] = 48 + 110 * t + line * 50; d[k + 3] = 255;
    }
    x.putImageData(img, 0, 0);
    So.base = base;
    So.tex = G.canvasTex(512, 512, () => {});
    So.ctx = So.tex.userData.ctx;
  };

  So.ping = function () {
    const S = G.Ship;
    if (G.Power.k('son') <= 0) { G.Game.toast('Сонар обесточен', G.Power.scram > 0 ? 'Аварийный сброс реактора' : 'В машинном отделении у сонара 0 единиц'); G.Audio.beep(220); return; }
    const cost = G.Cargo.has('sonar') ? 4 : 6; // фильтр сонара из ракушек
    if (S.energy < cost) { G.Game.toast('Мало энергии', `Для импульса нужно ${cost} единиц`); return; }
    So.range = 110 * G.Power.k('son'); // дальность импульса — от доли сонара в реакторе
    if (G.Net.isGuest()) G.Net.pendingPing = G.Game.t; // и хост делает импульс у себя
    S.energy -= cost; So.pingT = G.Game.t; G.Audio.ping();
    if (G.Silt && G.Silt.inside) { // сонарная тьма: импульс вязнет в иле, на столе одни помехи
      So.blips = []; So.jamT = G.Game.t;
      G.Game.toast('Сонар ослеп', 'Импульс вязнет в облаке ила. Выйдите из мути, чтобы увидеть, что вокруг.');
      G.Eco.onPing(S.center.clone()); return;
    }
    So.blips = G.Eco.scanTargets()
      .filter(tg => !tg.noSonar && Math.hypot(tg.pos.x - S.pos.x, tg.pos.z - S.pos.z) < So.range)
      .map(tg => ({ x: tg.pos.x, z: tg.pos.z, sp: tg.sp }));
    G.World.pois.forEach(p => { if (!p.pinged && Math.hypot(p.pos.x - S.pos.x, p.pos.z - S.pos.z) < 170) { p.pinged = true; G.Save.mark(); } });
    G.Eco.onPing(S.center.clone());
  };

  let acc = 0;
  So.update = function (dt, t) {
    acc += dt; if (acc < 0.05) return; acc = 0;
    const c = So.ctx, S = G.Ship, R = 240, k = R / So.range;
    const cy = Math.cos(S.yaw), sy = Math.sin(S.yaw);
    const toC = (x, z) => { const dx = x - S.pos.x, dz = z - S.pos.z; return [256 + (dx * cy - dz * sy) * k, 256 + (dx * sy + dz * cy) * k]; };

    c.clearRect(0, 0, 512, 512);
    c.save(); c.beginPath(); c.arc(256, 256, R, 0, 7); c.clip();
    c.fillStyle = '#021218'; c.fillRect(0, 0, 512, 512);
    const age = t - So.pingT;
    c.save(); c.globalAlpha = 0.3 + 0.7 * Math.max(0, 1 - age / 12);
    c.translate(256, 256); c.rotate(S.yaw); c.scale(k, k); c.translate(-S.pos.x, -S.pos.z);
    c.drawImage(So.base, -350, -350, 700, 700);
    c.restore();
    c.strokeStyle = 'rgba(94,242,214,0.25)'; c.lineWidth = 1;
    [0.33, 0.66].forEach(f => { c.beginPath(); c.arc(256, 256, R * f, 0, 7); c.stroke(); });
    if (age < 2.5) { c.strokeStyle = `rgba(94,242,214,${(1 - age / 2.5).toFixed(2)})`; c.lineWidth = 4; c.beginPath(); c.arc(256, 256, R * age / 2.2, 0, 7); c.stroke(); }
    if (age < 12) {
      const a = Math.max(0, 1 - age / 12);
      So.blips.forEach(b => {
        const [x, y] = toC(b.x, b.z);
        const col = b.sp === 'pred' || b.sp === 'eel' || b.sp === 'leech' ? '255,93,108' : b.sp === 'ognevka' ? '255,140,60' : b.sp === 'hvaten' ? '206,130,255' : b.sp === 'krab' ? '255,170,90' : b.sp === 'ezh' ? '140,220,255' : b.sp === 'raduzh' ? '200,255,170' : b.sp === 'plankton' ? '120,255,230' : b.sp === 'monet' ? '255,230,140' : b.sp === 'grot' ? '230,200,150' : b.sp === 'skalnik' ? '255,120,90' : b.sp === 'prisoska' ? '200,220,230' : b.sp === 'kamen' ? '255,150,170' : b.sp === 'organ' ? '210,170,130' : b.sp === 'cushion' ? '240,150,200' : b.sp === 'bladder' ? '150,255,160' : b.sp === 'fan' ? '255,180,140' : b.sp === 'fern' ? '120,220,140' : b.sp === 'echo' ? '255,120,60' : b.sp === 'veil' ? '255,138,224' : b.sp === 'ray' ? '191,246,255' : '255,210,107';
        c.fillStyle = `rgba(${col},${a.toFixed(2)})`; c.beginPath(); c.arc(x, y, b.sp === 'veil' || b.sp === 'ray' || b.sp === 'grot' ? 10 : b.sp === 'ezh' ? 3 : 6, 0, 7); c.fill();
      });
    }
    if ((G.Silt && G.Silt.k > 0.05) || t - (So.jamT || -99) < 4) { // помехи на голостоле
      const n = 220 * Math.max(G.Silt ? G.Silt.k : 0, t - (So.jamT || -99) < 4 ? 1 : 0);
      for (let i = 0; i < n; i++) { const v = (Math.sin(i * 91.7 + t * 37.3) * 43758.5) % 1, w = (Math.sin(i * 47.1 + t * 11.9) * 15731.7) % 1; c.fillStyle = `rgba(160,140,110,${(0.25 + Math.abs(v) * 0.5).toFixed(2)})`; c.fillRect(256 + v * R, 256 + w * R, 3, 3); }
    }
    c.restore();

    c.font = '700 18px monospace'; c.textAlign = 'center'; c.textBaseline = 'middle';
    G.World.pois.forEach(p => {
      if (!p.found && !p.pinged) return;
      let [x, y] = toC(p.pos.x, p.pos.z);
      const dx = x - 256, dy = y - 256, d = Math.hypot(dx, dy);
      if (d > R - 14) { x = 256 + dx / d * (R - 14); y = 256 + dy / d * (R - 14); }
      c.fillStyle = p.found ? '#ffb259' : '#c79bff';
      c.beginPath(); c.moveTo(x, y - 11); c.lineTo(x + 11, y); c.lineTo(x, y + 11); c.lineTo(x - 11, y); c.closePath(); c.fill();
      if (!p.found) { c.fillStyle = '#021218'; c.fillText('?', x, y + 1); }
    });
    if (G.Run && G.Run.route) { // маршрут забега: пунктир по точкам, следующая — в кольце
      const pts = G.Run.route.pois.map(k => G.World.pois.find(p => p.key === k)).filter(Boolean), nx = G.Run.next();
      c.save(); c.beginPath(); c.arc(256, 256, R, 0, 7); c.clip();
      c.setLineDash([10, 8]); c.strokeStyle = 'rgba(255,178,89,.8)'; c.lineWidth = 3; c.beginPath();
      [{ pos: S.pos }].concat(pts.filter(p => !G.Run.visited.has(p.key))).forEach((p, i) => { const [x, y] = toC(p.pos.x, p.pos.z); i ? c.lineTo(x, y) : c.moveTo(x, y); });
      c.stroke(); c.setLineDash([]);
      if (nx) { let [x, y] = toC(nx.pos.x, nx.pos.z); const dx = x - 256, dy = y - 256, d = Math.hypot(dx, dy); if (d > R - 18) { x = 256 + dx / d * (R - 18); y = 256 + dy / d * (R - 18); } c.strokeStyle = '#ffb259'; c.lineWidth = 4; c.beginPath(); c.arc(x, y, 18 + Math.sin(t * 4) * 3, 0, 7); c.stroke(); }
      c.restore();
    }
    c.fillStyle = '#5ef2d6'; c.beginPath(); c.moveTo(256, 238); c.lineTo(267, 270); c.lineTo(245, 270); c.closePath(); c.fill();
    c.strokeStyle = 'rgba(94,242,214,0.75)'; c.lineWidth = 3; c.beginPath(); c.arc(256, 256, R, 0, 7); c.stroke();
    c.fillStyle = '#5ef2d6'; c.fillText('НОС', 256, 36);
    So.tex.needsUpdate = true;
  };
})(window.G);
