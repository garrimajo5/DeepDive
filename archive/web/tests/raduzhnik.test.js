'use strict';
/* Радужник: стая гребневиков вспыхивает в луче прожектора и выдаёт корабль серпохвостам */
T.describe('Радужник', () => {
  const E = () => G.Eco, S = () => G.Ship, D = () => G.Game.debug;
  /* время берём из игры: положение стаи зависит от времени, и кадры D().frame должны видеть ту же стаю */
  const eco = (n, aim) => { for (let i = 0; i < n; i++) { G.Game.t += 0.05; if (aim) aimBeamAt(aim.c); E().update(0.05, G.Game.t); } };
  const quiet = () => {
    E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });
    E().rays.forEach(r => { r.fcd = 999; });
  };
  /* поставить корабль так, чтобы точка была в луче прожектора в 25 м от фонаря */
  const aimBeamAt = (p) => {
    const o = T.V(0, 0.8, -6.8), d = T.V(0, -10.8, -33.2).normalize().multiplyScalar(25);
    S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0;
    S().pos.copy(p).sub(o).sub(d); S().applyTransform();
  };
  /* корабль рядом со стаей, но луч смотрит в сторону */
  const aimAway = (sw) => { aimBeamAt(sw.c); S().yaw = Math.PI; S().applyTransform(); };
  /* серпохвост в патруле на заданном расстоянии от корабля */
  const predAt = (dist) => {
    const pr = E().preds[1]; // без пиявника: не уплывёт на станцию чистки
    T.ok(!pr.leech);
    pr.state = 'patrol'; pr.timer = 999; pr.leechCd = 999; pr.cd = 0; pr.hunger = 0.3; pr.target = null; pr.flareCd = 0;
    pr.p.copy(S().center).add(T.V(dist, 0, 0)); pr.goal.copy(pr.p); pr.v.set(0, 0, 0);
    return pr;
  };

  T.test('три стаи радужников дрейфуют в толще воды', () => {
    T.eq(E().swarms.length, 3);
    E().swarms.forEach(sw => {
      T.gt(sw.home.y - G.World.height(sw.home.x, sw.home.z), 5, 'стая лежит на дне');
      T.lt(sw.home.y, -6, 'стая у самого льда');
    });
    T.eq(E().rdIM.count, 3 * 28);
    T.eq(E().scanTargets().filter(x => x.sp === 'raduzh').length, 3);
    T.eq(G.nm('raduzh', 'gen'), 'гребневиков');
    G.SPECIES.raduzh.scanned = true; T.eq(G.nm('raduzh', 'gen'), 'радужников');
  });

  T.test('в луче прожектора стая вспыхивает, без света гаснет', () => {
    const ev = T.captureEvents();
    quiet();
    const sw = E().swarms[0];
    S().light = true; eco(10, sw);
    T.ok(sw.lit, 'стая не в луче');
    T.gt(sw.glow, 0.95, 'стая не вспыхнула');
    T.gt(E().flare, 0.95);
    T.ok(ev.some(e => e.sp === 'raduzh' && e.note === 'flare'), 'нет наблюдения «вспыхивает»');
    const c = E().rdIM.instanceColor.array, j = sw.i * 28 * 3;
    T.gt(Math.max(c[j], c[j + 1], c[j + 2]), 0.5, 'цвет стаи не стал ярким');
    S().light = false; eco(60, sw);
    T.ok(!sw.lit);
    T.lt(sw.glow, 0.05, 'стая не погасла');
    T.ok(ev.some(e => e.sp === 'raduzh' && e.note === 'fade'), 'нет наблюдения «гаснет»');
    T.lt(Math.max(c[j], c[j + 1], c[j + 2]), 0.2, 'стая светится в темноте');
  });

  T.test('стая не вспыхивает без света и вне луча (контроль)', () => {
    const ev = T.captureEvents();
    quiet();
    const sw = E().swarms[0];
    S().light = false; eco(20, sw);
    T.eq(sw.glow, 0);
    S().light = true; aimAway(sw); eco(20);
    T.ok(!sw.lit, 'стая в луче, хотя прожектор смотрит в сторону');
    T.eq(sw.glow, 0); T.eq(E().flare, 0);
    T.ok(!ev.some(e => e.sp === 'raduzh'), 'событие без вспышки');
  });

  T.test('вспышка выдаёт корабль серпохвосту издалека', () => {
    const ev = T.captureEvents();
    quiet();
    const sw = E().swarms[0];
    S().light = true; eco(10, sw);
    const pr = predAt(80);
    T.gt(pr.p.distanceTo(S().center), 48, 'хищник и так видит корабль');
    eco(2, sw);
    T.eq(pr.state, 'investigate', 'хищник не заметил вспышку');
    T.lt(pr.goal.distanceTo(S().center), 3, 'хищник плывёт не к кораблю');
    T.ok(ev.some(e => e.sp === 'raduzh' && e.note === 'betray'), 'нет наблюдения «выдаёт корабль»');
    const d0 = pr.p.distanceTo(S().center);
    eco(60, sw);
    T.lt(pr.p.distanceTo(S().center), d0 - 10, 'хищник не приблизился');
  });

  T.test('без вспышки дальний серпохвост не замечает корабль (контроль)', () => {
    quiet();
    const sw = E().swarms[0];
    S().light = true; aimAway(sw); eco(5);
    const pr = predAt(80);
    eco(40);
    T.eq(pr.state, 'patrol', 'хищник пошёл к кораблю без вспышки');
    /* и слишком далёкий хищник вспышку не видит */
    eco(10, sw); T.gt(E().flare, 0.9);
    const far = predAt(140);
    eco(5, sw);
    T.eq(far.state, 'patrol', 'вспышку видно слишком далеко');
  });

  T.test('у станции чистки вспышка не выдаёт корабль', () => {
    quiet();
    const sw = E().swarms[0];
    S().light = true; eco(10, sw);
    const pr = predAt(80);
    E().stations[0].top.copy(S().center); // станция прямо у корабля
    T._restore.push(() => { const st = E().stations[0]; st.top.copy(st.base).y += 4.2; });
    eco(5, sw);
    T.ok(E().shipSheltered, 'корабль не у станции');
    T.eq(pr.state, 'patrol', 'хищник пошёл к кораблю у станции');
  });

  T.test('радужника сканируют с мостика, вид сохраняется', () => {
    quiet();
    const sw = E().swarms[0];
    S().light = false;
    G.Game.toggleHelm(); D().frame(1); aimBeamAt(sw.c);
    D().lookAt(sw.c); D().frame(1);
    G.Ctl.actionDown = true;
    for (let i = 0; i < 80 && !G.SPECIES.raduzh.scanned; i++) { D().lookAt(sw.c); D().frame(1); }
    G.Ctl.actionDown = false; D().frame(1);
    T.ok(G.SPECIES.raduzh.scanned, 'радужник не отсканирован');
    G.Save.save(); G.SPECIES.raduzh.scanned = false; G.Save.load();
    T.ok(G.SPECIES.raduzh.scanned, 'не сохранился');
  });

  T.test('телепорт к радужникам', () => {
    T.ok(D().teleport('raduzh0'));
    const sw = E().swarms[0];
    T.lt(Math.hypot(S().pos.x - sw.home.x, S().pos.z - sw.home.z), 30);
  });
});
