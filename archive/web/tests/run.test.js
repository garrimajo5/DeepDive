'use strict';
/* Брифинг на голостоле: выбор маршрута, точки на сонаре и приборах */
T.describe('Брифинг и маршрут', () => {
  const D = () => G.Game.debug, S = () => G.Ship, R = () => G.Run, C = () => G.Ctl;
  const atTable = () => { const pl = G.Game.player; pl.x = -2.2; pl.z = -1.2; pl.yaw = -Math.PI / 2; pl.pitch = -0.3; D().frame(1); };
  const press = (x, y) => { C().padMove.x = x; C().padMove.y = y; D().frame(1); C().padMove.x = 0; C().padMove.y = 0; D().frame(1); };
  const quiet = () => { G.Eco.preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); }); G.Eco.eels.forEach(el => { el.cd = 999; }); };

  T.test('три маршрута, каждый — по существующим местам', () => {
    T.eq(R().ROUTES.length, 3);
    R().ROUTES.forEach(r => r.pois.forEach(k => T.ok(G.World.pois.some(p => p.key === k), r.id + ': нет места ' + k)));
    T.eq(R().route, null); T.ok(document.getElementById('s-route').hidden);
  });

  T.test('у голостола открывается брифинг, крестовина выбирает и берёт маршрут', () => {
    atTable();
    T.eq(D().actionLabel(), 'Брифинг: выбрать маршрут');
    C().actionPressed = true; D().frame(1);
    T.ok(R().isOpen() && !document.getElementById('brief').hidden, 'брифинг не открылся');
    press(0, -1); T.eq(R().sel, 1);
    press(1, 0);
    T.eq(R().route && R().route.id, 'vents', 'маршрут не выбран');
    T.ok(!R().isOpen(), 'брифинг не закрылся после выбора');
    D().frame(10);
    T.ok(!document.getElementById('s-route').hidden, 'нет строки маршрута на приборах');
    T.ok(document.getElementById('s-route').textContent.startsWith('Тёплые трубы · 0/2 · Чёрный курильщик'), document.getElementById('s-route').textContent);
    T.eq(D().actionLabel(), 'Брифинг: сменить маршрут');
  });

  T.test('сонар у голостола работает как раньше (контроль)', () => {
    const pl = G.Game.player; pl.x = 0; pl.z = 0.6; pl.yaw = 0; pl.pitch = -0.6; D().frame(1);
    T.eq(D().actionLabel(), 'Сонар: импульс');
  });

  T.test('точки маршрута проходятся по очереди, в конце — «пора решать»', () => {
    quiet(); R().choose('edge');
    const pois = R().route.pois.map(k => G.World.pois.find(p => p.key === k));
    T.eq(R().next(), pois[0]);
    const fly = p => { S().pos.set(p.pos.x + 5, Math.max(G.World.height(p.pos.x + 5, p.pos.z) + 10, -60), p.pos.z); S().speed = S().vy = 0; S().applyTransform(); D().frame(2); };
    fly(pois[1]); T.ok(R().visited.has('drop')); T.eq(R().next(), pois[0], 'следующая точка перескочила');
    T.ok(!R().done);
    fly(pois[0]); T.ok(R().done, 'маршрут не закрыт');
    T.eq(R().next(), null);
    T.ok(R().isVoteOpen(), 'после маршрута нет голосования'); R().closeVote();
    D().frame(10); T.ok(document.getElementById('s-route').textContent.includes('пройден'));
  });

  T.test('кнопки брифинга работают касанием', () => {
    atTable(); C().actionPressed = true; D().frame(1);
    document.querySelector('#brief [data-r="reef"] button').click();
    T.eq(R().route.id, 'reef'); T.ok(!R().isOpen());
  });
});
