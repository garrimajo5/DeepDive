'use strict';
/* Бюджет производительности и слияние статики */
T.describe('Производительность', () => {
  const D = () => G.Game.debug;
  const LIMIT_CALLS = 260, LIMIT_TRIS = 350000;
  function check(where) {
    const r = D().render();
    T.lt(r.calls, LIMIT_CALLS, where + ': вызовов отрисовки');
    T.lt(r.tris, LIMIT_TRIS, where + ': треугольников');
    return r;
  }
  T.test('бюджет на мостике, за штурвалом и в лаборатории', () => {
    check('мостик');
    G.Game.toggleHelm(); check('штурвал'); G.Game.toggleHelm();
    const P = G.Game.player; P.x = 0; P.z = 11; P.pitch = -1.2; check('лаборатория, взгляд в пол');
  });
  T.test('бюджет у каждого места и в четырёх направлениях', () => {
    G.World.pois.forEach(p => {
      D().teleport(p.key);
      [0, 1.57, 3.14, 4.71].forEach(y => { G.Game.player.yaw = y; check(p.key + ' ' + y); });
    });
  });
  T.test('статика корабля слита, подвижные детали остались отдельными', () => {
    T.gt(G.Ship.merged, 40, 'слито мало мешей');
    G.Ship.doors.forEach(d => T.ok(d.mesh.parent === G.Ship.group, 'люк потерялся'));
    G.Ship.doors[0].open = true; G.Game.debug.frame(30);
    T.gt(G.Ship.doors[0].mesh.position.x, 1.5, 'люк не двигается');
    G.Game.toggleHelm(); G.Ctl.padMove.x = 1; G.Game.debug.frame(20);
    T.ok(Math.abs(G.Ship.wheel.rotation.z) > 0.2, 'штурвал не крутится');
  });
});
