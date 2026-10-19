'use strict';
/* Событие «сонарная тьма»: облако ила глушит сонар, мутит воду, рассеивает луч и прячет корабль */
T.describe('Сонарная тьма', () => {
  const E = () => G.Eco, S = () => G.Ship, Si = () => G.Silt, So = () => G.Sonar;
  const eco = (n) => { for (let i = 0; i < n; i++) { G.Game.t += 0.05; E().update(0.05, G.Game.t); } };
  const quiet = () => { E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); }); E().eels.forEach(el => { el.cd = 999; }); E().lastPing = -99; };
  const openWater = () => { S().pos.set(-110, -12, -30); S().pos.y = Math.max(S().pos.y, G.World.height(-110, -30) + 12); S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0; S().applyTransform(); };
  const mud = () => Si().spawn(S().center.clone(), 16, 45, 'scrape');

  T.test('удар о дно поднимает облако ила вокруг корабля', () => {
    quiet(); openWater();
    G.Game.hullHit(6, 'scrape');
    T.eq(Si().clouds.length, 1, 'ила нет');
    eco(20);
    T.ok(Si().inside, 'корабль не в облаке');
    T.gt(Si().k, 0.5);
    G.Game.hullHit(6, 'scrape'); T.eq(Si().clouds.length, 1, 'вторая туча на том же месте');
    G.Game.hullHit(12, 'bite'); T.eq(Si().clouds.length, 1, 'укус поднял ил');
  });

  T.test('в иле импульс сонара глохнет', () => {
    quiet(); openWater(); mud(); eco(20);
    S().energy = 100; So().ping();
    T.eq(So().blips.length, 0, 'сонар что-то увидел в иле');
    T.eq(S().energy, 94, 'импульс не потратил энергию');
  });

  T.test('вне ила сонар видит существ (контроль)', () => {
    quiet(); S().pos.set(0, -20, 60); S().applyTransform(); eco(2);
    T.ok(!Si().inside);
    S().energy = 100; So().ping();
    T.gt(So().blips.length, 3, 'сонар ничего не видит');
  });

  T.test('в иле вода мутнеет и луч рассеивается', () => {
    quiet(); openWater(); S().light = true;
    const o = T.V(0, 0.8, -6.8), d = T.V(0, -10.8, -33.2).normalize();
    S().group.localToWorld(o); d.applyQuaternion(S().group.quaternion);
    const p30 = o.clone().addScaledVector(d, 30);
    T.ok(E().inBeam(p30), 'луч не достаёт на 30 м');
    mud(); eco(20);
    T.ok(!E().inBeam(p30), 'в иле луч бьёт так же далеко');
    T.ok(E().inBeam(o.clone().addScaledVector(d, 12)), 'вблизи луч пропал совсем');
  });

  T.test('в иле серпохвост не видит свет корабля', () => {
    quiet(); openWater(); S().light = true;
    const pr = E().preds[1]; T.ok(!pr.leech);
    const hunt = () => { pr.state = 'patrol'; pr.timer = 999; pr.cd = 0; pr.hunger = 0.3; pr.leechCd = 999; pr.p.copy(S().center).add(T.V(22, 0, 0)); pr.goal.copy(pr.p); };
    mud(); eco(20); T.ok(Si().inside);
    hunt(); eco(3);
    T.eq(pr.state, 'patrol', 'хищник увидел свет в иле');
    Si().reset(); eco(2); hunt(); eco(3);
    T.eq(pr.state, 'charge', 'без ила хищник не заметил свет (контроль)');
  });

  T.test('ил дрейфует по течению и оседает', () => {
    quiet(); openWater();
    const cl = mud(), c0 = cl.c.clone();
    eco(400); // 20 с
    const dv = cl.c.clone().sub(c0).setY(0);
    T.gt(dv.length(), 5, 'облако не дрейфует');
    T.gt(dv.normalize().dot(E().current.clone().normalize()), 0.95, 'облако идёт не по течению');
    eco(600);
    T.eq(Si().clouds.length, 0, 'облако не осело');
  });

  T.test('у Края отмели время от времени сходит оползень', () => {
    quiet(); S().pos.set(0, -20, 60); S().applyTransform();
    Si().slideT = 0.05; eco(2);
    const d = G.World.pois.find(p => p.key === 'drop');
    T.eq(Si().clouds.length, 1);
    T.lt(Math.hypot(Si().clouds[0].c.x - d.pos.x, Si().clouds[0].c.z - d.pos.z), 5, 'оползень не у Края отмели');
    T.eq(Si().clouds[0].why, 'slide');
  });

  T.test('табло показывает сонарную тьму', () => {
    quiet(); openWater(); mud(); eco(20);
    const el = document.getElementById('alert');
    T.ok(!el.hidden && el.textContent.startsWith('СОНАРНАЯ ТЬМА'), 'нет табло');
    Si().reset(); eco(20);
    T.ok(el.hidden, 'табло не погасло');
  });
});
