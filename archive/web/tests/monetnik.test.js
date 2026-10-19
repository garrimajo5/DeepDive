'use strict';
/* Монетники на мху и песчаные глазуны в засаде */
T.describe('Монетник и песчаный глазун', () => {
  const E = () => G.Eco, S = () => G.Ship, D = () => G.Game.debug;
  const eco = (n) => { for (let i = 0; i < n; i++) { G.Game.t += 0.05; E().update(0.05, G.Game.t); } };
  const quiet = () => {
    E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });
    E().rays.forEach(r => { r.fcd = 999; });
    E().eels.forEach(el => { el.cd = 999; });
  };
  const shipAt = (p, dy) => { S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0; S().pos.set(p.x, p.y + (dy || 12), p.z + 15); S().applyTransform(); };
  const shipAway = () => { S().pos.set(-250, -20, -250); S().speed = S().vy = 0; S().applyTransform(); };
  const alive = sc => sc.members.filter(c => c.alive).length;

  T.test('три стайки монетников на пятнах мха, у каждой — глазун в песке', () => {
    T.eq(E().schools.length, 3); T.eq(E().glazuns.length, 3);
    E().schools.forEach((sc, i) => {
      T.eq(sc.members.length, 9);
      const gz = E().glazuns[i];
      T.lt(Math.hypot(gz.p.x - sc.c.x, gz.p.z - sc.c.z), 4, 'глазун далеко от мха');
      T.near(gz.p.y, G.World.height(gz.p.x, gz.p.z), 0.01, 'глазун не в песке');
    });
    const sp = E().scanTargets().map(x => x.sp);
    T.eq(sp.filter(x => x === 'monet').length, 3); T.eq(sp.filter(x => x === 'glazun').length, 3);
    T.eq(G.nm('glazun', 'acc'), 'глаза в песке');
  });

  T.test('монетники держатся над мхом и пасутся', () => {
    const ev = T.captureEvents();
    quiet(); shipAway();
    E().glazuns.forEach(g => { g.cd = 999; });
    const sc = E().schools[0]; sc.grazeCd = 0; sc.pt.food = 1;
    eco(400);
    sc.members.forEach(c => T.lt(Math.hypot(c.p.x - sc.c.x, c.p.z - sc.c.z), 5, 'монетник уплыл от мха'));
    T.ok(ev.some(e => e.sp === 'monet' && e.note === 'graze'), 'нет наблюдения «пасутся»');
    T.lt(sc.pt.food, 1, 'мох не объеден');
  });

  T.test('глазун хватает монетника, проплывшего над ним', () => {
    const ev = T.captureEvents();
    quiet(); shipAway();
    const gz = E().glazuns[0], cn = gz.sc.members[0]; gz.cd = 0;
    for (let i = 0; i < 5 && cn.alive; i++) { cn.p.set(gz.p.x, gz.p.y + 0.8, gz.p.z); cn.goal.copy(cn.p); eco(1); }
    T.ok(!cn.alive, 'монетник уцелел над глазуном');
    T.gt(gz.lunge, 0.5, 'глазун не сделал бросок');
    T.ok(ev.some(e => e.sp === 'glazun' && e.note === 'ambush'), 'нет наблюдения «засада»');
    const left = alive(gz.sc);
    eco(20); T.eq(alive(gz.sc), left, 'глазун ест без передышки'); // после броска пауза
  });

  T.test('монетник в стороне от глазуна цел (контроль)', () => {
    quiet(); shipAway();
    const gz = E().glazuns[0], cn = gz.sc.members[0]; gz.cd = 0;
    gz.sc.members.forEach(c => { if (c !== cn) { c.alive = false; c.t = 999; } }); // остальные не заплывают к глазуну
    for (let i = 0; i < 40; i++) { cn.p.set(gz.p.x + 3, gz.p.y + 0.8, gz.p.z); cn.goal.copy(cn.p); eco(1); }
    T.ok(cn.alive);
    T.eq(gz.lunge, 0);
  });

  T.test('глазуна нет на сонаре', () => {
    quiet();
    const gz = E().glazuns[0]; shipAt(gz.p); S().energy = 100;
    G.Sonar.ping();
    T.ok(G.Sonar.blips.some(b => b.sp === 'monet'), 'монетники не видны на сонаре');
    T.ok(!G.Sonar.blips.some(b => b.sp === 'glazun'), 'глазун виден на сонаре');
  });

  T.test('от импульса сонара стайка рассыпается прочь от глазуна', () => {
    const ev = T.captureEvents();
    quiet();
    const gz = E().glazuns[0], sc = gz.sc; shipAt(gz.p); S().energy = 100;
    E().glazuns.forEach(g => { g.cd = 999; });
    eco(1);
    const away = (c) => Math.hypot(c.p.x - gz.p.x, c.p.z - gz.p.z);
    const before = sc.members.reduce((a, c) => a + away(c), 0) / 9;
    G.Sonar.ping(); eco(30);
    const after = sc.members.reduce((a, c) => a + away(c), 0) / 9;
    T.gt(after, before + 3, 'стайка не отплыла от глазуна');
    T.ok(ev.some(e => e.sp === 'monet' && e.note === 'scatter'), 'нет наблюдения «рассыпаются»');
    T.ok(ev.some(e => e.sp === 'glazun' && e.note === 'sonar'), 'нет наблюдения «не виден на сонаре»');
    eco(300);
    sc.members.forEach(c => T.lt(Math.hypot(c.p.x - sc.c.x, c.p.z - sc.c.z), 5, 'стайка не вернулась на мох'));
  });

  T.test('без глазуна рядом стайка бежит от корабля (контроль направления)', () => {
    quiet();
    const gz = E().glazuns[0], sc = gz.sc;
    const old = gz.p.clone(); gz.p.set(gz.p.x + 40, gz.p.y, gz.p.z); T._restore.push(() => gz.p.copy(old));
    shipAt(sc.c); S().energy = 100; eco(1);
    G.Sonar.ping(); eco(20);
    T.ok(sc.from.distanceTo(S().center) < 0.5, 'угроза не корабль');
    const cz = sc.members.reduce((a, c) => a + c.p.z, 0) / 9;
    T.lt(cz, sc.c.z - 2, 'стайка не отплыла от корабля'); // корабль стоит с +Z
  });

  T.test('в луче прожектора у глазуна блестят глаза', () => {
    const ev = T.captureEvents();
    quiet();
    const gz = E().glazuns[0];
    const o = T.V(0, 0.8, -6.8), d = T.V(0, -10.8, -33.2).normalize().multiplyScalar(20);
    S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0; S().pos.copy(gz.eyeC).sub(o).sub(d); S().applyTransform();
    S().light = false; eco(2);
    T.ok(!gz.lit);
    S().light = true; eco(2);
    T.ok(gz.lit, 'глаза не в луче');
    T.ok(ev.some(e => e.sp === 'glazun' && e.note === 'eyes'), 'нет наблюдения «глаза»');
    const c = E().glzEyeIM.instanceColor.array; T.gt(c[gz.i * 6], 1, 'глаза не стали ярче');
  });

  T.test('глазуна сканируют по глазам с мостика', () => {
    quiet(); S().light = false;
    const gz = E().glazuns[0];
    G.Game.toggleHelm(); D().frame(1);
    const o = T.V(0, 0.8, -6.8), d = T.V(0, -10.8, -33.2).normalize().multiplyScalar(24);
    S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0; S().pos.copy(gz.eyeC).sub(o).sub(d); S().applyTransform();
    G.Ctl.actionDown = true;
    for (let i = 0; i < 80 && !G.SPECIES.glazun.scanned; i++) { D().lookAt(gz.eyeC); D().frame(1); }
    G.Ctl.actionDown = false; D().frame(1);
    T.ok(G.SPECIES.glazun.scanned, 'глазун не отсканирован');
    T.eq(G.nm('glazun', 'acc'), 'песчаного глазуна');
  });
});
