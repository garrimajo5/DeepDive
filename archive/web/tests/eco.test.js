'use strict';
/* Экосистема: виды, связи между ними, реакции на корабль */
T.describe('Виды', () => {
  T.test('у каждого вида полное описание', () => {
    T.eq(G.SPECIES_ORDER.length, 26);
    G.SPECIES_ORDER.forEach(k => {
      const s = G.SPECIES[k];
      ['name', 'acc', 'unom', 'uacc', 'desc'].forEach(f => T.ok(typeof s[f] === 'string' && s[f].length > 1, `${k}.${f}`));
      T.gt(Object.keys(s.notes).length, 0, k + ': нет наблюдений');
    });
  });
  T.test('до сканирования вид называется описательно', () => {
    T.eq(G.nm('pred'), 'крупный хищник'); T.eq(G.nm('pred', 'acc'), 'крупного хищника');
    G.SPECIES.pred.scanned = true;
    T.eq(G.nm('pred'), 'серпохвост'); T.eq(G.nm('pred', 'acc'), 'серпохвоста');
  });
  T.test('все события экосистемы ссылаются на существующие наблюдения', () => {
    const ev = T.captureEvents();
    G.Game.debug.step(2400);
    T.gt(new Set(ev.map(e => e.sp + ':' + e.note)).size, 2, 'за 2 минуты почти ничего не произошло');
    ev.forEach(e => T.ok(G.SPECIES[e.sp] && G.SPECIES[e.sp].notes[e.note], 'неизвестное наблюдение ' + e.sp + ':' + e.note));
  });
  T.test('сканируемые цели есть у всех видов', () => {
    const sp = new Set(G.Eco.scanTargets().map(t => t.sp));
    G.SPECIES_ORDER.forEach(k => T.ok(sp.has(k), 'нет цели для ' + k));
  });
});

T.describe('Связи', () => {
  const E = () => G.Eco;
  T.test('голодный серпохвост ловит светляка', () => {
    const ev = T.captureEvents();
    const pr = E().preds[0], f = E().fish.find(x => x.alive);
    pr.p.copy(f.p).add(T.V(4, 0, 0)); pr.hunger = 1; pr.state = 'patrol'; pr.timer = 5; pr.cd = 999;
    G.Game.debug.step(240);
    T.ok(ev.some(e => e.sp === 'pred' && e.note === 'catch'), 'нет поимки');
  });
  T.test('сброс мира возвращает хищников, рыб и ледокрылов на исходные места', () => {
    const D = G.Game.debug;
    const snap = () => JSON.stringify([E().fish.map(f => [f.alive, f.p.x.toFixed(3), f.p.z.toFixed(3)]), E().rays.map(r => r.ang.toFixed(4)), E().preds.map(p => p.p.toArray().map(v => v.toFixed(3)))]);
    const a = snap();
    E().fish[3].alive = false; D.step(200); D.reset();
    T.ok(snap() === a, 'после сброса мир другой — тесты зависят от предыдущих');
  });
  T.test('погибшая рыба возвращается в стаю', () => {
    const f = E().fish[0]; f.alive = false; f.t = 1;
    G.Game.debug.step(30);
    T.ok(f.alive); T.lt(f.p.distanceTo(f.s.home), 6);
  });
  T.test('скребун объедает мох', () => {
    const gz = E().grazers[0], pt = gz.patch;
    pt.food = 1; gz.p.set(pt.x, 0, pt.z); gz.state = 'walk';
    G.Game.debug.step(100);
    T.eq(gz.state, 'graze'); T.lt(pt.food, 0.95);
  });
  T.test('стеклоуст присасывается к кораблю, разряд его сбрасывает', () => {
    const ev = T.captureEvents();
    const S = G.Ship, L = G.World.lairs[0];
    S.pos.set(L.mouth.x, L.mouth.y + 4, L.mouth.z + 16); S.yaw = 0;
    E().eels.forEach(e => { e.cd = 999; }); E().eels[0].cd = 0;
    G.Game.debug.step(300);
    T.ok(E().latched, 'не присосался');
    const e0 = S.energy; G.Game.debug.step(40);
    T.lt(S.energy, e0 - 2, 'энергия не утекает');
    S.energy = 60; G.Game.zap();
    T.eq(E().latched, null); T.eq(S.energy, 45);
    T.ok(ev.some(e => e.note === 'latch') && ev.some(e => e.sp === 'eel' && e.note === 'zap'));
  });
  T.test('разряда без энергии не будет', () => {
    G.Ship.energy = 10; G.Game.zap(); T.eq(G.Ship.energy, 10);
  });
  T.test('серпохвост таранит корабль со светом', () => {
    const S = G.Ship, pr = E().preds[0];
    S.light = true; pr.p.copy(S.center).add(T.V(0, 0, -20)); pr.hunger = 0.9; pr.cd = 0; pr.state = 'patrol';
    G.Game.debug.step(120);
    T.lt(S.hull, 100, 'удара не было'); T.ok(pr.state === 'retreat' || pr.state === 'patrol');
  });
  T.test('без света и сонара серпохвост корабль не трогает', () => {
    const S = G.Ship, pr = E().preds[0];
    S.light = false; E().lastPing = -999; pr.p.copy(S.center).add(T.V(0, 0, -20)); pr.hunger = 0.9; pr.cd = 0; pr.state = 'eat'; pr.timer = 99;
    G.Game.debug.step(60);
    T.eq(S.hull, 100);
  });
  T.test('под вуалью хищник теряет корабль', () => {
    const ev = T.captureEvents();
    const S = G.Ship, vl = E().veils[0], pr = E().preds[1];
    S.pos.copy(vl.p).add(T.V(0, -10, -4)); S.yaw = 0; S.update(0.01, 0);
    G.Eco.update(0.01, 0);
    T.ok(E().shipHidden, 'корабль не спрятан');
    pr.state = 'charge'; pr.timer = 10; pr.p.copy(S.center).add(T.V(30, 0, 0));
    G.Game.debug.step(4);
    T.eq(pr.state, 'retreat');
    T.ok(ev.some(e => e.sp === 'veil' && e.note === 'hide'));
  });
});

T.describe('Сонар', () => {
  T.test('импульс тратит энергию, показывает существ и места, будит хищников', () => {
    const S = G.Ship; S.energy = 100;
    G.Eco.preds[0].p.copy(S.center).add(T.V(40, 0, 0)); G.Eco.preds[0].state = 'patrol';
    G.Sonar.ping();
    T.eq(S.energy, 94);
    T.gt(G.Sonar.blips.length, 0);
    T.eq(G.Eco.preds[0].state, 'investigate');
    T.ok(G.World.pois.some(p => p.pinged), 'ни одно место не отмечено');
  });
  T.test('без энергии импульса нет', () => {
    G.Ship.energy = 3; G.Sonar.ping(); T.eq(G.Ship.energy, 3);
  });
});
