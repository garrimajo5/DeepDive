'use strict';
/* Корабль: отсеки, люки, иллюминаторы, движение, энергия, корпус */
T.describe('Отсеки', () => {
  const S = () => G.Ship;
  T.test('где можно стоять', () => {
    T.ok(S().canStand(0, -3), 'центр мостика');
    T.ok(S().canStand(4.5, 1.5), 'угол мостика');
    T.ok(!S().canStand(5.2, -2), 'за бортом');
    T.ok(!S().canStand(0, -1.2), 'внутри голостола');
    T.ok(!S().canStand(0, -5.6), 'внутри пульта пилота');
    T.ok(S().canStand(0, 5), 'коридор');
    T.ok(!S().canStand(0.9, 5), 'стена коридора');
    T.ok(S().canStand(3, 11), 'лаборатория');
  });
  T.test('закрытый люк не пускает в коридор, открытый пускает', () => {
    T.ok(!S().canStand(0, 2), 'люк закрыт');
    S().doors[0].t = 1;
    T.ok(S().canStand(0, 2), 'люк открыт');
  });
  T.test('отсек по координате', () => {
    T.eq(S().roomAt(-3), 'bridge'); T.eq(S().roomAt(5), 'corr'); T.eq(S().roomAt(11), 'lab');
  });
  T.test('взгляд наружу только через иллюминаторы', () => {
    T.ok(S().throughWindow(T.V(0, 1.65, -3), T.V(0, 0, -1), 'bridge'), 'носовое окно');
    T.ok(!S().throughWindow(T.V(0, 1.65, -3), T.V(-1, 0, 0), 'bridge'), 'глухая стена слева');
    T.ok(!S().throughWindow(T.V(0, 1.65, -3), T.V(0, 1, 0), 'bridge'), 'потолок');
    T.ok(S().throughWindow(T.V(0, 1.65, 11), T.V(0, -1, 0), 'lab'), 'стеклянный пол лаборатории');
    T.ok(!S().throughWindow(T.V(0, 1.65, 11), T.V(0, 0, -1), 'bridge'), 'окна другого отсека не считаются');
  });
});

T.describe('Движение корабля', () => {
  const S = () => G.Ship;
  T.test('вперёд по носу и поворот вправо', () => {
    G.Game.toggleHelm();
    const z0 = S().pos.z, yaw0 = S().yaw;
    G.Ctl.padMove.y = 1; G.Game.debug.frame(120);
    T.lt(S().pos.z, z0 - 8, 'корабль не поплыл вперёд');
    T.gt(S().speed, 2);
    G.Ctl.padMove.y = 0; G.Ctl.padMove.x = 1; G.Game.debug.frame(60);
    T.lt(S().yaw, yaw0 - 0.3, 'не повернул вправо');
  });
  T.test('не проваливается в дно и не всплывает выше льда', () => {
    G.Game.toggleHelm();
    G.Ctl.btnVert = -1; G.Ctl.padMove.y = 1; G.Game.debug.frame(400);
    T.ok(S().pos.y >= S().clearance(S().pos.x, S().pos.z, S().yaw) + 1.15 || S().pos.y >= -5.01, 'ниже дна: ' + S().pos.y);
    T.ok(S().pos.y >= -96.01, 'ниже предельной глубины');
    G.Ctl.btnVert = 1; G.Game.debug.frame(600);
    T.ok(S().pos.y <= -5 + 1e-6, 'выше льда: ' + S().pos.y);
  });
  T.test('без штурвала корабль тормозит', () => {
    S().speed = 5; G.Game.debug.frame(200);
    T.lt(Math.abs(S().speed), 0.6);
  });
});

T.describe('Энергия и корпус', () => {
  const S = () => G.Ship;
  T.test('энергия восстанавливается в покое и тратится прожектором и ходом', () => {
    S().light = false; S().energy = 50; G.Game.debug.frame(100);
    T.near(S().energy, 50 + 5 * 1.1, 0.3, 'восстановление');
    G.Game.toggleHelm(); S().light = true; S().energy = 50; G.Ctl.padMove.y = 1; G.Game.debug.frame(100);
    T.near(S().energy, 50 + 5 * (1.1 - 0.35 - 0.22), 0.4, 'расход на ход и свет');
  });
  T.test('прожектор гаснет без энергии', () => {
    S().light = true; S().energy = 0.3; G.Ship.input.thrust = 0;
    S().update(0.05, 1);
    T.ok(!S().light); T.eq(S().spot.intensity, 0);
  });
  T.test('удар по корпусу и авария при нуле', () => {
    G.Game.hullHit(30, 'bite'); T.eq(S().hull, 70);
    G.Game.hullHit(500, 'bite'); T.eq(S().hull, 0); T.eq(G.Game.state, 'lost');
    document.getElementById('b-restart').click();
    T.eq(G.Game.state, 'play'); T.eq(S().hull, 100);
  });
  T.test('корпус понемногу чинится', () => {
    S().hull = 50; G.Game.debug.frame(200);
    T.near(S().hull, 50 + 10 * 0.15, 0.05);
  });
});
