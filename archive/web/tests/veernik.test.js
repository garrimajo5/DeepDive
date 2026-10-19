'use strict';
/* Течение, веерник (стоит поперёк потока) и волнолист (раскрывается в луче) */
T.describe('Веерник, волнолист и течение', () => {
  const E = () => G.Eco, S = () => G.Ship, D = () => G.Game.debug;
  const eco = (n, fn) => { for (let i = 0; i < n; i++) { G.Game.t += 0.05; if (fn) fn(); E().update(0.05, G.Game.t); } };
  const quiet = () => {
    E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });
    E().rays.forEach(r => { r.fcd = 999; });
    E().shoals.forEach(sh => { sh.follow = null; sh.followT = 0; });
  };
  const shipAway = () => { S().pos.set(-250, -20, -250); S().speed = S().vy = 0; S().applyTransform(); };
  const ang = (a) => Math.atan2(Math.sin(a), Math.cos(a));
  const aimBeamAt = (p, dist) => {
    const o = T.V(0, 0.8, -6.8), d = T.V(0, -10.8, -33.2).normalize().multiplyScalar(dist || 18);
    S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0; S().pos.copy(p).sub(o).sub(d); S().applyTransform();
  };

  T.test('веерники у станций огнёвок, волнолист двумя куртинами', () => {
    T.eq(E().fans.length, E().stations.length + 1);
    E().fans.filter(f => f.st).forEach(f => T.lt(f.p.distanceTo(f.st.base), 9, 'веерник далеко от станции'));
    T.eq(E().ferns.length, 8);
    E().ferns.forEach(fe => T.near(fe.p.y, G.World.height(fe.p.x, fe.p.z), 0.01));
    const sp = E().scanTargets().map(x => x.sp);
    T.eq(sp.filter(x => x === 'fan').length, E().fans.length); T.eq(sp.filter(x => x === 'fern').length, 8);
    T.near(E().current.length(), 0.3, 1e-6);
  });

  T.test('течение сносит корабль', () => {
    quiet();
    S().pos.set(-110, -12, -30); S().pos.y = Math.max(S().pos.y, G.World.height(-110, -30) + 12); S().yaw = 0; S().speed = S().vy = 0; S().applyTransform();
    S().input.thrust = S().input.turn = S().input.vert = 0;
    const p0 = S().pos.clone();
    for (let i = 0; i < 200; i++) S().update(0.05, 0); // 10 с
    const d = S().pos.clone().sub(p0).setY(0);
    T.near(d.length(), 3, 0.3, 'снос за 10 с');
    T.gt(d.normalize().dot(E().current.clone().normalize()), 0.99, 'сносит не по течению');
  });

  T.test('веерники стоят поперёк течения и разворачиваются, когда оно меняется', () => {
    const ev = T.captureEvents();
    quiet();
    const f = E().fans[E().fans.length - 1];
    S().pos.copy(f.p).add(T.V(0, 8, 15)); S().speed = S().vy = 0; S().applyTransform();
    eco(10);
    E().fans.forEach(fn => T.lt(Math.abs(ang(fn.yaw - E().curAng)), 0.05, 'веерник не поперёк течения'));
    T.ok(ev.some(e => e.sp === 'fan' && e.note === 'across'), 'нет наблюдения «поперёк течения»');
    const a0 = E().curAng; E().curT = 0;
    eco(1);
    T.ok(ev.some(e => e.sp === 'fan' && e.note === 'turn'), 'нет наблюдения «разворачиваются»');
    for (let i = 0; i < 1200; i++) { eco(1, () => { S().pos.copy(f.p).add(T.V(0, 8, 15)); S().applyTransform(); }); }
    T.gt(Math.abs(ang(E().curAng - a0)), 1, 'течение не сменилось');
    E().fans.forEach(fn => T.lt(Math.abs(ang(fn.yaw - E().curAng)), 0.1, 'веерник не развернулся следом'));
  });

  T.test('огнёвки кормятся на веернике, пока станция пустует', () => {
    const ev = T.captureEvents();
    quiet();
    const st = E().stations[0], f = E().fanAt(st);
    S().pos.copy(f.p).add(T.V(0, 8, 15)); S().speed = S().vy = 0; S().applyTransform();
    eco(60);
    const mine = E().shrimp.filter(s => s.st === st);
    T.gt(mine.filter(s => s.p.distanceTo(f.top) < 3).length, 2, 'огнёвок нет на веернике');
    T.gt(mine.filter(s => s.p.distanceTo(st.top) < 3).length, 2, 'станция опустела совсем');
    T.ok(ev.some(e => e.sp === 'fan' && e.note === 'ognevka'), 'нет наблюдения «огнёвки на веернике»');
  });

  T.test('волнолист раскрывается в луче и сворачивается в темноте', () => {
    const ev = T.captureEvents();
    quiet();
    const fe = E().ferns[0];
    S().light = true; aimBeamAt(fe.top);
    T.ok(E().inBeam(fe.top), 'волнолист не в луче');
    eco(60, () => aimBeamAt(fe.top));
    T.gt(fe.open, 0.95, 'листья не раскрылись');
    T.ok(ev.some(e => e.sp === 'fern' && e.note === 'open'), 'нет наблюдения «раскрывается»');
    S().light = false; eco(240);
    T.lt(fe.open, 0.05, 'листья не свернулись в темноте');
  });

  T.test('без света волнолист свёрнут (контроль)', () => {
    quiet();
    const fe = E().ferns[0];
    S().light = false; eco(60, () => aimBeamAt(fe.top));
    T.eq(fe.open, 0);
  });

  T.test('под раскрытым волнолистом моллюски, к ним приплывает стая', () => {
    const ev = T.captureEvents();
    quiet();
    const fe = E().ferns.find(x => x.i >= 4), sh = E().shoals[2];
    S().light = true; eco(60, () => aimBeamAt(fe.top));
    T.gt(fe.open, 0.8);
    T.ok(E().ferns.some(x => x.open > 0.8 && sh.goal.distanceTo(x.top) < 0.01), 'стая не плывёт к моллюскам'); // к любому раскрытому листу куртины
    for (let i = 0; i < 300 && !ev.some(e => e.sp === 'fern' && e.note === 'mollusk'); i++) eco(1, () => aimBeamAt(fe.top));
    T.ok(ev.some(e => e.sp === 'fern' && e.note === 'mollusk'), 'нет наблюдения «моллюски»');
  });

  T.test('веерник сканируют с мостика', () => {
    quiet(); S().light = false;
    const f = E().fans[E().fans.length - 1];
    G.Game.toggleHelm(); D().frame(1);
    aimBeamAt(f.top, 22);
    G.Ctl.actionDown = true;
    for (let i = 0; i < 80 && !G.SPECIES.fan.scanned; i++) { aimBeamAt(f.top, 22); D().lookAt(f.top); D().frame(1); }
    G.Ctl.actionDown = false; D().frame(1);
    T.ok(G.SPECIES.fan.scanned, 'веерник не отсканирован');
  });
});
