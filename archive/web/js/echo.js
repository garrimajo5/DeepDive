'use strict';
/* Эхоловец — засадчик около 3 метров у Костей левиафана. Слушает корабль большими ушами-воронками
   и подделывает голоса экипажа по внутренней связи. Настоящие вызовы экипажа начинаются с кодового
   слова погружения (видно на приборах), у подделки слова нет или оно старое — с прошлого спуска.
   Подделка просит то, что выгодно самому засадчику: «дайте импульс» — и он бьёт по корпусу на звук,
   «включите свет» — и на свет приходит серпохвост. Импульс сонара, о котором он не просил, выдаёт его:
   он раскрыт, и подделки на время прекращаются. */
(function (G) {
  const V3 = THREE.Vector3;
  const LISTEN_R = 60, STRIKE_R = 50, REVEAL_R = 70, BAIT_T = 10, FAKE_FIRST = 12, FAKE_CD = 45, REAL_CD = 75, REVEAL_T = 120, STRIKE = 12;
  const CODES = ['КОРАЛЛ', 'ЛЕДОКРЫЛ', 'ОГНЕЦВЕТ', 'МАЯК', 'ПОЛЫНЬЯ', 'КОЛОДЕЦ', 'РАКОВИНА', 'СВЕТЛЯК'];
  const Ec = G.Echo = { pos: null, code: '', oldCode: '', bait: null, revealed: 0, fakeT: FAKE_FIRST, realT: 30, near: false, calls: [], CODES, STRIKE, BAIT_T };
  let seed = 9; const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647); // свой генератор: не сбивает случайность экосистемы

  Ec.build = function (scene) {
    const b = G.World.pois.find(p => p.key === 'bones'); if (!b) return;
    const x = b.pos.x + 14, z = b.pos.z + 10;
    Ec.pos = new V3(x, G.World.height(x, z) + 0.7, z);
    const g = Ec.group = new THREE.Group(); g.position.copy(Ec.pos);
    Ec.skin = new THREE.MeshLambertMaterial({ color: 0x4a4038, emissive: 0x000000 });
    const body = new THREE.Mesh(new THREE.SphereGeometry(1, 12, 8), Ec.skin); body.scale.set(0.9, 0.45, 1.5); g.add(body);
    const earGeo = new THREE.ConeGeometry(0.55, 1.1, 12, 1, true).translate(0, 0.55, 0);
    [-1, 1].forEach(s => { const e = new THREE.Mesh(earGeo, Ec.skin); e.position.set(s * 0.55, 0.25, -0.6); e.rotation.set(-0.5, 0, s * 0.45); g.add(e); });
    Ec.eye = new THREE.Mesh(new THREE.SphereGeometry(0.12, 8, 6), new THREE.MeshBasicMaterial({ color: 0x302820 })); Ec.eye.position.set(0, 0.3, -1.35); g.add(Ec.eye);
    scene.add(g);
    if (!Ec.code) Ec.newDive();
  };
  /* новый спуск — новое кодовое слово; старое эхоловец уже слышал */
  Ec.newDive = function () {
    Ec.oldCode = Ec.code;
    do Ec.code = CODES[Math.floor(rnd() * CODES.length)]; while (Ec.code === Ec.oldCode);
    Ec.hud();
    return Ec.code;
  };
  Ec.reset = function () { Ec.bait = null; Ec.revealed = 0; Ec.fakeT = FAKE_FIRST; Ec.realT = 30; Ec.near = false; Ec.calls.length = 0; Ec.show(null); };
  Ec.dist = () => (Ec.pos ? Ec.pos.distanceTo(G.Ship.center) : 1e9);

  /* вызов по внутренней связи: баннер наверху, звук и строка в журнале событий */
  Ec.call = function (who, text, fake) {
    const c = { who, text, fake: !!fake, t: G.Game.t };
    Ec.calls.push(c); if (Ec.calls.length > 20) Ec.calls.shift();
    Ec.show(c); G.Audio.beep(fake ? 520 : 640); G.Audio.beep(fake ? 470 : 700);
    G.Game.feedMsg && G.Game.feedMsg(`Связь · ${who}: «${text}»`);
    return c;
  };
  Ec.show = function (c) {
    const el = document.getElementById('intercom'); if (!el) return;
    el.hidden = !c; Ec.showT = c ? 7 : 0;
    if (c) el.innerHTML = `<small>Связь · ${c.who}</small><b>«${c.text}»</b>`;
  };
  /* настоящий доклад экипажа — с кодовым словом */
  Ec.real = function () {
    const S = G.Ship, list = [
      ['Пилот', `Курс держим, корпус ${Math.round(S.hull)}%.`], ['Инженер', `Энергии ${Math.round(S.energy)}, реактор в норме.`],
      ['Сонарщик', 'Сонар готов, жду команды.'], ['Биолог', `В трюме образцов: ${S.cargo.length}.`]
    ];
    const [who, t] = list[Math.floor(rnd() * list.length)];
    return Ec.call(who, `${Ec.code}. ${t}`, false);
  };
  /* подделка: без слова или со старым, и с просьбой, выгодной засадчику */
  Ec.fake = function (kind) {
    kind = kind || (!G.Ship.light && rnd() < 0.5 ? 'light' : 'ping');
    const pre = Ec.oldCode ? Ec.oldCode + '. ' : '';
    const [who, t] = kind === 'light' ? ['Пилот', 'Включите прожектор, ничего не видно!'] : ['Сонарщик', 'Срочно импульс сонара, рядом что-то большое!'];
    Ec.bait = { kind, t: BAIT_T };
    const c = Ec.call(who, pre + t, true);
    G.Eco.emit('echo', 'fake', Ec.pos, () => 'Голос по связи без кодового слова погружения — это не экипаж');
    return c;
  };

  Ec.update = function (dt) {
    if (!Ec.pos) return;
    if (Ec.showT > 0) { Ec.showT -= dt; if (Ec.showT <= 0) Ec.show(null); }
    if (G.Net && G.Net.isGuest()) return; // засадчика считает хост
    const d = Ec.dist();
    Ec.near = d < LISTEN_R;
    Ec.realT -= dt; if (Ec.realT <= 0) { Ec.realT = REAL_CD; Ec.real(); }
    if (Ec.revealed > 0) Ec.revealed -= dt;
    if (Ec.bait) { Ec.bait.t -= dt; if (Ec.bait.t <= 0) Ec.bait = null; }
    if (Ec.near && Ec.revealed <= 0) { Ec.fakeT -= dt; if (Ec.fakeT <= 0) { Ec.fakeT = FAKE_CD; Ec.fake(); } }
    else if (!Ec.near) Ec.fakeT = Math.max(Ec.fakeT, FAKE_FIRST);
    /* вид: раскрытый светится ушами, затаившийся — под цвет камня */
    const k = Ec.revealed > 0 ? 0.5 + 0.5 * Math.sin(G.Game.t * 3) : 0;
    Ec.skin.emissive.setRGB(0.35 * k, 0.12 * k, 0.05 * k); Ec.eye.material.color.setRGB(0.19 + 0.8 * k, 0.16 + 0.5 * k, 0.12);
  };
  /* импульс сонара: на выпрошенный звук — удар, на неожиданный — засадчик выдаёт себя */
  Ec.onPing = function () {
    if (!Ec.pos || (G.Net && G.Net.isGuest())) return;
    const d = Ec.dist();
    if (Ec.bait && Ec.bait.kind === 'ping' && d < STRIKE_R) {
      Ec.bait = null; G.Game.hullHit(STRIKE, 'echo');
      G.Eco.emit('echo', 'strike', Ec.pos, () => 'Эхоловец ударил по корпусу на звук импульса, который сам выпросил');
      return 'strike';
    }
    if ((!Ec.bait || Ec.bait.kind !== 'ping') && d < REVEAL_R) {
      const was = Ec.revealed > 0; Ec.revealed = REVEAL_T; Ec.bait = null;
      if (!was) { G.Game.toast('Сонар засёк эхоловца', 'У Костей левиафана затаился засадчик с ушами-воронками. Пока он раскрыт, ложных вызовов не будет.'); G.Eco.emit('echo', 'reveal', Ec.pos, () => 'Импульс сонара выдал эхоловца: он раскрыт'); }
      return 'reveal';
    }
    return null;
  };
  /* свет включили по подделке — на свет идёт ближайший серпохвост */
  Ec.onLight = function (on) {
    if (!on || !Ec.bait || Ec.bait.kind !== 'light' || (G.Net && G.Net.isGuest())) return null;
    Ec.bait = null;
    const S = G.Ship; let best = null, bd = 160;
    G.Eco.preds.forEach(pr => { const dd = pr.p.distanceTo(S.center); if (dd < bd && pr.state !== 'charge') { bd = dd; best = pr; } });
    if (best) G.Eco.lure(best);
    G.Eco.emit('echo', 'lure', Ec.pos, () => 'Свет включили по ложному вызову — на него идёт серпохвост');
    return best;
  };
  Ec.hud = function () { const el = document.getElementById('s-code'); if (el && Ec.code) { el.hidden = false; el.textContent = 'Код погружения: ' + Ec.code; } };
  /* цель сканирования: видна, только когда раскрыт */
  Ec.target = () => (Ec.pos ? { sp: 'echo', pos: Ec.pos, r: 2, hidden: Ec.revealed <= 0, noSonar: Ec.revealed <= 0 } : null);
})(window.G);
