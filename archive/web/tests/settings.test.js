'use strict';
/* Настройки: обзор, инверсия, громкость, качество, сохранение */
T.describe('Настройки', () => {
  const St = G.Settings, P = () => G.Game.player;
  const btn = sel => document.querySelector('#settings ' + sel);
  const swipe = (dx, dy) => { G.Ctl.lookDX = dx; G.Ctl.lookDY = dy; G.Game.debug.frame(1); };

  T.test('чувствительность меняет поворот от свайпа', () => {
    const y0 = P().yaw; swipe(100, 0); const d1 = y0 - P().yaw;
    St.set('sens', 2);
    const y1 = P().yaw; swipe(100, 0); const d2 = y1 - P().yaw;
    T.gt(d1, 0); T.near(d2 / d1, 2, 0.01, 'отношение поворотов');
  });
  T.test('инверсия переворачивает вертикальный обзор', () => {
    const p0 = P().pitch; swipe(0, 50); const down = P().pitch - p0;
    T.lt(down, 0, 'без инверсии свайп вниз опускает взгляд');
    St.set('invert', true);
    const p1 = P().pitch; swipe(0, 50);
    T.gt(P().pitch - p1, 0, 'с инверсией свайп вниз поднимает взгляд');
  });
  T.test('кнопки экрана меняют значения в допустимых пределах', () => {
    St.open();
    T.eq(G.Game.state, 'settings');
    for (let i = 0; i < 20; i++) btn('[data-a="sens+"]').click();
    T.eq(St.v.sens, 2); T.ok(btn('[data-a="sens+"]').disabled);
    for (let i = 0; i < 20; i++) btn('[data-a="vol-"]').click();
    T.eq(St.v.volume, 0); T.eq(btn('[data-v="volume"]').textContent, 'выкл');
    T.ok(G.Audio.muted, 'звук не выключился');
    btn('[data-a="vol+"]').click();
    T.near(St.v.volume, 0.1, 1e-9); T.ok(!G.Audio.muted);
    btn('[data-a="invert"]').click(); T.ok(St.v.invert);
    btn('[data-a="close"]').click();
    T.eq(G.Game.state, 'play'); T.ok(document.getElementById('settings').hidden);
  });
  T.test('кнопка «Настройки» на панели открывает экран, Esc закрывает', () => {
    document.getElementById('b-settings').click();
    T.ok(St.isOpen()); T.eq(G.Game.state, 'settings');
    const z = G.Ship.pos.z; G.Ctl.padMove.y = 1; G.Game.debug.frame(5); G.Ctl.padMove.y = 0;
    T.eq(P().z, -3, 'игрок ходит под открытыми настройками');
    G.Ctl.journalPressed = true; G.Game.debug.frame(1);
    T.ok(!St.isOpen()); T.eq(G.Game.state, 'play'); T.eq(G.Ship.pos.z, z);
  });
  T.test('качество графики фиксирует разрешение и выключает столбы света на низком', () => {
    St.set('quality', 'low');
    T.eq(G.Game.debug.pixelRatio, 0.7);
    T.ok(G.World.shafts.every(s => !s.visible));
    St.set('quality', 'mid'); T.eq(G.Game.debug.pixelRatio, 1);
    T.ok(G.World.shafts.every(s => s.visible));
    btn('[data-q="auto"]').click();
    T.eq(St.v.quality, 'auto'); T.ok(btn('[data-q="auto"]').classList.contains('on'));
  });
  T.test('сохраняются на устройстве и переживают сброс журнала', () => {
    St.set('sens', 1.4); St.set('quality', 'high');
    G.Game.resetProgress();
    St.v = St.defaults();
    T.ok(St.load());
    T.eq(St.v.sens, 1.4); T.eq(St.v.quality, 'high');
  });
  T.test('битые данные заменяются значениями по умолчанию', () => {
    localStorage.setItem(St.KEY, '{нет');
    St.load(); T.eq(St.v.sens, 1); T.eq(St.v.quality, 'auto');
    localStorage.setItem(St.KEY, JSON.stringify({ sens: 99, volume: -3, quality: 'ultra', invert: 'да' }));
    St.load();
    T.eq(St.v.sens, 2); T.eq(St.v.volume, 0); T.eq(St.v.quality, 'auto'); T.eq(St.v.invert, false);
  });
  T.test('«По умолчанию» возвращает исходные значения', () => {
    St.set('sens', 0.4); St.set('invert', true); St.set('volume', 0.2);
    St.open(); btn('[data-a="defaults"]').click(); St.close();
    T.eq(St.v.sens, 1); T.eq(St.v.invert, false); T.eq(St.v.volume, 0.7);
  });
});
