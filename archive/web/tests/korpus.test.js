'use strict';
/* Корпус «Ковчега»: существа не проходят внутрь корабля, а обходят его, садятся снаружи или бьют в борт */
T.describe('Корпус', () => {
  const E = () => G.Eco, S = () => G.Ship;
  const eco = (n, fn) => { for (let i = 0; i < n; i++) { G.Game.t += 0.05; if (fn) fn(); E().update(0.05, G.Game.t); } };
  const quiet = () => {
    E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.leechCd = 999; p.p.set(250, -20, 250); p.segs.forEach(sg => sg.set(250, -20, 250)); });
    E().eels.forEach(el => { el.cd = 999; });
    E().rays.forEach(r => { r.fcd = 999; });
  };
  /* поставить корабль так, чтобы точка w мира оказалась в точке (lx, ly, lz) корабельных координат (курс 0) */
  const shipAt = (w, lx, ly, lz) => { const s = S(); s.yaw = s.pitch = s.roll = 0; s.speed = s.vy = 0; s.pos.set(w.x - lx, w.y - ly, w.z - lz); s.applyTransform(); };
  const inside = (p, r = 0) => S().hullDist(p) < r - 1e-3;
  const local = p => S().group.worldToLocal(p.clone());
  /* открытая вода вдали от медуз-вуалей (от них серпохвост отворачивает): корабль выше дна на всём пути */
  const openWater = () => {
    const c = [[-200, 150], [200, -200], [-220, -60], [150, 200], [-60, -230]].map(([x, z]) => T.V(x, 0, z))
      .sort((a, b) => Math.min(...E().veils.map(v => Math.hypot(b.x - v.p.x, b.z - v.p.z))) - Math.min(...E().veils.map(v => Math.hypot(a.x - v.p.x, a.z - v.p.z))))[0];
    let h = -1e9; for (let dz = -35; dz <= 50; dz += 5) for (let dx = -10; dx <= 10; dx += 5) h = Math.max(h, G.World.height(c.x + dx, c.z + dz));
    c.y = Math.min(-8, h + 4); return c;
  };

  T.test('объём корпуса: точки в отсеках внутри, за бортом снаружи, с поворотом корабля', () => {
    const s = S(); s.yaw = 0.9; s.pos.set(10, -30, 40); s.applyTransform();
    const w = (x, y, z) => s.group.localToWorld(T.V(x, y, z));
    [[0, 1.6, -2], [0, 1.3, 5], [-3, 1.7, 11], [2, 1.6, 17], [0, 1.5, 22]].forEach(([x, y, z]) => T.lt(s.hullDist(w(x, y, z)), 0, `точка ${x},${y},${z} не внутри`));
    [[0, 1.6, -8], [3, 1.3, 5], [0, 5, 0], [0, 1.5, 26], [7, 1.6, 11]].forEach(([x, y, z]) => T.gt(s.hullDist(w(x, y, z)), 0, `точка ${x},${y},${z} не снаружи`));
    /* выталкивание: из коридора — вбок, из середины мостика — к ближайшей грани, скорость внутрь гасится */
    const p = w(0.3, 1.3, 5), v = T.V(0, 0, 0).copy(w(-3, 1.3, 5)).sub(w(0, 1.3, 5));
    T.ok(s.pushOut(p, 0.4, v), 'точка в коридоре не вытолкнута');
    T.gt(s.hullDist(p), 0.39); T.near(local(p).x, 1.6, 0.05, 'вытолкнута не вбок');
    T.lt(v.length(), 1e-6, 'скорость внутрь корпуса не погашена');
    T.ok(!s.pushOut(w(0, 1.6, -9), 0.4), 'точку снаружи тронули');
    /* на стыке коридора и лаборатории точка выходит наружу, а не в соседний отсек */
    const j = w(0.02, 0.32, 8.0); T.ok(s.pushOut(j, 0.2)); T.gt(s.hullDist(j), 0.19, 'точка на стыке отсеков осталась внутри');
  });

  T.test('светляки: стая у корабля обтекает корпус', () => {
    quiet(); const sh = E().shoals[0];
    const pin = () => shipAt(sh.c, 0, 1.4, -2);
    pin(); T.gt(sh.members.filter(f => inside(f.p)).length, 0, 'стая не задела корабль — тест ничего не проверяет');
    let worst = 1e9;
    for (let i = 0; i < 300; i++) { eco(1, pin); worst = Math.min(worst, ...sh.members.filter(f => f.alive).map(f => S().hullDist(f.p))); }
    T.gt(worst, 0.25, 'светляк внутри корабля');
  });

  T.test('серпохвост в броске бьёт в нос, а не проплывает в рубку', () => {
    quiet(); S().light = true;
    const pr = E().preds[1], base = openWater(); shipAt(base, 0, 0, 0);
    pr.p.copy(S().group.localToWorld(T.V(0, 1.6, -40))); pr.segs.forEach((sg, k) => sg.copy(pr.p).z -= k * 0.6); pr.v.set(0, 0, 9);
    pr.state = 'charge'; pr.timer = 10; pr.cd = 0; pr.hunger = 1; pr.leechCd = 999;
    const hull0 = S().hull; let worst = 1e9, segWorst = 1e9, bitten = false;
    for (let i = 0; i < 160 && !bitten; i++) {
      eco(1, () => shipAt(base, 0, 0, 0));
      worst = Math.min(worst, S().hullDist(pr.p)); segWorst = Math.min(segWorst, ...pr.segs.slice(1).map(sg => S().hullDist(sg)));
      bitten = pr.state === 'retreat';
    }
    T.ok(bitten, 'серпохвост так и не укусил');
    T.lt(S().hull, hull0, 'корпус не пострадал');
    T.gt(worst, 0.6, 'голова серпохвоста внутри корабля');
    T.gt(segWorst, 0.4, 'хвост серпохвоста внутри корабля');
  });

  T.test('серпохвост на патруле обходит корабль, а не проходит насквозь', () => {
    quiet(); S().light = false;
    const pr = E().preds[1]; const base = openWater(), pin = () => shipAt(base, 0, 0, 0); pin();
    pr.p.copy(S().group.localToWorld(T.V(0.5, 1.6, -30))); pr.segs.forEach(sg => sg.copy(pr.p)); pr.v.set(0, 0, 0);
    pr.goal.copy(S().group.localToWorld(T.V(0, 1.6, 45)));
    pr.state = 'patrol'; pr.timer = 999; pr.cd = 999; pr.hunger = 0; pr.leechCd = 999;
    let worst = 1e9, far = -1e9;
    for (let i = 0; i < 1000; i++) { eco(1, () => { pin(); pr.hunger = 0; }); worst = Math.min(worst, S().hullDist(pr.p)); far = Math.max(far, local(pr.p).z); }
    T.gt(worst, 0.6, 'серпохвост прошёл сквозь корпус');
    T.gt(far, 38, 'серпохвост застрял у корабля');
  });

  T.test('стеклоуст плывёт к носу вокруг корпуса и присасывается снаружи', () => {
    quiet(); const el = E().eels[0], L = el.lair;
    const pin = () => shipAt(L, 0, -3, 18); pin(); // нора за кормой и ниже корабля
    el.state = 'toShip'; el.timer = 6; el.p.copy(L); el.segs.forEach(sg => sg.copy(L));
    let worst = 1e9;
    for (let i = 0; i < 120 && el.state === 'toShip'; i++) { eco(1, pin); worst = Math.min(worst, S().hullDist(el.p), ...el.segs.slice(1).map(sg => S().hullDist(sg) + 0.05)); }
    T.eq(E().latched, el, 'стеклоуст не присосался');
    T.gt(worst, 0.25, 'стеклоуст прошёл сквозь корабль');
    eco(1, pin); el.segs.forEach(sg => T.gt(S().hullDist(sg), 0, 'присосавшийся стеклоуст внутри корпуса'));
  });

  T.test('ледокрыл проплывает над кораблём, стоящим на его пути', () => {
    quiet(); const ry = E().rays[0];
    eco(1); const a = ry.ang + 0.3;
    const on = T.V(ry.c.x + Math.cos(a) * ry.R, ry.p.y, ry.c.z + Math.sin(a) * ry.R);
    const pin = () => shipAt(on, 0, 1.6, -2); pin();
    let worst = 1e9, overTop = 1e9, passed = false;
    for (let i = 0; i < 400; i++) {
      eco(1, pin);
      worst = Math.min(worst, S().hullDist(ry.p));
      const mid = T.V(ry.p.x, S().pos.y + 1.6, ry.p.z);
      if (S().hullDist(mid) < 0) { passed = true; overTop = Math.min(overTop, ry.p.y - (S().pos.y + 3.5)); }
    }
    T.ok(passed, 'ледокрыл не прошёл над кораблём — тест ничего не проверяет');
    T.gt(worst, 1.4, 'ледокрыл внутри корабля');
    T.gt(overTop, 2, 'ледокрыл задевает крыльями крышу');
  });

  T.test('монетник не заплывает в корабль, даже если цель внутри', () => {
    quiet(); const cn = E().coins.find(c => c.alive);
    const pin = () => shipAt(cn0, -10, 0.5, 0); const cn0 = cn.p.clone(); pin();
    const goal = S().group.localToWorld(T.V(0, 1.5, -2));
    let worst = 1e9, closest = 1e9;
    for (let i = 0; i < 300; i++) { eco(1, () => { pin(); cn.goal.copy(goal); cn.gt = 999; cn.s.scatter = 0; }); const d = S().hullDist(cn.p); worst = Math.min(worst, d); closest = Math.min(closest, d); }
    T.gt(worst, 0.2, 'монетник внутри корабля');
    T.lt(closest, 0.6, 'монетник не доплыл до борта — тест ничего не проверяет');
  });

  T.test('радужники и светящийся планктон расступаются вокруг корпуса', () => {
    quiet(); eco(1);
    const sw = E().swarms[0], cl = E().clouds[0];
    shipAt(sw.c, 0, 1.6, -2);
    T.gt(sw.m.filter(m => inside(T.V(0, 0, 0).copy(sw.c).add(m.o))).length, 0, 'стая не задела корабль');
    eco(40, () => shipAt(sw.c, 0, 1.6, -2));
    sw.m.forEach(m => T.gt(S().hullDist(m.p), 0.25, 'радужник внутри корабля'));
    shipAt(cl.c, 0, 1.6, 11);
    let n0 = 0; for (let k = 0; k < cl.o.length; k += 3) if (inside(T.V(cl.c.x + cl.o[k], cl.c.y + cl.o[k + 1], cl.c.z + cl.o[k + 2]))) n0++;
    T.gt(n0, 0, 'облако не задело корабль');
    eco(20, () => shipAt(cl.c, 0, 1.6, 11));
    const pa = E().plPts.geometry.attributes.position.array, base = cl.i * cl.o.length;
    for (let k = 0; k < cl.o.length; k += 3) T.gt(S().hullDist(T.V(pa[base + k], pa[base + k + 1], pa[base + k + 2])), 0.15, 'планктон внутри корабля');
  });

  T.test('прилипалы держатся на корпусе снаружи', () => {
    const s = S(); s.yaw = 0; s.pos.set(0, -30, 0); s.applyTransform();
    E().RM_SLOTS.forEach(([x, y, z]) => { const d = s.hullDist(s.group.localToWorld(T.V(x, y, z))); T.gt(d, 0.05, `место ${x},${y},${z} внутри корпуса`); T.lt(d, 0.4, `место ${x},${y},${z} не на корпусе`); });
  });

  T.test('скальник подплывает к стеклу вокруг корпуса', () => {
    quiet(); S().light = false;
    const sk = E().skalnik, pin = () => shipAt(sk.home, 0, -1.5, 28); pin(); // нора за кормой
    sk.state = 'curious'; sk.timer = 60; sk.reveal = 4;
    let worst = 1e9;
    for (let i = 0; i < 1200 && !sk.seen; i++) { eco(1, () => { pin(); sk.timer = 10.5; }); worst = Math.min(worst, S().hullDist(sk.p)); }
    T.ok(sk.seen, 'скальник не доплыл до стекла');
    T.gt(worst, 0.45, 'скальник прошёл сквозь корабль');
  });
});
