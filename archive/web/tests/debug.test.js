'use strict';
/* Отладочная панель */
T.describe('Отладочная панель', () => {
  T.test('телепорт ставит корабль у места и место открывается', () => {
    const p = G.World.pois.find(x => x.key === 'bones');
    T.ok(G.Game.debug.teleport('bones'));
    T.lt(Math.hypot(G.Ship.pos.x - p.pos.x, G.Ship.pos.z - p.pos.z), p.rd, 'далеко от места');
    T.ok(G.Ship.pos.y <= -6 && G.Ship.pos.y >= -90);
    G.Game.debug.frame(1);
    T.ok(p.found, 'место не открылось');
    T.ok(!G.Game.debug.teleport('нет-такого'));
  });
  T.test('включается и показывает статистику', () => {
    G.DebugPanel.set(true);
    const el = document.getElementById('dbg');
    T.ok(el && !el.hidden, 'панель не видна');
    T.eq(el.querySelectorAll('#dbg-tp button').length, G.World.pois.length + G.Eco.stations.length + 7);
    G.DebugPanel.tick(0.6);
    T.ok(/FPS \d+/.test(el.querySelector('#dbg-text').textContent));
    const s = G.DebugPanel.stats();
    T.ok(s.fish.includes('/') && typeof s.calls === 'number');
    G.DebugPanel.set(false); T.ok(el.hidden);
  });
  T.test('тройное касание по приборам переключает панель', () => {
    G.DebugPanel.set(false);
    const st = document.getElementById('stats');
    for (let i = 0; i < 3; i++) st.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));
    T.ok(G.DebugPanel.on);
    G.DebugPanel.set(false);
  });
  T.test('кнопки панели пополняют энергию и корпус', () => {
    G.DebugPanel.set(true); G.Ship.energy = 10; G.Ship.hull = 10;
    document.querySelector('#dbg [data-a="energy"]').click();
    document.querySelector('#dbg [data-a="hull"]').click();
    T.eq(G.Ship.energy, 100); T.eq(G.Ship.hull, 100);
    G.DebugPanel.set(false);
  });
});
