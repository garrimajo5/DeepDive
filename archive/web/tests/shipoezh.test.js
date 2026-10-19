'use strict';
/* Ленточник, шипоёж (объедает его) и кольчужник (охотится на ежей, охраняет нору) */
T.describe('Шипоёж и кольчужник', () => {
  const E = () => G.Eco, S = () => G.Ship, D = () => G.Game.debug;
  let t = 2000;
  const eco = (n, dt = 0.1) => { for (let i = 0; i < n; i++) { t += dt; E().update(dt, t); } };
  const quiet = () => {
    E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });
    E().rays.forEach(r => { r.fcd = 999; });
    E().shoals.forEach(sh => { sh.follow = null; sh.followT = 0; });
  };
  const shipAway = () => { S().pos.set(-250, -20, -250); S().speed = S().vy = 0; S().applyTransform(); };
  /* все ежи, кроме одного, уходят из рощи (на время теста) */
  const oneUrchin = (gr) => {
    const us = E().urchins.filter(u => u.gr === gr);
    us.slice(1).forEach(u => { u.alive = false; u.t = 1e9; if (u.goal) { u.goal.eater = null; u.goal = null; } });
    E().urchins.filter(u => u.gr !== gr).forEach(u => { u.alive = false; u.t = 1e9; });
    return us[0];
  };
  /* хищник гонится за светляком из стаи рощи */
  const chase = (gr) => {
    const pr = E().preds[0], f = gr.sh.members.find(x => x.alive);
    f.p.set(gr.c.x, gr.c.y + 2, gr.c.z); gr.sh.alarm = 3;
    pr.p.set(gr.c.x + 3, gr.c.y + 3, gr.c.z); pr.hunger = 1; pr.cd = 999; pr.state = 'hunt'; pr.target = f; pr.timer = 12;
    return { pr, f };
  };

  T.test('рощи ленточника у стай, ежи пасутся в них, у второй рощи нора кольчужника', () => {
    T.eq(E().groves.length, 2);
    E().groves.forEach(gr => {
      T.lt(Math.hypot(gr.sh.home.x - gr.c.x, gr.sh.home.z - gr.c.z), 1, 'роща не у стаи');
      T.eq(gr.stalks.length, 34); T.near(gr.cover, 1, 0.01);
    });
    T.eq(E().urchins.length, 14);
    E().urchins.forEach(u => { T.near(u.p.y, G.World.height(u.p.x, u.p.z) + 0.15, 0.01, 'ёж не на дне'); T.lt(Math.hypot(u.p.x - u.gr.c.x, u.p.z - u.gr.c.z), 10); });
    const cr = E().crab;
    T.ok(cr, 'нет кольчужника');
    T.lt(Math.hypot(cr.den.x - E().groves[1].c.x, cr.den.z - E().groves[1].c.z), 12, 'нора далеко от рощи');
    T.eq(cr.state, 'den'); T.eq(cr.spines, 3);
    const sp = E().scanTargets().map(x => x.sp);
    T.eq(sp.filter(x => x === 'ezh').length, 14); T.eq(sp.filter(x => x === 'krab').length, 1);
    T.eq(G.nm('ezh', 'gen'), 'морского ежа');
  });

  T.test('шипоёж объедает ленточник до стеблей, без ежей ленточник отрастает', () => {
    const ev = T.captureEvents();
    quiet(); shipAway(); E().crab.hunger = -999;
    const gr = E().groves[0], u = oneUrchin(gr);
    eco(600); // минута
    const s = u.goal || gr.stalks.find(x => x.f < 0.9);
    T.ok(s, 'ёж ничего не ест');
    T.ok(ev.some(e => e.sp === 'ezh' && e.note === 'graze'), 'нет наблюдения «объедает»');
    T.lt(Math.min(...gr.stalks.map(x => x.f)), 0.5, 'стебель не объеден');
    T.lt(gr.cover, 1);
    /* голый стебель узкий и короткий */
    const m = new THREE.Matrix4(), sc = new THREE.Vector3();
    const k = gr.stalks.reduce((a, x, i) => (x.f < gr.stalks[a].f ? i : a), 0);
    E().kelpIM.getMatrixAt(gr.i * 34 + k, m); m.decompose(new THREE.Vector3(), new THREE.Quaternion(), sc);
    T.lt(sc.x, 0.6, 'стебель не похудел');
    const low = gr.stalks[k].f;
    u.alive = false; u.t = 1e9; if (u.goal) { u.goal.eater = null; u.goal = null; }
    eco(300);
    T.gt(gr.stalks[k].f, low + 0.1, 'ленточник не отрастает');
  });

  T.test('в густом ленточнике хищник теряет напуганную стаю', () => {
    const ev = T.captureEvents();
    quiet(); shipAway();
    const gr = E().groves[0], { pr, f } = chase(gr);
    T.ok(E().kelpShelter(f), 'светляк не в укрытии');
    eco(1, 0.05);
    T.ok(pr.state !== 'hunt', 'хищник продолжает охоту в ленточнике');
    T.ok(ev.some(e => e.sp === 'fish' && e.note === 'kelp'), 'нет наблюдения про укрытие');
    T.ok(f.alive);
  });

  T.test('в объеденном ленточнике стае негде спрятаться', () => {
    const ev = T.captureEvents();
    quiet(); shipAway();
    const gr = E().groves[0];
    gr.stalks.forEach(s => { s.f = 0.15; s.eater = { stub: 1 }; }); eco(1, 0.05);
    T.lt(gr.cover, 0.45);
    const { pr, f } = chase(gr);
    T.ok(!E().kelpShelter(f), 'светляк прячется в голых стеблях');
    for (let i = 0; i < 100 && f.alive; i++) { f.p.copy(pr.p); eco(1, 0.05); }
    T.ok(!f.alive, 'хищник не поймал светляка');
    T.ok(ev.some(e => e.sp === 'ezh' && e.note === 'bare'), 'нет наблюдения «негде спрятаться»');
    T.ok(!ev.some(e => e.sp === 'fish' && e.note === 'kelp'));
  });

  T.test('голодный кольчужник выходит из норы, раскалывает ежа и носит его иглы', () => {
    const ev = T.captureEvents();
    quiet(); shipAway();
    const cr = E().crab, gr = cr.gr, u = oneUrchin(gr);
    u.p.copy(cr.den).add(T.V(4, 0, 0)); u.p.y = G.World.height(u.p.x, u.p.z) + 0.15;
    cr.hunger = 0.5; eco(10);
    T.eq(cr.state, 'den', 'сытый краб вышел на охоту');
    cr.hunger = 1.2;
    let left = 0;
    for (let i = 0; i < 300 && u.alive; i++) { eco(1); left = Math.max(left, cr.p.distanceTo(cr.den)); }
    T.ok(!u.alive, 'ёж уцелел');
    T.gt(left, 1, 'краб не выходил из норы');
    T.eq(cr.spines, 5, 'иглы не добавились на панцирь');
    T.ok(ev.some(e => e.sp === 'krab' && e.note === 'hunt'));
    T.ok(ev.some(e => e.sp === 'krab' && e.note === 'armor'));
    for (let i = 0; i < 300 && cr.state !== 'den'; i++) eco(1);
    T.eq(cr.state, 'den', 'краб не вернулся в нору');
    T.lt(cr.p.distanceTo(cr.den), 0.5);
  });

  T.test('кольчужник не трогает ежей далеко от норы (контроль)', () => {
    quiet(); shipAway();
    const cr = E().crab, u = oneUrchin(E().groves[0]);
    T.gt(u.p.distanceTo(cr.den), 16);
    cr.hunger = 1.2; eco(300);
    T.ok(u.alive); T.eq(cr.state, 'den');
  });

  T.test('кольчужник охраняет нору и зажимает корпус клешнёй', () => {
    const ev = T.captureEvents();
    quiet();
    const cr = E().crab;
    S().pos.copy(cr.den).add(T.V(0, 3, 0)); S().speed = S().vy = 0; S().applyTransform();
    S().pos.add(T.V(cr.den.x - S().center.x, cr.den.y + 4 - S().center.y, cr.den.z - S().center.z)); S().applyTransform();
    T.lt(S().center.distanceTo(cr.den), 7);
    const hull = S().hull;
    eco(5);
    T.eq(cr.state, 'guard');
    T.gt(cr.raise, 0.5, 'клешни не подняты');
    T.ok(ev.some(e => e.sp === 'krab' && e.note === 'guard'));
    T.lt(S().hull, hull, 'корпус не пострадал');
    shipAway(); eco(100);
    T.ok(cr.state === 'den' || cr.state === 'home', 'краб не успокоился');
  });

  T.test('шипоежа и кольчужника сканируют с мостика', () => {
    quiet();
    const cr = E().crab, u = E().urchins.find(x => x.gr === cr.gr);
    S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0;
    const d = T.V(0, -10.8, -33.2).normalize().multiplyScalar(20);
    S().pos.copy(cr.den).sub(T.V(0, 0.8, -6.8)).sub(d); S().applyTransform();
    G.Game.toggleHelm(); D().frame(1);
    [['krab', () => cr.p], ['ezh', () => u.p]].forEach(([sp, pos]) => {
      D().lookAt(pos()); D().frame(1);
      G.Ctl.actionDown = true;
      for (let i = 0; i < 60 && !G.SPECIES[sp].scanned; i++) { D().lookAt(pos()); D().frame(1); }
      G.Ctl.actionDown = false; D().frame(1);
      T.ok(G.SPECIES[sp].scanned, sp + ' не отсканирован');
    });
    T.eq(G.nm('ezh', 'gen'), 'шипоежа');
    G.Save.save();
    G.SPECIES.ezh.scanned = G.SPECIES.krab.scanned = false;
    G.Save.load();
    T.ok(G.SPECIES.ezh.scanned && G.SPECIES.krab.scanned, 'не сохранились');
  });
});
