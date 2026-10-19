'use strict';
/* Присоска: прилипалы катаются на ледокрылах, перебираются на корпус и отпугивают стеклоуста */
T.describe('Присоска', () => {
  const E = () => G.Eco, S = () => G.Ship, D = () => G.Game.debug;
  const eco = (n, fn) => { for (let i = 0; i < n; i++) { G.Game.t += 0.05; if (fn) fn(); E().update(0.05, G.Game.t); } };
  const quiet = () => {
    E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });
    E().eels.forEach(el => { el.cd = 999; });
  };
  const ray = () => E().rays[0];
  /* корабль держится рядом с ледокрылом (сбоку, на его высоте) */
  const nearRay = (dist) => () => { const r = ray(); S().speed = S().vy = 0; S().pos.set(r.p.x + dist, r.p.y - 1.5, r.p.z); S().applyTransform(); };
  const onHull = () => E().remoras.filter(r => r.state === 'hull');
  const shipAway = () => { S().pos.set(-250, -20, -250); S().speed = S().vy = 0; S().applyTransform(); };
  /* посадить прилипал на корпус, подойдя к ледокрылу */
  const board = () => { eco(1); eco(200, nearRay(10)); };

  T.test('прилипалы катаются на ледокрылах', () => {
    T.eq(E().remoras.length, 6);
    quiet(); shipAway(); eco(2);
    E().remoras.forEach(rm => { T.eq(rm.state, 'ray'); T.lt(rm.p.distanceTo(rm.ray.p), 3, 'прилипала не на ледокрыле'); });
    T.eq(E().hullRemoras, 0);
    T.eq(E().scanTargets().filter(x => x.sp === 'prisoska').length, 6);
    T.ok(E().scanTargets().filter(x => x.sp === 'prisoska').every(x => x.noSonar), 'мелкие прилипалы на сонаре');
  });

  T.test('у ледокрыла прилипалы перебираются на корпус и держатся там', () => {
    const ev = T.captureEvents();
    quiet(); board();
    T.eq(onHull().length, 3, 'не все прилипалы ледокрыла перебрались');
    T.eq(E().hullRemoras, 3);
    T.ok(ev.some(e => e.sp === 'prisoska' && e.note === 'hop'), 'нет наблюдения «перебирается»');
    T.ok(ev.some(e => e.sp === 'prisoska' && e.note === 'drag'), 'нет наблюдения «тормозит»');
    const slots = new Set(onHull().map(r => r.slot)); T.eq(slots.size, 3, 'две прилипалы в одном месте');
    shipAway(); eco(20);
    onHull().forEach(rm => T.lt(rm.p.distanceTo(S().center), 14, 'прилипала отстала от корабля'));
    T.eq(E().hullRemoras, 3);
  });

  T.test('вдали от ледокрыла прилипалы не перебираются (контроль)', () => {
    const ev = T.captureEvents();
    quiet(); eco(1); eco(200, nearRay(35));
    T.eq(E().hullRemoras, 0);
    T.ok(ev.some(e => e.sp === 'prisoska' && e.note === 'ride'), 'нет наблюдения «катаются»');
  });

  const atLair = () => { const L = G.World.lairs[0]; S().yaw = 0; S().speed = S().vy = 0; S().pos.set(L.mouth.x, L.mouth.y + 4, L.mouth.z + 16); S().applyTransform(); };
  T.test('стеклоуст не садится на корпус с прилипалами', () => {
    const ev = T.captureEvents();
    quiet(); board(); T.gt(E().hullRemoras, 0);
    atLair(); E().eels[0].cd = 0;
    for (let i = 0; i < 300; i++) { atLair(); eco(1); }
    T.eq(E().latched, null, 'стеклоуст присосался');
    T.ok(ev.some(e => e.sp === 'prisoska' && e.note === 'eel'), 'нет наблюдения «отпугивает»');
  });

  T.test('без прилипал стеклоуст присасывается (контроль)', () => {
    quiet(); shipAway(); eco(2); T.eq(E().hullRemoras, 0);
    /* скребуны и рыбы у расщелины отвлекли бы стеклоуста на охоту — убираем их на время теста */
    const L = G.World.lairs[0].mouth;
    const gone = [...E().grazers.filter(g => g.alive && g.p.distanceTo(L) < 12), ...E().fish.filter(f => f.alive && f.p.distanceTo(L) < 10)];
    gone.forEach(x => { x.alive = false; x.t = 1e9; });
    T._restore.push(() => gone.forEach(x => { x.t = 0; }));
    atLair(); E().eels[0].cd = 0;
    for (let i = 0; i < 300 && !E().latched; i++) { atLair(); eco(1); }
    T.ok(E().latched, 'стеклоуст не присосался');
  });

  T.test('прилипалы тормозят корабль', () => {
    const top = () => {
      S().pos.set(0, -12, 60); S().yaw = 0; S().speed = S().vy = 0; S().applyTransform();
      S().input.thrust = 1; S().input.turn = S().input.vert = 0;
      for (let i = 0; i < 300; i++) S().update(0.05, 0);
      S().input.thrust = 0; return S().speed;
    };
    quiet(); shipAway(); eco(1);
    const free = top();
    E().hullRemoras = 6;
    const loaded = top();
    E().hullRemoras = 0;
    T.gt(free, 6, 'без прилипал корабль медленный');
    T.lt(loaded, free - 1, 'прилипалы не тормозят');
  });

  T.test('разряд по корпусу сбрасывает прилипал, они уплывают к ледокрылу', () => {
    const ev = T.captureEvents();
    quiet(); board(); T.gt(E().hullRemoras, 0);
    shipAway(); eco(2);
    S().energy = 60; G.Game.zap();
    T.eq(E().hullRemoras, 0);
    T.ok(ev.some(e => e.sp === 'prisoska' && e.note === 'zap'), 'нет наблюдения «разряд»');
    for (let i = 0; i < 2000 && E().remoras.some(r => r.state !== 'ray'); i++) eco(1);
    E().remoras.forEach(rm => T.eq(rm.state, 'ray', 'прилипала не вернулась на ледокрыла'));
    eco(40, nearRay(10));
    T.eq(E().hullRemoras, 0, 'сразу после разряда прилипалы снова на корпусе');
  });

  T.test('прилипалу сканируют на корпусе через иллюминатор', () => {
    quiet(); board(); shipAway(); eco(2);
    const rm = onHull().find(r => r.slot === 0); // нижний угол лобового стекла
    T.ok(rm, 'никто не сел на лобовое стекло');
    G.Game.toggleHelm(); D().frame(1);
    G.Ctl.actionDown = true;
    for (let i = 0; i < 80 && !G.SPECIES.prisoska.scanned; i++) { D().lookAt(rm.p); D().frame(1); }
    G.Ctl.actionDown = false; D().frame(1);
    T.ok(G.SPECIES.prisoska.scanned, 'прилипала не отсканирована (слот ' + rm.slot + ')');
  });
});
