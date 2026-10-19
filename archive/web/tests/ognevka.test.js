'use strict';
/* Огнёвки, станции чистки на огнецвете и пиявники на серпохвостах */
T.describe('Станции чистки', () => {
  const E = () => G.Eco, S = () => G.Ship, D = () => G.Game.debug;
  const quiet = () => E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });
  /* поставить корабль у станции, чтобы её центр был в шелтере */
  const parkAt = (st, off) => {
    S().pos.copy(st.top).add(off || T.V(0, 3, 0)); S().yaw = 0; S().speed = S().vy = 0;
    S().applyTransform(); S().update(0.01, 0); E().update(0.01, 0);
  };

  T.test('станции стоят на огнецвете в рифе', () => {
    T.gt(E().stations.length, 1, 'мало станций');
    E().stations.forEach(st => {
      T.near(st.base.y, G.World.height(st.base.x, st.base.z), 0.01, 'огнецвет не на дне');
      T.gt(st.top.y, st.base.y + 2); T.lt(st.top.y, -2, 'вершина выше льда');
    });
    T.eq(E().shrimp.length, E().stations.length * 10);
  });

  T.test('серпохвост бросает охоту, если добыча у станции', () => {
    const ev = T.captureEvents();
    quiet();
    const st = E().stations[0], pr = E().preds[1], f = E().fish.find(x => x.alive);
    f.p.copy(st.top); f.s.home.copy(st.top); f.s.goal.copy(st.top);
    pr.p.copy(st.top).add(T.V(9, 0, 0)); pr.state = 'hunt'; pr.target = f; pr.timer = 12; pr.hunger = 1; pr.cd = 999;
    D().step(1);
    T.ok(pr.state !== 'hunt', 'всё ещё охотится');
    D().step(60);
    T.ok(f.alive, 'рыбу съели у станции');
    T.ok(pr.target !== f, 'снова гонится за той же рыбой');
    T.ok(ev.some(e => e.sp === 'ognevka' && e.note === 'truce'), 'нет наблюдения «перемирие»');
  });

  T.test('голодный серпохвост у станции не выбирает добычу рядом с ней', () => {
    quiet();
    const st = E().stations[0], pr = E().preds[1];
    setLeechOff(pr);
    pr.p.copy(st.top).add(T.V(4, 0, 0)); pr.state = 'patrol'; pr.timer = 99; pr.goal.copy(pr.p); pr.hunger = 1; pr.cd = 999;
    D().step(1);
    T.eq(pr.state, 'patrol');
  });

  T.test('у станции корабль может переждать: таран отменяется', () => {
    const ev = T.captureEvents();
    quiet();
    const st = E().stations[0], pr = E().preds[1];
    S().light = true; parkAt(st);
    T.ok(E().shipSheltered === st, 'корабль не под защитой станции');
    T.ok(!E().shipHidden, 'мешает вуаль');
    pr.p.copy(S().center).add(T.V(25, 0, 0)); pr.state = 'charge'; pr.timer = 10; pr.hunger = 1; pr.cd = 0;
    D().step(80);
    T.eq(S().hull, 100, 'хищник всё равно ударил');
    T.ok(ev.some(e => e.sp === 'ognevka' && e.note === 'shelter'));
  });

  T.test('вдали от станции тот же хищник таранит корабль (контроль)', () => {
    quiet();
    const pr = E().preds[1]; setLeechOff(pr);
    S().light = true; S().update(0.01, 0); E().update(0.01, 0);
    T.eq(E().shipSheltered, null);
    pr.p.copy(S().center).add(T.V(25, 0, 0)); pr.state = 'charge'; pr.timer = 10; pr.hunger = 1; pr.cd = 0;
    D().step(80);
    T.lt(S().hull, 100);
  });

  function setLeechOff(pr) { pr.leech = false; pr.leechM.visible = false; pr.station = null; pr.leechCd = 999; }
});

