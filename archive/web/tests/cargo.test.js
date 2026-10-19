'use strict';
/* Грузовой отсек: образцы на полках, улучшения корабля за образцы */
T.describe('Грузовой отсек', () => {
  const D = () => G.Game.debug, S = () => G.Ship, Cg = () => G.Cargo, C = () => G.Ctl;
  const give = (kind, n) => { for (let i = 0; i < n; i++) S().cargo.push({ kind, name: G.Manip.KIND[kind].name }); S().showTubes(); };
  const atTerminal = () => { const pl = G.Game.player; pl.x = 0; pl.z = 22.4; pl.yaw = Math.PI; pl.pitch = -0.2; D().frame(1); };
  const press = (x, y) => { C().padMove.x = x; C().padMove.y = y; D().frame(1); C().padMove.x = 0; C().padMove.y = 0; D().frame(1); };

  T.test('из машинного отделения люк ведёт в трюм', () => {
    const pl = G.Game.player; S().doors[2].open = true; D().frame(30);
    pl.x = 0; pl.z = 18.8; pl.yaw = Math.PI; pl.pitch = 0; D().frame(1); // за реактором, у кормового люка
    T.eq(D().actionLabel(), 'Открыть люк');
    C().padMove.y = 1; D().frame(30); C().padMove.y = 0; T.lt(pl.z, 19.2, 'прошли сквозь закрытый люк');
    C().actionPressed = true; D().frame(30); T.gt(S().doors[3].t, 0.85);
    C().padMove.y = 1; D().frame(60); C().padMove.y = 0;
    T.eq(G.Game.room, 'cargo'); T.gt(pl.z, 20.5);
  });

  T.test('образцы лежат на полках трюма', () => {
    const im = Cg().im, e = new THREE.Matrix4().elements;
    const shown = () => { let n = 0; for (let i = 0; i < im.count; i++) { im.getMatrixAt(i, new THREE.Matrix4().copy(new THREE.Matrix4())); const m = new THREE.Matrix4(); im.getMatrixAt(i, m); if (m.elements[0] > 0.5) n++; } return n; };
    T.eq(shown(), 0, 'полки не пусты');
    give('moss', 3); give('shell', 1);
    T.eq(shown(), 4);
  });

  T.test('улучшение ставится за нужные образцы и тратит их', () => {
    T.ok(!Cg().can(Cg().UP.find(u => u.id === 'batt')), 'улучшение без образцов');
    T.ok(!Cg().install('batt'));
    give('moss', 3);
    T.ok(Cg().install('batt'), 'не поставили');
    T.ok(Cg().has('batt')); T.eq(S().cargo.length, 0, 'образцы не потрачены');
    give('moss', 3); T.ok(!Cg().install('batt'), 'одно улучшение дважды');
  });

  T.test('терминал: крестовина выбирает, вправо — ставит, кнопка закрывает', () => {
    give('shell', 2); atTerminal();
    T.eq(D().actionLabel(), 'Терминал трюма: улучшения');
    C().actionPressed = true; D().frame(1);
    T.ok(Cg().isOpen() && !document.getElementById('cargo').hidden, 'терминал не открылся');
    press(0, -1); press(0, -1); T.eq(Cg().UP[Cg().sel].id, 'sonar');
    press(1, 0); T.ok(Cg().has('sonar'), 'вправо не поставило');
    T.ok(document.querySelector('#cargo [data-u="sonar"]').classList.contains('own'));
    C().actionPressed = true; D().frame(1); T.ok(!Cg().isOpen());
  });

  T.test('кнопки терминала работают касанием', () => {
    give('coral', 2); give('spine', 1); atTerminal(); C().actionPressed = true; D().frame(1);
    document.querySelector('#cargo [data-u="hull"] button').click();
    T.ok(Cg().has('hull'));
    document.querySelector('#cargo [data-a="close"]').click(); T.ok(!Cg().isOpen());
  });

  T.test('броня ослабляет удары, аккумуляторы быстрее копят энергию', () => {
    const quiet = () => G.Eco.preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });
    quiet(); G.Breach.cd = 999;
    S().hull = 100; G.Game.hullHit(10, 'bite'); T.eq(S().hull, 90);
    give('coral', 2); give('spine', 1); Cg().install('hull');
    S().hull = 100; G.Game.hullHit(10, 'bite'); T.eq(S().hull, 93, 'броня не держит');
    S().pos.set(-110, -12, -30); S().pos.y = Math.max(S().pos.y, G.World.height(-110, -30) + 12); S().light = false; S().applyTransform();
    const charge = () => { S().energy = 20; for (let i = 0; i < 100; i++) S().update(0.05, 0); return S().energy - 20; };
    const e1 = charge(); give('moss', 3); Cg().install('batt'); const e2 = charge();
    T.near(e2, e1 * 1.4, 0.05);
  });

  T.test('фильтр сонара дешевле, глушитель прячет быстрый ход', () => {
    G.Eco.preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });
    S().pos.set(0, -20, 60); S().applyTransform();
    S().energy = 100; G.Sonar.ping(); T.eq(S().energy, 94);
    give('shell', 2); Cg().install('sonar'); S().energy = 100; G.Sonar.ping(); T.eq(S().energy, 96);
    /* серпохвост в 18 м: без глушителя слышит быстрый ход, с глушителем — нет */
    const pr = G.Eco.preds[1]; S().light = false; G.Eco.lastPing = -99;
    const test = () => { S().pos.set(-110, -12, -30); S().pos.y = Math.max(S().pos.y, G.World.height(-110, -30) + 12); S().yaw = 0; S().speed = 5; S().applyTransform();
      pr.state = 'patrol'; pr.timer = 999; pr.cd = 0; pr.hunger = 0.3; pr.leechCd = 999; pr.p.copy(S().center).add(T.V(18, 0, 0)); pr.goal.copy(pr.p);
      for (let i = 0; i < 3; i++) { G.Game.t += 0.05; S().speed = 5; G.Eco.update(0.05, G.Game.t); } return pr.state; };
    T.eq(test(), 'charge', 'без глушителя не слышит');
    give('coral', 1); give('moss', 2); Cg().install('quiet');
    T.eq(test(), 'patrol', 'с глушителем слышит за 18 м');
  });
});
