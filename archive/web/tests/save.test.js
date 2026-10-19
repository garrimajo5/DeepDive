'use strict';
/* Сохранение журнала */
T.describe('Сохранение', () => {
  const stored = () => { const r = localStorage.getItem(G.Save.KEY); return r ? JSON.parse(r) : null; };
  T.test('снимок и восстановление журнала', () => {
    G.SPECIES.ray.scanned = true; G.SPECIES.eel.seen.add('latch');
    G.World.pois.find(p => p.key === 'well').found = true;
    const snap = G.Save.snapshot();
    G.Game.resetProgress();
    T.ok(!G.SPECIES.ray.scanned);
    T.ok(G.Save.apply(snap));
    T.ok(G.SPECIES.ray.scanned); T.ok(G.SPECIES.eel.seen.has('latch'));
    T.ok(G.World.pois.find(p => p.key === 'well').found);
  });
  T.test('наблюдение сохраняется само примерно через секунду', () => {
    G.Eco.emit('grazer', 'graze', G.Ship.center, () => 'мох');
    G.Game.debug.frame(1);
    T.eq(stored(), null, 'сохранилось слишком рано');
    G.Game.debug.frame(25);
    const s = stored();
    T.ok(s && s.species.grazer.seen.includes('graze'), 'нет в хранилище');
  });
  T.test('открытие места и метка сонара сохраняются', () => {
    G.Game.debug.teleport('shell'); G.Game.debug.frame(1);
    G.Ship.energy = 100; G.Sonar.ping();
    G.Game.debug.frame(25);
    const s = stored();
    T.ok(s.pois.some(p => p.key === 'shell' && p.found));
    T.ok(s.pois.some(p => p.pinged));
  });
  T.test('загрузка после перезапуска', () => {
    G.SPECIES.fish.scanned = true; G.Save.save();
    G.SPECIES.fish.scanned = false;
    T.ok(G.Save.load()); T.ok(G.SPECIES.fish.scanned);
  });
  T.test('битые и чужие данные не ломают игру', () => {
    localStorage.setItem(G.Save.KEY, '{не json');
    T.eq(G.Save.load(), false);
    localStorage.setItem(G.Save.KEY, JSON.stringify({ v: 99 }));
    T.eq(G.Save.load(), false);
    localStorage.setItem(G.Save.KEY, JSON.stringify({ v: 1, species: { pred: { scanned: true, seen: ['catch', 'нет-такого'] }, dragon: {} }, pois: [{ key: 'нет' }] }));
    T.ok(G.Save.load());
    T.ok(G.SPECIES.pred.scanned); T.eq(G.SPECIES.pred.seen.size, 1);
  });
  T.test('сброс прогресса из журнала в два нажатия', () => {
    G.SPECIES.veil.scanned = true; G.Save.save();
    G.Game.openJournal();
    const b = document.getElementById('j-reset');
    b.click();
    T.ok(G.SPECIES.veil.scanned, 'стёрлось с первого нажатия');
    document.getElementById('j-reset').click();
    T.ok(!G.SPECIES.veil.scanned); T.eq(stored(), null);
    T.eq(document.getElementById('j-count').textContent, '0/26 · 0/6');
  });
});
