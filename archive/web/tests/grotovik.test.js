'use strict';
/* Гротовик — живой остров с рифом и стаей на спине */
T.describe('Гротовик', () => {
  const E = () => G.Eco, S = () => G.Ship, D = () => G.Game.debug;
  const eco = (n, dt = 0.05) => { for (let i = 0; i < n; i++) { G.Game.t += dt; E().update(dt, G.Game.t); } };
  const quiet = () => {
    E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });
    E().rays.forEach(r => { r.fcd = 999; });
    E().shoals.forEach(sh => { sh.follow = null; sh.followT = 0; });
  };
  const shipAway = () => { S().pos.set(-250, -20, -250); S().speed = S().vy = 0; S().applyTransform(); };
  const gr = () => E().grot;
  /* хищник гонится за светляком стаи гротовика, светляк в точке p */
  const chase = (p) => {
    const sh = gr().sh, pr = E().preds[0], f = sh.members.find(x => x.alive);
    f.p.copy(p); sh.alarm = 3;
    pr.p.copy(p).add(T.V(3, 1, 0)); pr.hunger = 1; pr.cd = 999; pr.state = 'hunt'; pr.target = f; pr.timer = 12;
    return { pr, f };
  };

  T.test('гротовик стоит на дне, его стая живёт на спине', () => {
    T.ok(gr(), 'гротовика нет');
    T.near(gr().p.y, G.World.height(gr().p.x, gr().p.z), 0.01);
    T.lt(gr().sh.home.distanceTo(gr().back), 1, 'дом стаи не на спине');
    T.ok(G.World.obstacles.includes(gr().ob), 'корабль не упирается в панцирь');
    T.eq(E().scanTargets().filter(x => x.sp === 'grot').length, 1);
    T.eq(G.nm('grot'), 'ходячий риф');
  });

  T.test('гротовик бредёт по маршруту и уносит стаю с собой', () => {
    const ev = T.captureEvents();
    quiet();
    const p0 = gr().p.clone(), sh = gr().sh;
    S().pos.copy(gr().p).add(T.V(0, 14, 20)); S().speed = S().vy = 0; S().applyTransform();
    eco(1000, 0.1); // почти 2 минуты
    let sum = 0, n = 0; // стая кружит у рифа — меряем среднее расстояние за последние 20 с
    for (let i = 0; i < 20; i++) { eco(10, 0.1); sum += Math.hypot(sh.c.x - gr().back.x, sh.c.z - gr().back.z); n++; }
    T.gt(Math.hypot(gr().p.x - p0.x, gr().p.z - p0.z), 30, 'гротовик стоит на месте');
    T.near(gr().p.y, G.World.height(gr().p.x, gr().p.z), 0.01, 'ноги не по дну');
    T.lt(sh.home.distanceTo(gr().back), 1);
    T.lt(sum / n, 7, 'стая отстала от гротовика');
    T.near(gr().ob.x, gr().p.x, 0.01); T.near(gr().ob.z, gr().p.z, 0.01);
    T.ok(ev.some(e => e.sp === 'grot' && e.note === 'drift'), 'нет наблюдения «бредёт»');
  });

  T.test('напуганная стая прячется в рифе на спине, хищник её теряет', () => {
    const ev = T.captureEvents();
    quiet(); shipAway();
    const { pr, f } = chase(gr().back.clone().add(T.V(0, 1, 0)));
    eco(5);
    T.ok(f.alive, 'хищник поймал светляка в рифе');
    T.ok(pr.target !== f, 'хищник не бросил охоту на спрятавшегося светляка');
    T.ok(ev.some(e => e.sp === 'grot' && e.note === 'hide'), 'нет наблюдения «прячется в рифе»');
  });

  T.test('вдали от рифа хищник ловит светляка той же стаи (контроль)', () => {
    const ev = T.captureEvents();
    quiet(); shipAway();
    const p = gr().back.clone().add(T.V(14, 3, 0));
    const { pr, f } = chase(p);
    for (let i = 0; i < 100 && f.alive; i++) { f.p.copy(pr.p); eco(1); }
    T.ok(!f.alive, 'хищник не поймал светляка вдали от рифа');
    T.ok(!ev.some(e => e.sp === 'grot' && e.note === 'hide'));
  });

  T.test('задетый кораблём гротовик прячет ноги и замирает', () => {
    const ev = T.captureEvents();
    quiet();
    S().yaw = 0; S().speed = S().vy = 0; S().pos.set(gr().p.x, gr().p.y + 2, gr().p.z + 9); S().applyTransform();
    eco(2);
    T.gt(gr().shy, 0, 'гротовик не заметил удара');
    T.ok(ev.some(e => e.sp === 'grot' && e.note === 'shy'), 'нет наблюдения «замирает»');
    shipAway();
    const p0 = gr().p.clone(); eco(100);
    T.lt(gr().p.distanceTo(p0), 0.01, 'гротовик идёт, хотя замер');
    T.lt(gr().legs.scale.y, 0.5, 'ноги не спрятаны');
    eco(200);
    T.gt(gr().p.distanceTo(p0), 1, 'гротовик не пошёл дальше');
    T.gt(gr().legs.scale.y, 0.9);
  });

  T.test('корабль высоко над рифом гротовика не пугает (контроль)', () => {
    quiet();
    S().yaw = 0; S().speed = S().vy = 0; S().pos.set(gr().p.x, gr().ob.top + 4, gr().p.z + 6); S().applyTransform();
    eco(40);
    T.ok(!(gr().shy > 0), 'гротовик замер от корабля над ним');
  });

  T.test('гротовика сканируют с мостика', () => {
    quiet(); S().light = false;
    G.Game.toggleHelm(); D().frame(1);
    const o = T.V(0, 0.8, -6.8), d = T.V(0, -10.8, -33.2).normalize().multiplyScalar(24);
    S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0; S().pos.copy(gr().back).sub(o).sub(d); S().applyTransform();
    G.Ctl.actionDown = true;
    for (let i = 0; i < 80 && !G.SPECIES.grot.scanned; i++) { D().lookAt(gr().back); D().frame(1); }
    G.Ctl.actionDown = false; D().frame(1);
    T.ok(G.SPECIES.grot.scanned, 'гротовик не отсканирован');
  });

  T.test('телепорт к гротовику', () => {
    T.ok(D().teleport('grot'));
    T.lt(Math.hypot(S().pos.x - gr().back.x, S().pos.z - gr().back.z), 30);
  });
});
