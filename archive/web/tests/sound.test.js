'use strict';
/* Звуковой дизайн: песни ледокрыла, гул рифа, тревоги */
T.describe('Звук', () => {
  const D = () => G.Game.debug, S = () => G.Ship, Snd = () => G.Sound, E = () => G.Eco;
  const quiet = () => { E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); }); E().eels.forEach(el => { el.cd = 999; }); };
  const cues = name => Snd().log.filter(c => c.name === name);
  const openWater = () => { S().pos.set(-110, -12, -30); S().pos.y = Math.max(S().pos.y, G.World.height(-110, -30) + 12); S().speed = S().vy = 0; S().applyTransform(); };

  T.test('ледокрыл поёт рядом, песня с направлением и в журнале', () => {
    const ev = T.captureEvents();
    quiet();
    const r = E().rays[0]; D().frame(1);
    S().yaw = 0; S().pos.set(r.p.x + 40, r.p.y - 4, r.p.z); S().speed = S().vy = 0; S().applyTransform(); // скат слева от корабля
    Snd().songCd = 0; D().frame(1);
    const c = cues('song'); T.eq(c.length, 1, 'песни нет');
    T.lt(c[0].a, 60); T.lt(c[0].b, -0.3, 'песня не слева');
    T.ok(ev.some(e => e.sp === 'ray' && e.note === 'song'), 'нет наблюдения «поёт»');
  });

  T.test('далеко от ледокрылов песен не слышно (контроль)', () => {
    quiet();
    const far = () => { S().pos.set(270, -20, 270); S().speed = S().vy = 0; S().applyTransform(); };
    far(); Snd().songCd = 0;
    for (let i = 0; i < 5; i++) { far(); D().frame(1); }
    T.ok(E().rays.every(r => r.p.distanceTo(S().center) > 160), 'скат слишком близко для контроля');
    T.eq(cues('song').length, 0);
  });

  T.test('у кораллов звучит гул рифа, в открытой воде он стихает', () => {
    quiet();
    const c = G.World.coralSpots[0];
    const at = (x, z) => { S().pos.set(x, Math.max(G.World.height(x, z) + 8, -70), z); S().speed = S().vy = 0; S().applyTransform(); };
    for (let i = 0; i < 120; i++) { at(c.x, c.z); D().frame(1); }
    const near = Snd().reef; T.gt(near, 0.4, 'у рифа тихо');
    for (let i = 0; i < 160; i++) { at(-280, -280); D().frame(1); }
    T.lt(Snd().reef, near * 0.3, 'гул не стихает вдали');
  });

  T.test('тревоги: повреждённый корпус, таран, стеклоуст, мало энергии, перегрев', () => {
    quiet(); openWater();
    S().hull = 20; D().frame(2); T.eq(cues('hull').length, 1, 'нет тревоги корпуса');
    D().frame(50); T.eq(cues('hull').length, 2, 'тревога корпуса не повторяется');
    S().hull = 100; S().energy = 10; D().frame(2); T.eq(cues('energy').length, 1);
    S().energy = 100;
    const pr = E().preds[1]; pr.state = 'charge'; pr.timer = 99; pr.cd = 99; pr.p.copy(S().center).add(T.V(15, 0, 0)); D().frame(2);
    T.gt(cues('charge').length, 0, 'нет тревоги тарана');
    pr.state = 'eat'; pr.p.set(250, -20, 250);
    G.Power.startHot('time'); G.Power.heat = 80; D().frame(2);
    T.gt(cues('heat').length, 0, 'нет тревоги перегрева');
  });

  T.test('без беды тревог нет (контроль)', () => {
    quiet(); openWater(); S().hull = 100; S().energy = 100;
    D().frame(100);
    ['hull', 'charge', 'latch', 'energy', 'heat'].forEach(n => T.eq(cues(n).length, 0, n));
  });
});
