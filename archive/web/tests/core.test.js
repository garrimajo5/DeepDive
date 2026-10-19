'use strict';
/* Утилиты и мир */
T.describe('Утилиты', () => {
  T.test('шум в диапазоне 0..1 и детерминирован', () => {
    for (let i = 0; i < 400; i++) {
      const x = i * 1.37 - 300, z = i * 0.71 + 11, n = G.noise(x, z);
      T.ok(n >= 0 && n <= 1, 'noise вне диапазона: ' + n);
      T.eq(G.noise(x, z), n, 'noise не детерминирован');
      const f = G.fbm(x * 0.01, z * 0.01, 4);
      T.ok(f >= 0 && f <= 1, 'fbm вне диапазона: ' + f);
    }
  });
  T.test('clamp, lerp, smooth', () => {
    T.eq(G.clamp(5, 0, 1), 1); T.eq(G.clamp(-5, 0, 1), 0); T.eq(G.lerp(2, 4, 0.5), 3);
    T.eq(G.smooth(0, 1, -1), 0); T.eq(G.smooth(0, 1, 2), 1); T.near(G.smooth(0, 1, 0.5), 0.5, 1e-9);
  });
  T.test('merge складывает вершины и красит части', () => {
    const a = new THREE.BoxGeometry(1, 1, 1), b = new THREE.SphereGeometry(1, 4, 3);
    const na = a.toNonIndexed().attributes.position.count, nb = b.toNonIndexed().attributes.position.count;
    const m = G.merge([{ g: a }, { g: b, c: new THREE.Color(1, 0, 0) }]);
    T.eq(m.attributes.position.count, na + nb);
    T.eq(m.attributes.normal.count, na + nb);
    T.eq(m.attributes.color.getX(0), 1); T.eq(m.attributes.color.getY(na), 0); T.eq(m.attributes.color.getX(na), 1);
  });
});

T.describe('Мир', () => {
  T.test('дно всегда ниже льда и выше бездны', () => {
    for (let x = -340; x <= 340; x += 17) for (let z = -340; z <= 340; z += 17) {
      const h = G.World.height(x, z);
      T.ok(h <= -7 && h > -250, `высота ${h} в (${x}, ${z})`);
    }
  });
  T.test('шесть мест для открытий с уникальными ключами', () => {
    const keys = G.World.pois.map(p => p.key);
    T.eq(keys.length, 6); T.eq(new Set(keys).size, 6);
    G.World.pois.forEach(p => { T.ok(p.name && p.desc, 'нет текста у ' + p.key); T.gt(p.rd, 20); });
  });
  T.test('пятна мха, логова и кораллы на месте', () => {
    T.gt(G.World.patches.length, 14, 'мало пятен мха');
    G.World.patches.forEach(p => T.ok(p.food >= 0 && p.food <= 1));
    T.eq(G.World.lairs.length, 3);
    T.gt(G.World.coralSpots.length, 20);
  });
  T.test('съеденный мох отрастает', () => {
    const p = G.World.patches[0]; p.food = 0.2;
    for (let i = 0; i < 200; i++) G.World.update(0.05, 100 + i * 0.05);
    T.near(p.food, 0.2 + 10 * 0.012, 0.01);
    T.near(p.alpha, 0.15 + 0.85 * p.food, 0.003);
    const a = G.World.moss.geometry.attributes.color.array, k = p.base.findIndex(b => b > 0.2);
    T.near(a[(p.v0 + k) * 4 + 3], p.base[k] * p.alpha, 1e-5, 'яркость пятна в общем меше');
  });
});
