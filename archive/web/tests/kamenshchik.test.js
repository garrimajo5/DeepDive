'use strict';
/* Каменщик (прячет венчики от крупных) и трубный орган (гул заглушает двигатели) */
T.describe('Каменщик и трубный орган', () => {
  const E = () => G.Eco, S = () => G.Ship, D = () => G.Game.debug;
  const eco = (n, fn) => { for (let i = 0; i < n; i++) { G.Game.t += 0.05; if (fn) fn(); E().update(0.05, G.Game.t); } };
  const quiet = () => {
    E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });
    E().rays.forEach(r => { r.fcd = 999; });
    E().eels.forEach(el => { el.cd = 999; });
    E().lastPing = -99;
  };
  const shipAway = () => { S().pos.set(-250, -20, -250); S().speed = S().vy = 0; S().applyTransform(); };
  const col = () => E().masons[0];
  const hiddenN = c => c.worms.filter(w => w.ext < 0.3).length;
  /* корабль идёт вдоль ряда каменщиков на высоте h над ними со скоростью v */
  const pass = (c, h, v) => { const a = c.worms[0].top, b = c.worms[KM().N - 1].top; S().yaw = 0; S().pitch = S().roll = 0; S().vy = 0; S().speed = v; S().pos.copy(a).lerp(b, 0.5); S().pos.y += h; S().applyTransform(); };
  const KM = () => ({ N: col().worms.length });

  T.test('ряды каменщиков у огнецвета и два трубных органа', () => {
    T.eq(E().masons.length, E().stations.length);
    E().masons.forEach(c => {
      T.eq(c.worms.length, 16);
      T.lt(c.c.distanceTo(c.st.base), 8, 'ряд далеко от огнецвета');
      c.worms.forEach(w => T.near(w.p.y, G.World.height(w.p.x, w.p.z) - 0.02, 0.01));
    });
    T.eq(E().organs.length, 2);
    const sp = E().scanTargets().map(x => x.sp);
    T.eq(sp.filter(x => x === 'kamen').length, E().masons.length);
    T.eq(sp.filter(x => x === 'organ').length, 2);
  });

  T.test('корабль на ходу рядом — венчики прячутся, потом раскрываются', () => {
    const ev = T.captureEvents();
    quiet();
    eco(20, () => pass(col(), 3, 2));
    T.gt(hiddenN(col()), 4, 'венчики не спрятались');
    T.ok(ev.some(e => e.sp === 'kamen' && e.note === 'hide'), 'нет наблюдения «прячут венчики»');
    shipAway(); eco(140);
    T.eq(hiddenN(col()), 0, 'венчики не раскрылись');
    col().worms.forEach(w => T.gt(w.ext, 0.95));
  });

  T.test('неподвижный корабль рядом венчики не пугает (контроль)', () => {
    const ev = T.captureEvents();
    quiet();
    eco(60, () => pass(col(), 3, 0));
    T.eq(hiddenN(col()), 0);
    T.ok(!ev.some(e => e.sp === 'kamen'));
  });

  T.test('по спрятавшимся рядам видно проходящего хищника', () => {
    const ev = T.captureEvents();
    quiet();
    const c = col(), pr = E().preds[1];
    S().pos.copy(c.c).add(T.V(0, 12, 30)); S().speed = S().vy = 0; S().applyTransform();
    pr.state = 'retreat'; pr.timer = 999; pr.cd = 999;
    const a = c.worms[0].top, b = c.worms[15].top;
    for (let i = 0; i <= 40; i++) { pr.p.copy(a).lerp(b, i / 40); pr.p.y += 2; eco(1); }
    T.gt(hiddenN(c), 8, 'ряд не спрятался от хищника');
    T.ok(ev.some(e => e.sp === 'kamen' && e.note === 'warn'), 'нет наблюдения «видно хищника»');
  });

  /* корабль идёт на ходу в открытой воде, хищник рядом */
  const openWater = (v) => () => { S().yaw = 0; S().pitch = S().roll = 0; S().vy = 0; S().speed = v; S().pos.set(-110, -12, -30); S().pos.y = Math.max(S().pos.y, G.World.height(-110, -30) + 10); S().applyTransform(); };
  const hunter = (d) => {
    const pr = E().preds[1]; T.ok(!pr.leech);
    pr.state = 'patrol'; pr.timer = 999; pr.cd = 0; pr.hunger = 0.3; pr.leechCd = 999; pr.target = null;
    pr.p.copy(S().center).add(T.V(d, 0, 0)); pr.goal.copy(pr.p); pr.v.set(0, 0, 0);
    return pr;
  };
  T.test('серпохвост слышит быстрый ход двигателей рядом', () => {
    const ev = T.captureEvents();
    quiet(); S().light = false;
    openWater(5)(); eco(1, openWater(5));
    T.ok(!E().shipMasked && !E().shipHidden && !E().shipSheltered, 'корабль в укрытии');
    const pr = hunter(15);
    eco(2, openWater(5));
    T.eq(pr.state, 'charge', 'хищник не услышал корабль');
    T.ok(ev.some(e => e.sp === 'pred' && e.note === 'hear'), 'нет наблюдения «слышит двигатели»');
  });

  T.test('тихий ход хищник не слышит (контроль)', () => {
    quiet(); S().light = false;
    openWater(1.5)(); eco(1, openWater(1.5));
    const pr = hunter(15);
    eco(40, openWater(1.5));
    T.eq(pr.state, 'patrol');
  });

  T.test('у трубного органа гул заглушает двигатели', () => {
    const ev = T.captureEvents();
    quiet(); S().light = false;
    const og = E().organs[0];
    const near = () => { S().yaw = 0; S().pitch = S().roll = 0; S().vy = 0; S().speed = 5; S().pos.copy(og.p).add(T.V(0, 8, 8)); S().applyTransform(); };
    near(); eco(1, near);
    T.ok(E().shipMasked === og, 'корабль не у органа');
    const pr = hunter(15);
    eco(40, near);
    T.ok(pr.state !== 'charge', 'хищник услышал корабль сквозь гул');
    T.ok(ev.some(e => e.sp === 'organ' && e.note === 'mask'), 'нет наблюдения «гул заглушает»');
    T.ok(ev.some(e => e.sp === 'organ' && e.note === 'hum'), 'нет наблюдения «гудит»');
  });

  T.test('трубный орган сканируют с мостика', () => {
    quiet(); S().light = false;
    const og = E().organs[0];
    G.Game.toggleHelm(); D().frame(1);
    const o = T.V(0, 0.8, -6.8), d = T.V(0, -10.8, -33.2).normalize().multiplyScalar(22);
    S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0; S().pos.copy(og.top).sub(o).sub(d); S().applyTransform();
    G.Ctl.actionDown = true;
    for (let i = 0; i < 80 && !G.SPECIES.organ.scanned; i++) { D().lookAt(og.top); D().frame(1); }
    G.Ctl.actionDown = false; D().frame(1);
    T.ok(G.SPECIES.organ.scanned, 'трубный орган не отсканирован');
  });
});
