'use strict';
/* Обучение */
T.describe('Обучение', () => {
  const D = () => G.Game.debug, Tu = () => G.Tutorial;
  const text = () => document.querySelector('#tut span').textContent;
  T.test('пять шагов засчитываются по действиям игрока', () => {
    Tu().restart(); D().frame(1);
    T.ok(!document.getElementById('tut').hidden, 'подсказка не видна');
    T.ok(text().includes('штурвал'));
    const P = G.Game.player; P.x = 0; P.z = -3.4; P.yaw = 0; P.pitch = -0.4; D().frame(1);
    G.Ctl.actionPressed = true; D().frame(2);
    T.eq(Tu().i, 1, 'шаг «штурвал»'); T.ok(text().includes('20 метров'));
    G.Ctl.padMove.y = 1; D().frame(200); G.Ctl.padMove.y = 0;
    T.eq(Tu().i, 2, 'шаг «проплыть»');
    G.Ctl.pingPressed = true; D().frame(2);
    T.eq(Tu().i, 3, 'шаг «сонар»');
    G.SPECIES.ray.scanned = true; D().frame(1);
    T.eq(Tu().i, 4, 'шаг «скан»');
    G.Ctl.standPressed = true; D().frame(1);
    G.Ship.doors.forEach(d => { d.open = true; d.t = 1; });
    P.x = 0; P.z = 11; D().frame(1);
    T.ok(Tu().done, 'обучение не завершено');
    T.ok(document.getElementById('tut').hidden);
  });
  T.test('шаг не засчитывается раньше времени', () => {
    Tu().restart(); D().frame(5);
    T.eq(Tu().i, 0);
    G.Game.toggleHelm(); D().frame(1); T.eq(Tu().i, 1);
    D().frame(5); T.eq(Tu().i, 1, 'засчитано без движения');
  });
  T.test('кнопка «Пропустить» скрывает обучение', () => {
    Tu().restart(); D().frame(1);
    document.querySelector('#tut button').click();
    T.ok(Tu().done); T.ok(document.getElementById('tut').hidden);
  });
  T.test('прогресс обучения сохраняется', () => {
    Tu().restart(); D().frame(1); G.Game.toggleHelm(); D().frame(1);
    G.Save.save(); Tu().restart();
    T.ok(G.Save.load()); T.eq(Tu().i, 1); T.ok(!Tu().done);
  });
  T.test('сброс прогресса запускает обучение заново', () => {
    T.ok(Tu().done);
    G.Game.resetProgress();
    T.ok(!Tu().done); T.eq(Tu().i, 0);
  });
});
