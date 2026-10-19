'use strict';
/* Шлюз и манипулятор: образцы со дна через стеклянный пол лаборатории */
T.describe('Манипулятор', () => {
  const D = () => G.Game.debug, S = () => G.Ship, M = () => G.Manip, C = () => G.Ctl;
  const quiet = () => { G.Eco.preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); }); G.Eco.eels.forEach(el => { el.cd = 999; }); };
  /* корабль висит над образцом так, что тот под лабораторией, игрок в лаборатории смотрит вниз на него */
  const over = (s, h) => {
    S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0;
    S().pos.set(s.pos.x, s.pos.y + (h || 7), s.pos.z - 11.5); S().applyTransform();
    const pl = G.Game.player; pl.x = 0; pl.z = 11; D().frame(1); D().lookAt(s.pos); D().frame(1);
  };
  const hold = (n) => { C().actionDown = true; for (let i = 0; i < n; i++) { D().lookAt(M().target ? M().target.pos : M().samples[0].pos); D().frame(1); } C().actionDown = false; };

  T.test('на дне лежат образцы четырёх видов, рука сложена под лабораторией', () => {
    const kinds = new Set(M().samples.map(s => s.kind));
    ['moss', 'shell', 'coral', 'spine'].forEach(k => T.ok(kinds.has(k), 'нет образцов: ' + k));
    M().samples.forEach(s => T.lt(s.pos.y - G.World.height(s.pos.x, s.pos.z), 0.5, 'образец висит над дном'));
    T.eq(M().state, 'idle'); T.eq(S().cargo.length, 0);
    S().tubeOrbs.forEach(o => T.ok(!o.visible, 'колба не пуста'));
  });

  T.test('сквозь пол лаборатории видно образец, удержание кнопки — рука достаёт его в колбу', () => {
    quiet(); S().light = true;
    const s = M().samples[0]; over(s);
    T.eq(D().actionLabel(), 'Манипулятор: взять образец (держать)');
    hold(10);
    T.eq(M().state, 'reach'); T.gt(M().prog, 0.2);
    T.gt(M().arm.tipL.distanceTo(M().arm.fold), 1, 'рука не выдвигается');
    hold(30);
    T.ok(s.taken, 'образец не взят');
    for (let i = 0; i < 40 && M().state !== 'idle'; i++) D().frame(1);
    T.eq(M().state, 'idle');
    T.eq(S().cargo.length, 1); T.eq(S().cargo[0].kind, 'moss');
    T.ok(S().tubeOrbs[0].visible, 'образца нет в колбе');
    T.lt(M().arm.tipL.distanceTo(M().arm.fold), 0.01, 'рука не сложилась');
    D().frame(1); T.ok(D().actionLabel() !== 'Манипулятор: взять образец (держать)', 'взятый образец снова в прицеле');
  });

  T.test('отпустить кнопку рано — рука возвращается пустой (контроль)', () => {
    quiet();
    const s = M().samples[1]; over(s);
    hold(20); C().actionDown = false;
    for (let i = 0; i < 60; i++) D().frame(1);
    T.ok(!s.taken); T.eq(M().state, 'idle'); T.eq(S().cargo.length, 0);
  });

  T.test('слишком далеко — манипулятор не дотянется', () => {
    quiet();
    const s = M().samples[2]; over(s, 20);
    T.ok(D().actionLabel() !== 'Манипулятор: взять образец (держать)', 'дотянулись на 20 м');
    hold(80);
    T.ok(!s.taken);
  });

  T.test('с мостика манипулятором не управляют', () => {
    quiet();
    const s = M().samples[0]; over(s);
    const pl = G.Game.player; pl.x = -3; pl.z = -3; D().frame(1); D().lookAt(s.pos); D().frame(1);
    T.ok(D().actionLabel() !== 'Манипулятор: взять образец (держать)');
  });

  T.test('в колбах — три последних образца', () => {
    quiet();
    ['moss', 'shell', 'coral', 'spine'].forEach(k => S().cargo.push({ kind: k, name: M().KIND[k].name }));
    S().showTubes();
    T.ok(S().tubeOrbs.every(o => o.visible));
    T.eq('#' + S().tubeOrbs[2].material.color.getHexString(), '#' + new THREE.Color(M().KIND.spine.color).getHexString());
  });
});
