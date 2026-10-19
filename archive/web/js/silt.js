'use strict';
/* Событие «сонарная тьма». Облако ила поднимается, когда корабль чиркает по дну, а у Края отмели
   время от времени сходит оползень. Облако дрейфует по течению и оседает. Внутри него импульс сонара
   глохнет в иле, вода мутнеет, луч прожектора рассеивается. Зато и серпохвост в иле не видит свет корабля. */
(function (G) {
  const V3 = THREE.Vector3;
  const N = 300, MAXC = 3, SCRAPE_R = 16, SCRAPE_LIFE = 45, SLIDE_R = 30, SLIDE_LIFE = 80, SLIDE_PERIOD = 300, SLIDE_FIRST = 150;
  const Si = G.Silt = { clouds: [], inside: null, k: 0, slideT: SLIDE_FIRST, msgCd: 0 };

  Si.build = function (scene) {
    const g = new THREE.BufferGeometry(), a = new Float32Array(MAXC * N * 3).fill(-999);
    g.setAttribute('position', new THREE.BufferAttribute(a, 3));
    Si.pts = new THREE.Points(g, new THREE.PointsMaterial({ color: 0x6b5a44, size: 1.6, transparent: true, opacity: 0.55, depthWrite: false }));
    Si.pts.frustumCulled = false; scene.add(Si.pts);
    Si.off = Array.from({ length: N }, (_, i) => { const u = Math.sin(i * 12.9898) * 43758.5453; const r = u - Math.floor(u); const a2 = i * 2.39996, y = ((i * 0.618) % 1) * 2 - 1; const rr = Math.sqrt(Math.max(0, 1 - y * y)); return new V3(Math.cos(a2) * rr, y * 0.45, Math.sin(a2) * rr).multiplyScalar(Math.cbrt(r)); });
  };
  Si.spawn = function (pos, r, life, why) {
    if (Si.clouds.length >= MAXC) Si.clouds.shift();
    const cl = { c: pos.clone(), r, life, max: life, why, slot: 0 };
    Si.clouds.push(cl); Si.clouds.forEach((c, i) => { c.slot = i; });
    if (why === 'slide') G.Game.feedMsg && G.Game.feedMsg('У Края отмели сошёл оползень: облако ила идёт по течению');
    return cl;
  };
  Si.onHit = function (n, kind) {
    if (kind !== 'scrape') return;
    const S = G.Ship, near = Si.clouds.find(c => c.c.distanceTo(S.center) < c.r * 0.6);
    if (near) { near.life = Math.max(near.life, SCRAPE_LIFE); return; } // ещё муть в той же туче
    Si.spawn(S.center.clone().setY(Math.max(S.pos.y - 2, G.World.height(S.pos.x, S.pos.z) + 3)), SCRAPE_R, SCRAPE_LIFE, 'scrape');
  };
  Si.reset = function () { Si.clouds.length = 0; Si.inside = null; Si.k = 0; Si.slideT = SLIDE_FIRST; Si.msgCd = 0; if (Si.pts) Si.pts.geometry.attributes.position.array.fill(-999); };
  /* насколько облако плотное: оседает последние 8 с */
  const dens = cl => Math.min(1, cl.life / 8) * Math.min(1, (cl.max - cl.life) * 2 + 0.3);
  Si.at = function (p) { for (const cl of Si.clouds) if (p.distanceTo(cl.c) < cl.r && dens(cl) > 0.4) return cl; return null; };

  Si.update = function (dt, t) {
    const S = G.Ship, cur = G.Eco.current;
    Si.slideT -= dt;
    if (Si.slideT <= 0) {
      Si.slideT = SLIDE_PERIOD;
      const d = G.World.pois.find(p => p.key === 'drop');
      if (d) Si.spawn(new V3(d.pos.x, Math.max(G.World.height(d.pos.x, d.pos.z) + 10, -55), d.pos.z), SLIDE_R, SLIDE_LIFE, 'slide');
    }
    for (let i = Si.clouds.length - 1; i >= 0; i--) {
      const cl = Si.clouds[i];
      cl.life -= dt; if (cl.life <= 0) { Si.clouds.splice(i, 1); continue; }
      if (cur) cl.c.addScaledVector(cur, dt * 1.3); // ил несёт течением
      cl.c.y -= dt * 0.05;
    }
    Si.clouds.forEach((c, i) => { c.slot = i; });
    const was = Si.inside;
    Si.inside = Si.at(S.center);
    Si.k += ((Si.inside ? 1 : 0) - Si.k) * Math.min(1, dt * 1.5);
    if (Si.inside && !was) {
      G.Game.toast('Сонарная тьма', 'Корабль в облаке ила: сонар не пробивает муть, свет рассеивается. Зато хищники вас тоже не видят.', 4500);
      G.Game.feedMsg && G.Game.feedMsg('Сонарная тьма: корабль в облаке ила');
    }
    /* частицы ила */
    const a = Si.pts.geometry.attributes.position.array;
    for (let s = 0; s < MAXC; s++) {
      const cl = Si.clouds[s];
      for (let j = 0; j < N; j++) {
        const q = (s * N + j) * 3;
        if (!cl) { a[q + 1] = -999; continue; }
        const o = Si.off[j], sp = cl.r * (0.5 + 0.5 * Math.min(1, (cl.max - cl.life) * 0.5));
        a[q] = cl.c.x + o.x * sp + Math.sin(t * 0.3 + j) * 0.6; a[q + 1] = cl.c.y + o.y * sp; a[q + 2] = cl.c.z + o.z * sp + Math.cos(t * 0.25 + j) * 0.6;
      }
    }
    Si.pts.geometry.attributes.position.needsUpdate = true;
    Si.pts.material.opacity = 0.55 * Math.min(1, Si.clouds.reduce((m, c) => Math.max(m, dens(c)), 0) + 0.1);
    Si.msgCd -= dt;
    if (Si.msgCd <= 0) { Si.msgCd = 0.3; Si.alert(); }
  };
  Si.alert = function () {
    const el = document.getElementById('alert'); if (!el) return;
    if ((G.Breach && G.Breach.active) || (G.Power && (G.Power.hot || G.Power.scram > 0))) return; // пробоина и реактор важнее
    if (Si.inside) { el.hidden = false; el.textContent = 'СОНАРНАЯ ТЬМА · ОБЛАКО ИЛА'; Si.shown = true; }
    else if (Si.shown) { el.hidden = true; Si.shown = false; }
  };
})(window.G);
