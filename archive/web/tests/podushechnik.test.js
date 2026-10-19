'use strict';
/* Подушечник (чернила прячут стаю и корабль) и пузырчатка-фонарь (споры собирают рыб) */
T.describe('Подушечник и пузырчатка-фонарь', () => {
  const E = () => G.Eco, S = () => G.Ship, D = () => G.Game.debug;
  const eco = (n, fn) => { for (let i = 0; i < n; i++) { G.Game.t += 0.05; if (fn) fn(); E().update(0.05, G.Game.t); } };
  const quiet = () => {
    E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });
    E().rays.forEach(r => { r.fcd = 999; });
    E().eels.forEach(el => { el.cd = 999; });
    E().shoals.forEach(sh => { sh.follow = null; sh.followT = 0; });
    E().lastPing = -99;
  };
  const shipAway = () => { S().pos.set(-250, -20, -250); S().speed = S().vy = 0; S().applyTransform(); };
  const cu = () => E().cushions[0];
  /* корабль касается подушечника */
  const touch = (c) => () => { S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0; S().pos.set(c.base.x, c.top.y - 0.5, c.base.z + 2); S().applyTransform(); };

  T.test('подушечники у стай, пузырчатка у пятен мха', () => {
    T.eq(E().cushions.length, 2); T.eq(E().bladders.length, E().schools.length);
    E().cushions.forEach(c => T.lt(Math.hypot(c.base.x - c.sh.home.x, c.base.z - c.sh.home.z), 5, 'подушечник далеко от стаи'));
    E().bladders.forEach(b => T.lt(Math.hypot(b.base.x - b.sc.c.x, b.base.z - b.sc.c.z), 6, 'пузырчатка далеко от мха'));
    const sp = E().scanTargets().map(x => x.sp);
    T.eq(sp.filter(x => x === 'cushion').length, 2); T.eq(sp.filter(x => x === 'bladder').length, E().bladders.length);
  });

  T.test('от касания корабля подушечник сжимается и окутывает корабль чернилами', () => {
    const ev = T.captureEvents();
    quiet(); eco(2, touch(cu()));
    T.gt(cu().ink, 0, 'чернил нет');
    T.gt(cu().squeeze, 0.5, 'подушечник не сжался');
    T.ok(E().shipInk === cu(), 'корабль не в чернилах');
    T.ok(E().shipHidden, 'корабль в чернилах не скрыт');
    T.ok(ev.some(e => e.sp === 'cushion' && e.note === 'touch'), 'нет наблюдения «сжимается»');
    const n = ev.filter(e => e.sp === 'cushion' && e.note === 'touch').length;
    eco(220, touch(cu())); // чернила рассеялись, но подушечник ещё не восстановился
    T.lt(cu().ink, 0); T.eq(ev.filter(e => e.sp === 'cushion' && e.note === 'touch').length, n, 'чернила без перезарядки');
    T.ok(!E().shipInk);
  });

  T.test('серпохвост теряет корабль в чернилах', () => {
    const ev = T.captureEvents();
    quiet(); S().light = true; eco(2, touch(cu()));
    const pr = E().preds[1]; pr.p.copy(S().center).add(T.V(20, 0, 0)); pr.state = 'charge'; pr.timer = 10; pr.cd = 0;
    const hull = S().hull;
    eco(60, touch(cu()));
    T.eq(S().hull, hull, 'хищник укусил корабль в чернилах');
    T.ok(ev.some(e => e.sp === 'cushion' && e.note === 'ship'), 'нет наблюдения «корабль в чернилах»');
  });

  T.test('без чернил серпохвост кусает корабль (контроль)', () => {
    quiet(); S().light = true;
    cu().cd = 999; eco(2, touch(cu())); T.ok(!E().shipInk);
    const pr = E().preds[1]; pr.p.copy(S().center).add(T.V(20, 0, 0)); pr.state = 'charge'; pr.timer = 10; pr.cd = 0;
    const hull = S().hull;
    for (let i = 0; i < 200 && S().hull === hull; i++) eco(1, touch(cu()));
    T.lt(S().hull, hull, 'хищник не укусил');
  });

  T.test('напуганная стая сжимает подушечник и прячется в чернилах', () => {
    const ev = T.captureEvents();
    quiet(); shipAway();
    const c = cu(), sh = c.sh, f = sh.members.find(x => x.alive);
    f.p.copy(c.top).add(T.V(0, 0.5, 0)); sh.alarm = 3;
    eco(1);
    T.gt(c.ink, 0, 'стая не сжала подушечник');
    const pr = E().preds[0]; f.p.copy(c.inkC); pr.p.copy(c.inkC).add(T.V(3, 0, 0)); pr.hunger = 1; pr.cd = 999; pr.state = 'hunt'; pr.target = f; pr.timer = 12;
    eco(5);
    T.ok(f.alive, 'светляка поймали в чернилах');
    T.ok(pr.target !== f, 'хищник не потерял светляка');
    T.ok(ev.some(e => e.sp === 'cushion' && e.note === 'hide'), 'нет наблюдения «прячется в чернилах»');
  });

  T.test('спелая пузырчатка лопается, на споры слетаются монетники и светляки', () => {
    const ev = T.captureEvents();
    quiet(); shipAway();
    const bl = E().bladders[0], sh = E().shoals[0];
    sh.members.forEach(f => f.p.copy(bl.c).add(T.V(15, 1, 0))); eco(1);
    bl.ripe = 1; eco(3);
    T.gt(bl.life, 0, 'луковицы не лопнули');
    T.ok(ev.some(e => e.sp === 'bladder' && e.note === 'pop'), 'нет наблюдения «лопаются»');
    T.lt(sh.goal.distanceTo(bl.c), 0.01, 'стая не плывёт на споры');
    let near = 0;
    for (let i = 0; i < 260; i++) { eco(1); near = Math.max(near, bl.sc.members.filter(c => c.alive && c.p.distanceTo(bl.c) < 3).length); }
    T.gt(near, 3, 'монетники не приплыли к спорам');
    T.ok(ev.some(e => e.sp === 'bladder' && e.note === 'feed'), 'нет наблюдения «слетаются»');
    T.lt(bl.life, 0); T.eq(bl.sc.feed, null, 'монетники кормятся на погасших спорах');
  });

  T.test('корабль лопает только спелые луковицы (контроль)', () => {
    quiet();
    const bl = E().bladders[0];
    const by = () => { S().yaw = 0; S().pitch = S().roll = 0; S().vy = 0; S().speed = 1; S().pos.set(bl.base.x, bl.base.y + 1.5, bl.base.z - 2); S().applyTransform(); }; // центр корабля в 2 м от стеблей
    bl.ripe = 0.3; eco(20, by);
    T.eq(bl.life, 0, 'лопнула недозрелая');
    bl.ripe = 0.7; eco(2, by);
    T.gt(bl.life, 0, 'корабль не задел спелые луковицы');
  });

  T.test('подушечник сканируют с мостика', () => {
    quiet(); S().light = false;
    const c = cu();
    G.Game.toggleHelm(); D().frame(1);
    const o = T.V(0, 0.8, -6.8), d = T.V(0, -10.8, -33.2).normalize().multiplyScalar(22);
    S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0; S().pos.copy(c.top).sub(o).sub(d); S().applyTransform();
    G.Ctl.actionDown = true;
    for (let i = 0; i < 80 && !G.SPECIES.cushion.scanned; i++) { D().lookAt(c.top); D().frame(1); }
    G.Ctl.actionDown = false; D().frame(1);
    T.ok(G.SPECIES.cushion.scanned, 'подушечник не отсканирован');
  });
});
