'use strict';
/* Машинное отделение: реактор, пульт распределения 100 единиц на 5 систем, влияние на системы */
T.describe('Машинное отделение', () => {
  const D = () => G.Game.debug, S = () => G.Ship, P = () => G.Power, E = () => G.Eco;
  const C = () => G.Ctl;
  const quiet = () => { E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); }); E().eels.forEach(el => { el.cd = 999; }); };
  const atConsole = () => { const pl = G.Game.player; pl.x = 1.6; pl.z = 15.6; pl.yaw = -Math.PI / 2; pl.pitch = -0.1; D().frame(1); };
  const press = (x, y, n) => { C().padMove.x = x; C().padMove.y = y; D().frame(n || 1); C().padMove.x = 0; C().padMove.y = 0; D().frame(1); };

  T.test('реактор даёт 100 единиц, базовые доли — как раньше', () => {
    T.eq(P().used(), 100); T.eq(P().free(), 0);
    P().KEYS.forEach(k => T.eq(P().k(k), 1, k));
    T.eq(P().set('eng', 50), 30, 'взяли больше, чем есть в резерве');
    P().set('lamp', 0); T.eq(P().free(), 10);
    T.eq(P().set('eng', 90), 40, 'резерв ушёл не весь');
    P().set('son', 0); P().set('life', 0);
    T.eq(P().set('eng', 90), P().MAX, 'больше 60 на одну систему');
    T.eq(P().set('zap', 7), 5, 'шаг 5 единиц');
    P().reset(); T.eq(P().used(), 100); T.eq(P().v.eng, 30);
  });

  T.test('люк из лаборатории ведёт в машинное отделение', () => {
    const pl = G.Game.player; pl.x = 0; pl.z = 12.6; pl.yaw = Math.PI; pl.pitch = 0;
    D().frame(1);
    T.eq(D().actionLabel(), 'Открыть люк');
    C().padMove.y = 1; D().frame(40); C().padMove.y = 0;
    T.lt(pl.z, 13.7, 'прошли сквозь закрытый люк');
    C().actionPressed = true; D().frame(30);
    T.gt(S().doors[2].t, 0.85);
    C().padMove.y = 1; D().frame(80); C().padMove.y = 0;
    T.eq(G.Game.room, 'eng'); T.gt(pl.z, 15);
    T.eq(S().roomAt(17), 'eng'); T.eq(S().roomAt(13.9), 'lab');
  });

  T.test('пульт энергии: крестовина выбирает систему и меняет долю, кнопка закрывает', () => {
    atConsole();
    T.eq(D().actionLabel(), 'Распределить энергию');
    C().actionPressed = true; D().frame(1);
    T.ok(P().isOpen(), 'пульт не открылся');
    T.ok(!document.getElementById('power').hidden, 'панели не видно');
    const z0 = G.Game.player.z;
    T.eq(P().sel, 0);
    press(1, 0); T.eq(P().v.eng, 30, 'добавили без резерва');
    press(-1, 0); T.eq(P().v.eng, 25); T.eq(P().free(), 5);
    press(0, -1); T.eq(P().sel, 1, 'вниз — следующая система');
    press(1, 0); T.eq(P().v.son, 25);
    T.eq(P().free(), 0);
    T.near(G.Game.player.z, z0, 1e-6, 'игрок ходил, пока пульт открыт');
    T.ok(document.querySelector('#power [data-k="son"] output').textContent === '25', 'панель не обновилась');
    C().actionPressed = true; D().frame(1);
    T.ok(!P().isOpen(), 'кнопка действия не закрыла пульт');
    T.eq(P().v.son, 25, 'доли сбросились при закрытии');
  });

  T.test('кнопки −/+ на панели работают касанием', () => {
    atConsole(); C().actionPressed = true; D().frame(1);
    document.querySelector('#power [data-k="lamp"] [data-d="-"]').click();
    T.eq(P().v.lamp, 5); T.eq(P().sel, 4);
    document.querySelector('#power [data-k="life"] [data-d="+"]').click();
    T.eq(P().v.life, 30);
    T.ok(document.querySelector('#power [data-k="life"] [data-d="+"]').disabled, 'плюс без резерва активен');
    document.querySelector('#power [data-a="close"]').click();
    T.ok(!P().isOpen());
  });

  T.test('пульт закрывается, если уйти из машинного отделения', () => {
    atConsole(); C().actionPressed = true; D().frame(1); T.ok(P().isOpen());
    G.Game.player.z = 11; D().frame(2);
    T.ok(!P().isOpen());
  });

  const topSpeed = () => {
    S().pos.set(-110, -12, -30); S().pos.y = Math.max(S().pos.y, G.World.height(-110, -30) + 12); S().yaw = 0; S().speed = S().vy = 0; S().applyTransform();
    S().energy = 100; S().input.thrust = 1; S().input.turn = S().input.vert = 0;
    for (let i = 0; i < 300; i++) S().update(0.05, 0);
    S().input.thrust = 0; return S().speed;
  };
  T.test('двигатели: доля меняет тягу, без энергии корабль стоит', () => {
    const base = topSpeed();
    P().set('lamp', 0); P().set('eng', 40); const fast = topSpeed();
    P().set('eng', 0); const none = topSpeed();
    T.gt(fast, base * 1.2, 'больше энергии — не быстрее');
    T.lt(Math.abs(none), 0.01, 'обесточенные двигатели тянут');
  });

  T.test('сонар: доля меняет дальность импульса, без энергии импульса нет', () => {
    quiet(); S().energy = 100;
    G.Sonar.ping(); T.near(G.Sonar.range, 110, 1e-6);
    P().set('lamp', 0); P().set('son', 30); S().energy = 100; G.Sonar.ping(); T.near(G.Sonar.range, 165, 1e-6);
    P().set('son', 0); S().energy = 100; G.Sonar.ping();
    T.eq(S().energy, 100, 'обесточенный сонар потратил энергию');
  });

  T.test('прожектор: доля меняет дальность луча, без энергии свет гаснет', () => {
    quiet(); S().light = true; S().energy = 100;
    S().yaw = 0; S().pitch = S().roll = 0; S().pos.set(0, -20, 60); S().applyTransform();
    const o = T.V(0, 0.8, -6.8), d = T.V(0, -10.8, -33.2).normalize();
    S().group.localToWorld(o); d.applyQuaternion(S().group.quaternion);
    const far = o.clone().addScaledVector(d, 55);
    T.ok(!E().inBeam(far), 'при базовой доле луч достаёт на 55 м');
    P().set('son', 10); P().set('lamp', 20);
    T.ok(E().inBeam(far), 'при двойной доле луч не длиннее');
    P().set('lamp', 0); S().update(0.05, 0);
    T.ok(!S().light, 'обесточенный прожектор горит');
    G.Game.toggleLight(); T.ok(!S().light, 'обесточенный прожектор включился');
  });

  T.test('разряд: доля меняет радиус, без энергии разряда нет', () => {
    quiet(); S().pos.set(0, -20, 60); S().applyTransform();
    const pr = E().preds[1];
    const put = () => { pr.p.copy(S().center).add(T.V(28, 0, 0)); pr.state = 'patrol'; pr.timer = 999; };
    put(); S().energy = 100; G.Game.zap(); T.eq(pr.state, 'patrol', 'базовый разряд достал на 28 м');
    P().set('lamp', 0); P().set('zap', 25); put(); S().energy = 100; G.Game.zap(); T.eq(pr.state, 'flee', 'сильный разряд не отпугнул');
    P().set('zap', 0); put(); S().energy = 100; G.Game.zap();
    T.eq(S().energy, 100, 'обесточенный разряд сработал'); T.eq(pr.state, 'patrol');
  });

  T.test('жизнеобеспечение: доля меняет ремонт корпуса', () => {
    const fix = () => { S().hull = 50; for (let i = 0; i < 200; i++) S().update(0.05, 0); return S().hull - 50; };
    S().pos.set(-110, -12, -30); S().pos.y = Math.max(S().pos.y, G.World.height(-110, -30) + 12); S().applyTransform();
    const base = fix();
    P().set('lamp', 0); P().set('zap', 0); P().set('life', 50); const more = fix();
    P().set('life', 0); const none = fix();
    T.near(more, base * 2, 0.01); T.eq(none, 0);
  });
});
