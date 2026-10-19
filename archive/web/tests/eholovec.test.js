'use strict';
/* Эхоловец: ложные вызовы по связи, кодовое слово, удар на выпрошенный импульс, свет для серпохвоста */
T.describe('Эхоловец', () => {
  const Ec = () => G.Echo, S = () => G.Ship, D = () => G.Game.debug, E = () => G.Eco;
  const quiet = () => E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); });
  const near = (dz) => {
    const p = Ec().pos, x = p.x, z = p.z + (dz || 22);
    S().pos.set(x, Math.max(p.y + 8, G.World.height(x, z) + 9), z); S().speed = 0; S().vy = 0; S().yaw = 0; S().applyTransform();
  };
  const hold = () => { const p = S().pos.clone(); return () => { S().pos.copy(p); S().speed = 0; S().vy = 0; S().applyTransform(); }; };
  const run = (sec) => { const back = hold(); for (let i = 0; i < sec * 20; i++) { D().frame(1); back(); } };
  const fakes = () => Ec().calls.filter(c => c.fake);

  T.test('вид в журнале: эхоловец у Костей левиафана', () => {
    T.ok(G.SPECIES.echo && G.SPECIES_ORDER.includes('echo'));
    T.eq(Object.keys(G.SPECIES.echo.notes).length, 4);
    const b = G.World.pois.find(p => p.key === 'bones');
    T.lt(Math.hypot(Ec().pos.x - b.pos.x, Ec().pos.z - b.pos.z), 25, 'далеко от Костей');
    T.ok(Ec().pos.y > G.World.height(Ec().pos.x, Ec().pos.z), 'под дном');
    const tg = E().scanTargets().find(t => t.sp === 'echo'); T.ok(tg && tg.hidden && tg.noSonar, 'затаившийся виден');
  });

  T.test('рядом с кораблём подделывает голос: без кодового слова, с просьбой', () => {
    quiet(); Ec().realT = 999; near();
    run(13);
    const f = fakes(); T.eq(f.length, 1, 'нет ложного вызова');
    T.ok(!f[0].text.includes(Ec().code), 'в подделке настоящее кодовое слово');
    T.ok(Ec().bait, 'подделка ничего не просит');
    const el = document.getElementById('intercom'); T.ok(!el.hidden); T.ok(el.textContent.includes('Связь'));
    T.ok(G.SPECIES.echo.seen.has('fake'), 'нет наблюдения');
  });

  T.test('настоящий доклад экипажа — с кодовым словом, его видно на приборах', () => {
    quiet(); Ec().realT = 0.01; S().pos.set(-110, -12, -30); S().applyTransform(); D().frame(2);
    const r = Ec().calls.filter(c => !c.fake); T.eq(r.length, 1);
    T.ok(r[0].text.startsWith(Ec().code + '.'), 'доклад без кода: ' + r[0].text);
    T.ok(document.getElementById('s-code').textContent.includes(Ec().code));
  });

  T.test('новый спуск: новое слово, а эхоловец говорит старым', () => {
    quiet(); const old = Ec().code;
    G.Run.decide('deep'); G.Game.state = 'play';
    T.ok(Ec().code !== old); T.eq(Ec().oldCode, old);
    T.ok(document.getElementById('s-code').textContent.includes(Ec().code));
    const c = Ec().fake('ping');
    T.ok(c.text.startsWith(old + '.'), 'подделка без старого слова'); T.ok(!c.text.includes(Ec().code));
  });

  T.test('поверили «дайте импульс» — удар по корпусу', () => {
    quiet(); Ec().realT = 999; near();
    Ec().fake('ping'); const h = S().hull;
    G.Sonar.ping(); D().frame(1);
    T.lt(S().hull, h - Ec().STRIKE + 1, 'нет удара на выпрошенный импульс');
    T.ok(!Ec().bait); T.ok(G.SPECIES.echo.seen.has('strike'));
  });

  T.test('импульс без просьбы выдаёт засадчика: подделки прекращаются (контроль)', () => {
    quiet(); Ec().realT = 999; near(); const h = S().hull;
    G.Sonar.ping(); D().frame(1);
    T.eq(S().hull, h, 'удар без просьбы'); T.gt(Ec().revealed, 0, 'не раскрыт');
    T.ok(G.SPECIES.echo.seen.has('reveal'));
    const tg = E().scanTargets().find(t => t.sp === 'echo'); T.ok(!tg.hidden, 'раскрытого не просканировать');
    run(60); T.eq(fakes().length, 0, 'раскрытый всё равно подделывает голоса');
  });

  T.test('поверили «включите прожектор» — на свет идёт серпохвост', () => {
    quiet(); Ec().realT = 999; near();
    const pr = E().preds[0]; pr.p.copy(S().center).add(new THREE.Vector3(40, 0, 0)); pr.state = 'patrol'; pr.cd = 999;
    if (S().light) G.Game.toggleLight();
    Ec().fake('light'); G.Game.toggleLight();
    T.eq(pr.state, 'charge', 'серпохвост не пошёл на свет'); D().frame(1); T.ok(G.SPECIES.echo.seen.has('lure'), 'нет наблюдения');
    G.Game.toggleLight(); pr.state = 'patrol'; G.Game.toggleLight();
    T.eq(pr.state, 'patrol', 'свет без подделки сам гонит серпохвоста (контроль)');
  });

  T.test('вдали от Костей ложных вызовов нет (контроль)', () => {
    quiet(); Ec().realT = 999; S().pos.set(-110, -12, -30); S().applyTransform();
    run(60); T.eq(fakes().length, 0);
  });

  T.test('у гостя экипажа засадчик не считается — его ведёт хост', () => {
    quiet(); Ec().realT = 999; near();
    const N = G.Net; Object.assign(N, { on: true, host: false, status: 'joined' });
    try { run(15); T.eq(fakes().length, 0, 'гость сам придумал подделку'); }
    finally { Object.assign(N, { on: false, host: false, status: 'off' }); N.hud(); }
  });
});
