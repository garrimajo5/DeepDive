'use strict';
/* Событие «перегрев реактора»: безопасно только 60 единиц, лишнее греет, на 100° — аварийный сброс */
T.describe('Перегрев реактора', () => {
  const D = () => G.Game.debug, S = () => G.Ship, P = () => G.Power;
  const quiet = () => { G.Eco.preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); }); G.Eco.eels.forEach(el => { el.cd = 999; }); };
  const openWater = () => { S().pos.set(-110, -12, -30); S().pos.y = Math.max(S().pos.y, G.World.height(-110, -30) + 12); S().yaw = 0; S().speed = S().vy = 0; S().applyTransform(); };
  const run = (n) => { for (let i = 0; i < n; i++) S().update(0.05, G.Game.t += 0.05); };
  const cut = () => { P().set('eng', 20); P().set('life', 10); P().set('zap', 5); P().set('son', 15); P().set('lamp', 10); }; // 60

  T.test('у чёрного курильщика реактор перегревается', () => {
    quiet();
    const v = G.World.pois.find(p => p.key === 'geyser');
    S().pos.set(v.pos.x + 20, -12, v.pos.z); S().applyTransform();
    run(2);
    T.ok(P().hot, 'нет перегрева у курильщика');
    T.eq(P().limit(), 60);
    run(10);
    T.ok(!document.getElementById('alert').hidden, 'нет табло перегрева');
    T.ok(document.getElementById('alert').textContent.startsWith('ПЕРЕГРЕВ'));
  });

  T.test('вдали от курильщика первые минуты перегрева нет (контроль)', () => {
    quiet(); openWater(); run(600);
    T.ok(!P().hot);
  });

  T.test('перегрев приходит и сам по себе, раз в несколько минут', () => {
    quiet(); openWater(); P().nextHot = 0.1; run(4);
    T.ok(P().hot);
  });

  T.test('лишняя нагрузка греет, урезанная — охлаждает, и перегрев кончается', () => {
    quiet(); openWater(); P().startHot('time');
    const h0 = P().heat; run(100); // 5 с при нагрузке 100
    T.gt(P().heat, h0 + 15, 'реактор не греется от лишней нагрузки');
    cut(); T.eq(P().used(), 60);
    const h1 = P().heat; run(100);
    T.lt(P().heat, h1, 'урезанный реактор не остывает');
    for (let i = 0; i < 100 && P().hot; i++) run(20);
    T.ok(!P().hot, 'перегрев не кончился');
    T.eq(P().limit(), 100);
  });

  T.test('на 100° аварийный сброс обесточивает все системы, потом реактор перезапускается', () => {
    quiet(); openWater(); S().light = true; P().startHot('time'); P().heat = 99;
    run(10);
    T.gt(P().scram, 0, 'нет аварийного сброса');
    P().KEYS.forEach(k => T.eq(P().k(k), 0, k + ' под напряжением'));
    T.ok(!S().light, 'прожектор горит при сбросе');
    G.Game.toggleLight(); T.ok(!S().light, 'прожектор включился при сбросе');
    S().input.thrust = 1; run(40); S().input.thrust = 0;
    T.lt(Math.abs(S().speed), 0.05, 'двигатели тянут при сбросе');
    S().energy = 100; G.Sonar.ping(); T.eq(S().energy, 100, 'сонар работает при сбросе');
    for (let i = 0; i < 300 && P().scram > 0; i++) run(1);
    T.ok(P().scram <= 0, 'реактор не перезапустился');
    T.eq(P().k('eng'), 1);
    T.near(P().heat, 50, 3, 'после перезапуска реактор холодный');
  });

  T.test('панель и экран пульта показывают перегрев', () => {
    quiet(); openWater(); P().startHot('time'); run(6);
    T.ok(document.getElementById('power').classList.contains('hot'));
    T.ok(document.getElementById('pw-free').textContent.startsWith('Перегрев'), 'на панели нет перегрева');
  });
});
