'use strict';
/* Скальник: мимикрия под камни, охота на кольчужника, любопытство */
T.describe('Скальник', () => {
  const E = () => G.Eco, S = () => G.Ship, D = () => G.Game.debug;
  const eco = (n, dt = 0.05) => { for (let i = 0; i < n; i++) { G.Game.t += dt; E().update(dt, G.Game.t); } };
  const quiet = () => {
    E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });
    E().rays.forEach(r => { r.fcd = 999; });
  };
  const shipAway = () => { S().pos.set(-250, -20, -250); S().speed = S().vy = 0; S().applyTransform(); };
  const sk = () => E().skalnik, cr = () => E().crab;
  const aimBeamAt = (p, dist) => {
    const o = T.V(0, 0.8, -6.8), d = T.V(0, -10.8, -33.2).normalize().multiplyScalar(dist || 22);
    S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0;
    S().pos.copy(p).sub(o).sub(d); S().applyTransform();
  };
  /* краб вышел из норы к ежу, скальник может напасть */
  const crabOut = (spines) => {
    const c = cr(), u = E().urchins.find(x => x.alive);
    c.spines = spines; c.state = 'hunt'; c.timer = 60; c.target = u;
    c.p.copy(c.den).addScaledVector(c.out, 5); c.p.y = G.World.height(c.p.x, c.p.z);
    u.p.copy(c.p).addScaledVector(c.out, 6); u.p.y = G.World.height(u.p.x, u.p.z) + 0.15;
    sk().cd = 0;
    return c;
  };

  T.test('скальник сидит у норы кольчужника и неотличим от камня', () => {
    T.ok(sk(), 'скальника нет');
    T.lt(sk().home.distanceTo(cr().den), 9);
    T.near(sk().home.y, G.World.height(sk().home.x, sk().home.z), 0.01);
    T.eq(sk().camo, 1);
    T.ok(E().scanTargets().filter(x => x.sp === 'skalnik').every(x => x.hidden && x.noSonar), 'замаскированного видно в прицеле или на сонаре');
    T.eq(G.nm('skalnik'), 'живой камень');
  });

  T.test('в луче прожектора меняет цвет и становится виден', () => {
    const ev = T.captureEvents();
    quiet(); S().light = true; aimBeamAt(sk().p.clone().setY(sk().p.y + 0.5));
    const c0 = new THREE.Color(0x4f4a5c); // цвет камня
    eco(10);
    T.ok(sk().lit, 'скальник не в луче');
    T.lt(sk().camo, 0.5, 'маскировка не сброшена');
    T.ok(E().scanTargets().some(x => x.sp === 'skalnik' && !x.hidden), 'не виден в прицеле');
    T.gt(sk().body.material.color.r - c0.r, 0.2, 'цвет не изменился');
    T.ok(ev.some(e => e.sp === 'skalnik' && e.note === 'mimic'), 'нет наблюдения «мимикрия»');
    shipAway(); eco(300);
    T.gt(sk().camo, 0.9, 'не замаскировался снова');
  });

  T.test('выгоняет кольчужника с бедным панцирем обратно в нору', () => {
    const ev = T.captureEvents();
    quiet(); shipAway();
    const c = crabOut(3);
    let met = false;
    for (let i = 0; i < 400 && !met; i++) { eco(1); met = ev.some(e => e.sp === 'skalnik' && e.note === 'hunt'); if (c.state !== 'hunt' && !met) { c.state = 'hunt'; c.timer = 60; } }
    T.ok(met, 'скальник не напал');
    T.eq(c.state, 'home', 'краб не удирает');
    T.eq(c.target, null);
    for (let i = 0; i < 200 && c.state !== 'den'; i++) eco(1);
    T.eq(c.state, 'den', 'краб не вернулся в нору');
    T.eq(c.spines, 3, 'краб пострадал');
    for (let i = 0; i < 400 && sk().state !== 'rock'; i++) eco(1);
    T.eq(sk().state, 'rock', 'скальник не вернулся на место');
  });

  T.test('кольчужника в полной броне не трогает', () => {
    const ev = T.captureEvents();
    quiet(); shipAway();
    const c = crabOut(9);
    let met = false;
    for (let i = 0; i < 400 && !met; i++) { eco(1); met = ev.some(e => e.sp === 'skalnik' && e.note === 'armor'); if (c.state !== 'hunt' && !met) { c.state = 'hunt'; c.timer = 60; } }
    T.ok(met, 'нет наблюдения «отступает от брони»');
    T.ok(!ev.some(e => e.sp === 'skalnik' && e.note === 'hunt'), 'напал на краба в броне');
    T.ok(c.state === 'hunt' || c.state === 'crack', 'краб бросил охоту');
  });

  T.test('к тихому тёмному кораблю подплывает к стеклу, свет его спугивает', () => {
    const ev = T.captureEvents();
    quiet();
    S().light = false; S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0;
    S().pos.set(sk().home.x, sk().home.y + 5, sk().home.z + 20); S().applyTransform();
    sk().curCd = 0;
    for (let i = 0; i < 600 && !ev.some(e => e.sp === 'skalnik' && e.note === 'curious'); i++) eco(1);
    T.ok(ev.some(e => e.sp === 'skalnik' && e.note === 'curious'), 'не подплыл к кораблю');
    T.lt(sk().p.distanceTo(S().front), 4.5, 'далеко от стекла');
    T.ok(E().scanTargets().some(x => x.sp === 'skalnik' && !x.hidden), 'у стекла его не видно');
    S().light = true; eco(2);
    T.eq(sk().state, 'back', 'свет не спугнул');
  });

  T.test('к кораблю со светом или на ходу не подплывает (контроль)', () => {
    quiet();
    S().light = true; S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0;
    S().pos.set(sk().home.x + 30, sk().home.y + 5, sk().home.z + 20); S().applyTransform(); // луч мимо
    sk().curCd = 0; eco(200);
    T.eq(sk().state, 'rock');
    S().light = false; S().speed = 3; eco(100);
    T.eq(sk().state, 'rock', 'подплыл к кораблю на ходу');
  });

  T.test('замаскированного скальника нельзя взять в прицел (контроль)', () => {
    quiet(); S().light = false; sk().curCd = 999; // без любопытства: скальник остаётся камнем
    G.Game.toggleHelm(); D().frame(1);
    const tgt = sk().p.clone().setY(sk().p.y + 0.5);
    G.Ctl.actionDown = true;
    for (let i = 0; i < 60; i++) { aimBeamAt(tgt, 24); D().lookAt(sk().p); D().frame(1); }
    G.Ctl.actionDown = false; D().frame(1);
    T.gt(sk().camo, 0.5);
    T.ok(!G.SPECIES.skalnik.scanned, 'отсканирован замаскированным');
    T.ok(G.Game.scan.key !== 'skalnik');
  });

  T.test('скальника сканируют после того, как он выдал себя', () => {
    quiet(); S().light = true;
    G.Game.toggleHelm(); D().frame(1);
    const tgt = sk().p.clone().setY(sk().p.y + 0.5);
    aimBeamAt(tgt, 24);
    G.Ctl.actionDown = true;
    for (let i = 0; i < 100 && !G.SPECIES.skalnik.scanned; i++) { aimBeamAt(tgt, 24); D().lookAt(sk().p); D().frame(1); }
    G.Ctl.actionDown = false; D().frame(1);
    T.ok(G.SPECIES.skalnik.scanned, 'скальник не отсканирован');
  });
});
