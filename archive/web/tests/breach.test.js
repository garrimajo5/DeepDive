'use strict';
/* Событие «пробоина»: сирена, вода на полу, сварка удержанием */
T.describe('Пробоина', () => {
  const D = () => G.Game.debug, S = () => G.Ship, B = () => G.Breach, C = () => G.Ctl;
  const quiet = () => { G.Eco.preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); }); G.Eco.eels.forEach(el => { el.cd = 999; }); };
  /* встать у трещины лицом к ней */
  const atCrack = (sp) => { const pl = G.Game.player; pl.x = sp.at.x; pl.z = sp.at.z; pl.yaw = Math.atan2(sp.n.x, sp.n.z); pl.pitch = -0.2; D().frame(1); };

  T.test('сильный удар пробивает борт, слабый — нет', () => {
    quiet();
    G.Game.hullHit(5, 'scrape');
    T.eq(B().active, null, 'слабый удар пробил борт');
    G.Game.hullHit(12, 'bite');
    T.ok(B().active, 'укус не пробил борт');
    T.eq(B().active.room, 'bridge');
    T.ok(B().crack.visible && B().spray.m.visible, 'трещины и струи не видно');
    D().frame(10);
    T.ok(!document.getElementById('alert').hidden, 'нет тревоги на экране');
    T.ok(document.getElementById('alert').textContent.startsWith('ПРОБОИНА · МОСТИК'));
  });

  T.test('пока трещина открыта, отсек заливает, корпус слабеет', () => {
    quiet(); S().hull = 80;
    B().start(B().SPOTS[0]);
    D().frame(200); // 10 с
    T.near(B().water, 0.16, 0.01, 'вода не прибывает');
    T.ok(B().waterMesh.visible); T.near(B().waterMesh.position.y, B().water, 1e-6);
    T.lt(S().hull, 76, 'корпус не слабеет');
    S().hull = 16; D().frame(200);
    T.near(S().hull, 15, 0.01, 'пробоина сама по себе добила корабль');
    T.eq(G.Game.state, 'play');
  });

  T.test('удержание кнопки у трещины заваривает шов, потом вода уходит', () => {
    quiet();
    const sp = B().SPOTS[0]; B().start(sp); D().frame(100);
    atCrack(sp);
    T.eq(D().actionLabel(), 'Заварить пробоину (держать)');
    C().actionDown = true; D().frame(30); C().actionDown = false; D().frame(1);
    T.ok(B().active, 'шов заварился за 1,5 с');
    T.gt(B().weld, 30);
    C().actionDown = true; for (let i = 0; i < 80 && B().active; i++) D().frame(1); C().actionDown = false;
    T.eq(B().active, null, 'шов не заварен');
    const w = B().water; T.gt(w, 0.05);
    D().frame(100);
    T.lt(B().water, w - 0.08, 'насосы не откачивают воду');
    D().frame(10); T.ok(document.getElementById('alert').hidden, 'тревога не погасла');
  });

  T.test('держать кнопку вдали от трещины бесполезно (контроль)', () => {
    quiet();
    B().start(B().SPOTS[0]);
    const pl = G.Game.player; pl.x = 0; pl.z = 0.5; pl.yaw = 0; D().frame(1);
    C().actionDown = true; D().frame(200); C().actionDown = false;
    T.ok(B().active, 'заварили издалека');
    T.eq(B().weld, 0);
  });

  T.test('в воде по колено идти медленнее', () => {
    quiet();
    const walk = () => { const pl = G.Game.player; pl.x = -3; pl.z = -5; pl.yaw = Math.PI; D().frame(1); const z0 = pl.z; C().padMove.y = 1; D().frame(20); C().padMove.y = 0; return pl.z - z0; }; // открытое место у левого борта, идём к корме
    const dry = walk();
    B().start(B().SPOTS[0]); B().water = 0.4;
    const wet = walk();
    T.lt(wet, dry * 0.7, 'вода не мешает идти');
  });

  T.test('насосы работают от жизнеобеспечения', () => {
    quiet();
    B().start(B().SPOTS[0]); B().water = 0.4; B().end();
    G.Power.set('life', 0); D().frame(100);
    T.near(B().water, 0.4, 1e-6, 'насосы качают без энергии');
    G.Power.set('life', 25); D().frame(100);
    T.lt(B().water, 0.33);
  });

  T.test('после пробоины борт держится немного, следующая — в другом отсеке', () => {
    quiet();
    G.Game.hullHit(12, 'bite'); T.eq(B().active.room, 'bridge'); B().end();
    G.Game.hullHit(12, 'bite'); T.eq(B().active, null, 'новая пробоина сразу после старой');
    B().cd = 0; G.Game.hullHit(12, 'bite');
    T.ok(B().active && B().active.room === 'corr', 'вторая пробоина не в коридоре');
  });

  T.test('сирена и красный свет во время пробоины', () => {
    quiet();
    const L = S().lights[0], c0 = L.l.color.clone();
    B().start(B().SPOTS[0]);
    let red = false; for (let i = 0; i < 30; i++) { D().frame(1); if (L.l.color.r > 0.9 && L.l.color.g < 0.3) red = true; }
    T.ok(red, 'свет не краснеет');
    B().end(); D().frame(2);
    T.near(L.l.color.r, c0.r, 1e-6); T.near(L.l.color.g, c0.g, 1e-6);
  });
});
