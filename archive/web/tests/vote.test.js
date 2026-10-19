'use strict';
/* Возврат и голосование «глубже или наверх», итоги забега */
T.describe('Голосование и итоги', () => {
  const D = () => G.Game.debug, S = () => G.Ship, R = () => G.Run, C = () => G.Ctl;
  const quiet = () => { G.Eco.preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); }); G.Eco.eels.forEach(el => { el.cd = 999; }); };
  const finishRoute = (id) => {
    R().choose(id);
    R().route.pois.forEach(k => { const p = G.World.pois.find(x => x.key === k); S().pos.set(p.pos.x + 5, Math.max(G.World.height(p.pos.x + 5, p.pos.z) + 10, -60), p.pos.z); S().speed = S().vy = 0; S().applyTransform(); D().frame(2); });
  };
  const press = (x) => { C().padMove.x = x; D().frame(1); C().padMove.x = 0; D().frame(1); };

  T.test('пройденный маршрут собирает экипаж на голосование, мир ждёт', () => {
    quiet(); finishRoute('vents');
    T.ok(R().done); T.ok(R().isVoteOpen(), 'голосование не открылось');
    T.eq(G.Game.state, 'vote'); T.ok(!document.getElementById('vote').hidden);
    T.eq(document.querySelectorAll('#vote .vt-op').length, 4, 'нет мнений экипажа');
    const p0 = S().pos.clone(); S().speed = 3; D().frame(20);
    T.lt(S().pos.distanceTo(p0), 0.01, 'корабль движется во время голосования');
  });

  T.test('мнения экипажа зависят от состояния корабля', () => {
    S().hull = 30; S().energy = 90; S().cargo.length = 0;
    const o = R().opinions();
    T.ok(o.find(x => x.who === 'Пилот').up, 'пилот не просится наверх с корпусом 30%');
    T.ok(!o.find(x => x.who === 'Инженер').up);
    T.ok(!o.find(x => x.who === 'Биолог').up);
    ['moss', 'moss', 'shell', 'coral'].forEach(k => S().cargo.push({ kind: k }));
    T.ok(R().opinions().find(x => x.who === 'Биолог').up, 'биолог не хочет довезти образцы');
  });

  T.test('«глубже»: новый спуск, хищники злее, новый маршрут', () => {
    quiet(); finishRoute('vents');
    T.ok(R().isVoteOpen());
    D().frame(2); press(1); // вправо — глубже
    T.eq(R().depth, 1); T.ok(!R().isVoteOpen()); T.eq(G.Game.state, 'play');
    T.eq(R().route, null, 'старый маршрут не сброшен');
    T.near(R().predK(), 1.15, 1e-6);
    const pr = G.Eco.preds[1]; S().light = true; G.Eco.lastPing = -99;
    S().pos.set(-110, -12, -30); S().pos.y = Math.max(S().pos.y, G.World.height(-110, -30) + 12); S().speed = 0; S().applyTransform();
    pr.state = 'patrol'; pr.timer = 999; pr.cd = 0; pr.hunger = 0.3; pr.leechCd = 999; pr.p.copy(S().center).add(T.V(34, 0, 0)); pr.goal.copy(pr.p);
    for (let i = 0; i < 3; i++) { G.Game.t += 0.05; G.Eco.update(0.05, G.Game.t); }
    T.eq(pr.state, 'charge', 'глубже хищник не видит свет за 34 м');
  });

  T.test('«наверх»: итоги забега и новое погружение', () => {
    quiet();
    S().cargo.push({ kind: 'moss' }); R().note('samples');
    finishRoute('edge');
    D().frame(2); press(-1); // влево — наверх
    T.eq(G.Game.state, 'results'); T.ok(!document.getElementById('results').hidden, 'нет итогов');
    const txt = document.getElementById('results').textContent;
    T.ok(txt.includes('Маршрутов пройдено') && txt.includes('Образцов поднято'), 'в итогах нет счёта');
    T.gt(R().score, 0);
    document.getElementById('b-newrun').click();
    T.eq(G.Game.state, 'play'); T.ok(document.getElementById('results').hidden);
    T.eq(R().route, null); T.eq(R().depth, 0); T.eq(S().cargo.length, 0); T.eq(S().hull, 100);
  });

  T.test('у голостола после маршрута — голосование', () => {
    quiet(); finishRoute('vents'); D().frame(2); press(1); // глубже
    R().choose('vents'); R().done = true;
    const pl = G.Game.player; pl.x = -2.2; pl.z = -1.2; pl.yaw = -Math.PI / 2; pl.pitch = -0.3; D().frame(1);
    T.eq(D().actionLabel(), 'Голосование: глубже или наверх');
    C().actionPressed = true; D().frame(1);
    T.ok(R().isVoteOpen());
  });
});
