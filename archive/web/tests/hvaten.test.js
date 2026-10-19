'use strict';
/* Хватень (анемон-засадчик) и пестрянка (его симбионт) */
T.describe('Хватень и пестрянка', () => {
  const E = () => G.Eco, S = () => G.Ship, D = () => G.Game.debug;
  let t = 1000;
  const eco = (n) => { for (let i = 0; i < n; i++) { t += 0.05; E().update(0.05, t); } };
  const quiet = () => {
    E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });
    E().rays.forEach(r => { r.fcd = 999; });
    E().shoals.forEach(sh => { sh.follow = null; sh.followT = 0; });
    /* вуали дрейфуют от прогона к прогону по-разному и могут оттеснять стаю — убрать их подальше */
    const vp = E().veils.map(v => v.p.clone());
    E().veils.forEach(v => v.p.set(-280, v.p.y, -280));
    T._restore.push(() => E().veils.forEach((v, i) => v.p.copy(vp[i])));
  };
  /* поставить корабль так, чтобы точка была в луче прожектора в 25 м от фонаря */
  const aimBeamAt = (p) => {
    const o = T.V(0, 0.8, -6.8), d = T.V(0, -10.8, -33.2).normalize().multiplyScalar(25);
    S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0;
    S().pos.copy(p).sub(o).sub(d); S().applyTransform();
  };
  /* убрать остальных рыб от хватня, чтобы проверять одну */
  const alone = (hv, f) => {
    const gone = E().fish.filter(x => x !== f && x.alive && x.p.distanceTo(hv.mouth) < 10);
    gone.forEach(x => { x.alive = false; x.t = 999; });
    T._restore.push(() => gone.forEach(x => { x.t = 0; }));
  };
  const shipAway = () => { S().pos.set(-250, -20, -250); S().speed = S().vy = 0; S().applyTransform(); };

  T.test('хватни сидят на дне у стай, в каждом живут пестрянки', () => {
    T.gt(E().anemones.length, 2, 'мало хватней');
    E().anemones.forEach(hv => {
      T.near(hv.base.y, G.World.height(hv.base.x, hv.base.z), 0.01, 'хватень не на дне');
      T.lt(Math.min(...E().shoals.map(sh => sh.home.distanceTo(hv.top))), 12, 'нет стаи рядом');
      T.eq(hv.pestr.length, 3);
    });
    T.eq(E().hvTentIM.count, E().anemones.length * 22);
    const sp = E().scanTargets().map(x => x.sp);
    T.eq(sp.filter(x => x === 'hvaten').length, E().anemones.length);
    T.eq(sp.filter(x => x === 'pestr').length, E().anemones.length);
    T.eq(G.nm('hvaten', 'gen'), 'донного анемона');
    G.SPECIES.hvaten.scanned = true; T.eq(G.nm('hvaten', 'gen'), 'хватня');
  });

  T.test('в луче прожектора хватень прячет щупальца, пестрянки ныряют к нему', () => {
    const ev = T.captureEvents();
    quiet();
    const hv = E().anemones[0];
    S().light = true; aimBeamAt(hv.top);
    T.ok(E().inBeam(hv.top), 'хватень не в луче');
    eco(20);
    T.lt(hv.open, 0.1, 'щупальца не спрятались');
    T.ok(ev.some(e => e.sp === 'hvaten' && e.note === 'hide'), 'нет наблюдения «прячется»');
    T.ok(ev.some(e => e.sp === 'pestr' && e.note === 'immune'), 'нет наблюдения про пестрянку');
    S().light = false; eco(20);
    T.ok(!hv.lit);
    T.gt(hv.open, 0.2, 'в темноте щупальца не раскрываются');
    eco(100);
    T.gt(hv.open, hv.digest > 0 ? 0.45 : 0.95, 'щупальца не раскрылись'); // сытый хватень раскрыт наполовину
  });

  T.test('без света прожектора хватень не реагирует (контроль)', () => {
    quiet();
    const hv = E().anemones[0];
    S().light = false; aimBeamAt(hv.top);
    T.ok(!E().inBeam(hv.top));
    const ev = T.captureEvents();
    eco(20);
    T.ok(!hv.lit);
    T.ok(!ev.some(e => e.sp === 'hvaten' && e.note === 'hide'), 'спрятался без света');
  });

  T.test('в темноте хватень ловит светляка, пестрянка доедает остатки', () => {
    const ev = T.captureEvents();
    quiet(); S().light = false; shipAway();
    const hv = E().anemones[0], f = E().fish.find(x => x.alive); alone(hv, f);
    for (let i = 0; i < 100 && f.alive; i++) { f.p.copy(hv.mouth); eco(1); }
    T.ok(!f.alive, 'светляк уцелел у раскрытых щупалец');
    T.ok(ev.some(e => e.sp === 'hvaten' && e.note === 'catch'), 'нет наблюдения «ловит»');
    T.gt(hv.digest, 0);
    eco(80);
    T.ok(ev.some(e => e.sp === 'pestr' && e.note === 'leftovers'), 'пестрянка не доела остатки');
    T.lt(hv.open, 0.6, 'сытый хватень раскрыт полностью');
  });

  T.test('прожектор спасает светляка от хватня', () => {
    quiet();
    const hv = E().anemones[0], f = E().fish.find(x => x.alive); alone(hv, f);
    S().light = true; aimBeamAt(hv.top);
    eco(10);
    const ev = T.captureEvents();
    for (let i = 0; i < 100; i++) { f.p.copy(hv.mouth); eco(1); }
    T.ok(f.alive, 'хватень поймал рыбу в луче ');
    T.ok(!ev.some(e => e.sp === 'hvaten' && e.note === 'catch' && e.pos.distanceTo(hv.mouth) < 1), 'хватень ловит рыбу в луче');
  });

  T.test('пестрянки выманивают стаю к щупальцам', () => {
    const ev = T.captureEvents();
    quiet(); S().light = false; shipAway();
    const hv = E().anemones[0];
    const sh = E().shoals.reduce((a, b) => (a.home.distanceTo(hv.top) < b.home.distanceTo(hv.top) ? a : b));
    E().anemones.forEach(h => { h.lureCd = 999; });
    /* стая отходит в сторону, затем пестрянки начинают подманивать */
    eco(1); // рыбы, убранные прошлым тестом, возрождаются дома — до сдвига стаи, а не после
    sh.members.forEach(f => f.p.add(T.V(10, 2, 10))); // сразу отвести стаю от хватня
    sh.goal.copy(sh.home).add(T.V(10, 2, 10)); sh.gt = 15; sh.alarm = 0; eco(40);
    const before = sh.c.distanceTo(hv.top);
    T.gt(before, 4, 'стая и так у хватня');
    hv.lureCd = 0; hv.digest = 0; hv.open = 1;
    eco(1);
    T.ok(hv.lure === sh, 'пестрянки не выбрали ближнюю стаю');
    T.ok(ev.some(e => e.sp === 'pestr' && e.note === 'lure'));
    let far = 0;
    for (let i = 0; i < 120; i++) { eco(1); far = Math.max(far, hv.pc.distanceTo(hv.top)); }
    T.lt(sh.c.distanceTo(hv.top), before - 2, `стая не приблизилась: было ${before.toFixed(1)}, стало ${sh.c.distanceTo(hv.top).toFixed(1)}`);
    T.gt(far, 1.5, 'пестрянки не выплывали к стае');
  });

  T.test('хватня и пестрянку сканируют с мостика', () => {
    quiet();
    const hv = E().anemones[0];
    S().light = false; aimBeamAt(hv.top);
    G.Game.toggleHelm(); D().frame(1);
    ['hvaten', 'pestr'].forEach(sp => {
      const pos = () => (sp === 'hvaten' ? hv.top : hv.pc);
      D().lookAt(pos()); D().frame(1);
      G.Ctl.actionDown = true;
      for (let i = 0; i < 60 && !G.SPECIES[sp].scanned; i++) { D().lookAt(pos()); D().frame(1); }
      G.Ctl.actionDown = false; D().frame(1);
      T.ok(G.SPECIES[sp].scanned, sp + ' не отсканирован');
    });
    G.Save.save();
    G.SPECIES.hvaten.scanned = G.SPECIES.pestr.scanned = false;
    G.Save.load();
    T.ok(G.SPECIES.hvaten.scanned && G.SPECIES.pestr.scanned, 'не сохранились');
  });
});
