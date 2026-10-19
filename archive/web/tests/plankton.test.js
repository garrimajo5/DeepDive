'use strict';
/* Мерцающий планктон: светящийся след за быстрым кораблём и хищником */
T.describe('Мерцающий планктон', () => {
  const E = () => G.Eco, S = () => G.Ship, D = () => G.Game.debug;
  const eco = (n, fn) => { for (let i = 0; i < n; i++) { G.Game.t += 0.05; if (fn) fn(0.05); E().update(0.05, G.Game.t); } };
  const quiet = () => {
    E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); p.v.set(0, 0, 0); });
    E().rays.forEach(r => { r.fcd = 999; });
    /* вуали дрейфуют и могут оказаться у облака: под куполом корабль скрыт, хищник отворачивает */
    const vp = E().veils.map(v => v.p.clone());
    E().veils.forEach(v => v.p.set(v.home.x, v.p.y, v.home.z));
    T._restore.push(() => E().veils.forEach((v, i) => v.p.copy(vp[i])));
  };
  const cloud = () => E().clouds[0];
  /* поставить корабль у облака носом к нему и вести с постоянной скоростью вдоль −Z */
  const enter = (cl, back) => { S().yaw = 0; S().pitch = S().roll = 0; S().vy = 0; S().pos.set(cl.c.x, cl.c.y - 1.5, cl.c.z + back); S().applyTransform(); };
  const drive = (speed) => (dt) => { S().speed = speed; S().pos.z -= speed * dt; S().applyTransform(); };
  const lit = (cl) => { let n = 0; for (let k = 0; k < cl.glow.length; k++) if (cl.glow[k] > 0.4) n++; return n; };

  T.test('четыре облака планктона висят в толще воды', () => {
    T.eq(E().clouds.length, 4);
    E().clouds.forEach(cl => T.gt(cl.home.y - G.World.height(cl.home.x, cl.home.z), 5, 'облако лежит на дне'));
    T.eq(E().plPts.geometry.attributes.position.count, 4 * 360);
    T.eq(E().scanTargets().filter(x => x.sp === 'plankton').length, 4);
    T.eq(G.nm('plankton'), 'светящееся облако');
    G.SPECIES.plankton.scanned = true; T.eq(G.nm('plankton', 'gen'), 'мерцающего планктона');
  });

  T.test('за быстрым кораблём тянется светящийся след и гаснет', () => {
    const ev = T.captureEvents();
    quiet(); S().light = false;
    const cl = cloud(); enter(cl, 6); eco(1);
    eco(40, drive(6));
    T.gt(lit(cl), 25, 'облако не вспыхнуло');
    T.gt(E().shipWake, 0.5, 'след корабля не засчитан');
    T.ok(ev.some(e => e.sp === 'plankton' && e.note === 'wake'), 'нет наблюдения «след»');
    /* светятся точки позади носа, а не впереди */
    const pa = E().plPts.geometry.attributes.position.array; let ahead = 0;
    for (let k = 0; k < 360; k++) if (cl.glow[k] > 0.4 && pa[k * 3 + 2] < S().front.z - 3) ahead++;
    T.eq(ahead, 0, 'светится вода впереди корабля');
    S().speed = 0; eco(100);
    T.eq(lit(cl), 0, 'след не погас');
    T.eq(E().shipWake, 0);
  });

  T.test('медленный корабль проходит облако без следа', () => {
    const ev = T.captureEvents();
    quiet(); S().light = false;
    const cl = cloud(); enter(cl, 6); eco(1);
    eco(140, drive(1.5));
    T.eq(lit(cl), 0, 'облако вспыхнуло от медленного корабля');
    T.eq(E().shipWake, 0);
    T.ok(ev.some(e => e.sp === 'plankton' && e.note === 'slow'), 'нет наблюдения «медленно»');
    T.ok(!ev.some(e => e.sp === 'plankton' && e.note === 'wake'));
  });

  const hunter = () => {
    const pr = E().preds[1]; T.ok(!pr.leech);
    pr.state = 'patrol'; pr.timer = 999; pr.cd = 0; pr.hunger = 0.3; pr.target = null; pr.leechCd = 999;
    pr.p.copy(S().center).add(T.V(25, 0, 0)); pr.goal.copy(pr.p); pr.v.set(0, 0, 0);
    return pr;
  };
  T.test('след выдаёт корабль хищнику даже без прожектора', () => {
    const ev = T.captureEvents();
    quiet(); S().light = false; E().lastPing = -99;
    const cl = cloud(); enter(cl, 6); eco(1);
    const pr = hunter(); let charged = false;
    for (let i = 0; i < 40 && !charged; i++) { eco(1, drive(6)); if (pr.state === 'patrol') pr.p.copy(S().center).add(T.V(25, 0, 0)); charged = pr.state === 'charge'; }
    T.ok(charged, 'хищник не заметил след ' + [pr.state, E().shipWake, !!E().shipSheltered, E().shipHidden, pr.cd, pr.hunger, S().hull, G.Game.t - E().lastPing].join(' '));
    T.ok(ev.some(e => e.sp === 'plankton' && e.note === 'betray'), 'нет наблюдения «выдаёт»');
    T.ok(!ev.some(e => e.sp === 'pred' && e.note === 'ship'), 'бросок приписан свету');
  });

  T.test('медленный корабль без света хищник не замечает (контроль)', () => {
    quiet(); S().light = false; E().lastPing = -99;
    const cl = cloud(); enter(cl, 6); eco(1);
    const pr = hunter();
    for (let i = 0; i < 80; i++) { eco(1, drive(1.5)); if (pr.state === 'patrol') pr.p.copy(S().center).add(T.V(25, 0, 0)); }
    T.eq(pr.state, 'patrol', 'хищник пошёл на корабль без следа и света');
  });

  T.test('бросок хищника сквозь облако светится', () => {
    const ev = T.captureEvents();
    quiet(); S().pos.set(-250, -20, -250); S().speed = 0; S().applyTransform();
    const cl = cloud(), pr = E().preds[1];
    pr.state = 'retreat'; pr.timer = 999; pr.cd = 999;
    pr.p.copy(cl.c).add(T.V(-PL(), 0, 0)); pr.goal.copy(cl.c).add(T.V(40, 0, 0)); pr.v.set(6, 0, 0);
    pr.segs.forEach(s => s.copy(pr.p));
    eco(80);
    T.ok(ev.some(e => e.sp === 'plankton' && e.note === 'pred'), 'бросок хищника не оставил след');
  });
  const PL = () => 14;

  T.test('планктон сканируют с мостика', () => {
    quiet(); S().light = false;
    const cl = cloud();
    G.Game.toggleHelm(); D().frame(1);
    const d = T.V(0, -10.8, -33.2).normalize().multiplyScalar(22);
    S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0;
    S().pos.copy(cl.c).sub(T.V(0, 0.8, -6.8)).sub(d); S().applyTransform();
    G.Ctl.actionDown = true;
    for (let i = 0; i < 80 && !G.SPECIES.plankton.scanned; i++) { D().lookAt(cl.c); D().frame(1); }
    G.Ctl.actionDown = false; D().frame(1);
    T.ok(G.SPECIES.plankton.scanned, 'планктон не отсканирован');
    G.Save.save(); G.SPECIES.plankton.scanned = false; G.Save.load();
    T.ok(G.SPECIES.plankton.scanned, 'не сохранился');
  });

  T.test('телепорт к облаку планктона', () => {
    T.ok(D().teleport('plankton1'));
    const cl = E().clouds[1];
    T.lt(Math.hypot(S().pos.x - cl.home.x, S().pos.z - cl.home.z), 30);
  });
});