T.describe('Пиявник', () => {
  const E = () => G.Eco, S = () => G.Ship, D = () => G.Game.debug;

  T.test('в начале один серпохвост заражён, пиявника можно сканировать', () => {
    T.eq(E().preds.filter(p => p.leech).length, 1);
    T.ok(E().preds[0].leechM.visible, 'паразита не видно');
    D().step(1);
    const tg = E().scanTargets().find(t => t.sp === 'leech');
    T.ok(tg, 'нет цели сканирования');
    T.lt(tg.pos.distanceTo(E().preds[0].p), 2, 'цель не на хищнике');
  });

  T.test('пиявник присасывается к здоровому хищнику', () => {
    const ev = T.captureEvents();
    const pr = E().preds[1];
    pr.p.set(-150, -20, -150); pr.leechCd = 0.1; pr.state = 'eat'; pr.timer = 99;
    D().step(5);
    T.ok(pr.leech && pr.leechM.visible);
    T.ok(ev.some(e => e.sp === 'leech' && e.note === 'infest'));
  });

  T.test('заражённый хищник медленнее', () => {
    const run = (leech) => {
      G.Game.debug.reset();
      const pr = E().preds[1];
      pr.leech = leech; pr.leechM.visible = leech; pr.leechCd = 999;
      pr.p.set(-150, -20, -150); pr.v.set(0, 0, 0); pr.state = 'retreat'; pr.timer = 99; pr.goal.set(-150, -20, 0);
      D().step(60);
      return pr.p.z + 150;
    };
    const healthy = run(false), sick = run(true);
    T.lt(sick, healthy * 0.85, `заражённый ${sick.toFixed(1)} м, здоровый ${healthy.toFixed(1)} м`);
  });

  T.test('заражённый хищник злее: замечает корабль со светом издалека', () => {
    const ev = T.captureEvents();
    const sick = E().preds[0], fine = E().preds[1];
    S().light = true; S().update(0.01, 0); E().update(0.01, 0);
    [sick, fine].forEach((pr, k) => {
      pr.p.copy(S().center).add(T.V(k ? -40 : 40, 0, 0)); pr.state = 'patrol'; pr.timer = 99; pr.goal.copy(pr.p); pr.hunger = 0.5; pr.cd = 0;
    });
    fine.leechCd = 999; E().preds[2].p.set(250, -20, 250); E().preds[2].cd = 999;
    D().step(1);
    T.eq(sick.state, 'charge', 'заражённый не атакует с 40 м');
    T.ok(fine.state !== 'charge', 'здоровый атакует с 40 м');
    T.ok(ev.some(e => e.sp === 'leech' && e.note === 'angry'));
  });

  T.test('огнёвки снимают пиявника на станции', () => {
    const ev = T.captureEvents();
    const pr = E().preds[0], st = E().stations[0];
    E().preds.slice(1).forEach(p => { p.p.set(250, -20, 250); p.cd = 999; });
    S().light = false; E().lastPing = -999;
    pr.p.copy(st.top).add(T.V(10, 0, 0)); pr.state = 'patrol'; pr.timer = 99; pr.hunger = 0; pr.station = null;
    D().step(1);
    T.eq(pr.state, 'clean', 'хищник не поплыл на станцию');
    D().step(400);
    T.ok(!pr.leech && !pr.leechM.visible, 'пиявник остался');
    T.ok(ev.some(e => e.sp === 'ognevka' && e.note === 'clean'));
    T.ok(ev.some(e => e.sp === 'leech' && e.note === 'cleaned'));
    T.eq(E().scanTargets().filter(t => t.sp === 'leech').length, 0);
  });

  T.test('голодный заражённый хищник сначала охотится, а не чистится', () => {
    const pr = E().preds[0];
    pr.p.set(-150, -20, -150); pr.state = 'patrol'; pr.timer = 99; pr.hunger = 0.9; pr.cd = 999;
    D().step(1);
    T.ok(pr.state !== 'clean');
  });
});

T.describe('Огнёвка в журнале', () => {
  const E = () => G.Eco, S = () => G.Ship, D = () => G.Game.debug;
  T.test('огнёвку сканируют с мостика, вид сохраняется', () => {
    const st = E().stations[0];
    S().pos.copy(st.top).add(T.V(0, 2, 22)); S().yaw = 0; S().applyTransform();
    E().preds.forEach(p => { p.p.set(250, -20, 250); p.cd = 999; });
    G.Game.toggleHelm(); D().frame(1);
    D().lookAt(st.top); D().frame(1);
    T.eq(D().actionLabel(), 'Сканировать (держать)');
    G.Ctl.actionDown = true;
    for (let i = 0; i < 40 && !G.SPECIES.ognevka.scanned; i++) { D().lookAt(st.top); D().frame(1); }
    G.Ctl.actionDown = false;
    T.ok(G.SPECIES.ognevka.scanned, 'не отсканировалась');
    G.Save.save();
    G.SPECIES.ognevka.scanned = false;
    G.Save.load();
    T.ok(G.SPECIES.ognevka.scanned, 'не сохранилась');
  });
});
