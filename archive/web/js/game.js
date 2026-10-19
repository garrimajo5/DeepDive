'use strict';
/* Главный цикл, игрок внутри корабля, взаимодействия, интерфейс */
(function (G) {
  const V3 = THREE.Vector3;
  const $ = id => document.getElementById(id);
  const Game = G.Game = {
    state: 'intro', t: 0, piloting: false, room: 'bridge', done: false, shake: 0, vignette: 0,
    player: { x: 0, z: -3.0, yaw: 0, pitch: -0.08, bob: 0 },
    scan: { key: null, prog: 0 }
  };
  let renderer, scene, camera, hemi, sun, clock;
  const tmp = { v1: new V3(), v2: new V3(), v3: new V3(), q: new THREE.Quaternion(), qy: new THREE.Quaternion(), e: new THREE.Euler(0, 0, 0, 'YXZ'), up: new V3(0, 1, 0) };
  const fogA = new THREE.Color(0x1a6676), fogB = new THREE.Color(0x041a22);

  Game.init = function () {
    renderer = new THREE.WebGLRenderer({ canvas: $('view'), antialias: true, powerPreference: 'high-performance' });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.25));
    scene = new THREE.Scene();
    scene.fog = new THREE.FogExp2(fogA.clone(), 0.017);
    scene.background = fogA.clone();
    camera = new THREE.PerspectiveCamera(72, 1, 0.05, 420);
    hemi = new THREE.HemisphereLight(0x9ad9e8, 0x0b1c24, 0.9); scene.add(hemi);
    sun = new THREE.DirectionalLight(0xc8f2ff, 0.55); sun.position.set(0.3, 1, 0.25); scene.add(sun);
    G.World.build(scene);
    G.Sonar.init();
    G.Ship.build(scene);
    G.Eco.init(scene); G.Silt.build(scene); G.Echo.build(scene); G.Manip.build(scene);
    G.Ship.group.add(camera); camera.position.set(0, 1.65, -3);
    G.Ctl.init(); bindUI(); G.Power.init(); G.Cargo.init(); G.Run.init(); G.Ship.drawPower(); G.DebugPanel.init(); G.Tutorial.init(); G.Settings.init(); resize(); addEventListener('resize', resize);
    clock = new THREE.Clock();
    renderer.xr.enabled = true; G.AR.build(); G.AR.check(); G.Net.auto();
    renderer.setAnimationLoop(loop);
    if (G.Save.load() && G.Save.hasProgress()) { const c = counts(); $('loading').textContent = `Журнал загружен: видов ${c.s} из ${c.sn}, мест ${c.p} из ${c.pn}.`; }
    else $('loading').hidden = true;
    $('b-start').hidden = false;
    updateCounts();
  };

  /* отладка: прогон симуляции без отрисовки и статистика рендера */
  Game.debug = {
    info: () => ({ calls: renderer.info.render.calls, tris: renderer.info.render.triangles, geos: renderer.info.memory.geometries }),
    step(n, dt) {
      dt = dt || 0.05;
      for (let i = 0; i < n; i++) {
        Game.t += dt; G.timeU.value = Game.t;
        G.Ctl.read(); updatePlayer(dt);
        G.Ship.update(dt, Game.t); G.World.update(dt, Game.t); G.Eco.update(dt, Game.t); G.Sonar.update(dt, Game.t);
        handleEvents(); updateDiscover();
      }
      G.Ctl.lookDX = G.Ctl.lookDY = 0;
    },
    /* полный кадр логики, как в игре: ввод, взаимодействия, сканирование, события */
    frame(n, dt) {
      dt = dt || 0.05;
      for (let i = 0; i < n; i++) {
        Game.t += dt; G.timeU.value = Game.t; G.Ctl.read();
        if (Game.state === 'play') simulate(dt);
        else if (Game.state === 'journal' && G.Ctl.journalPressed) closeJournal();
        else if (Game.state === 'settings' && G.Ctl.journalPressed) G.Settings.close();
        else if (Game.state === 'vote') G.Run.voteNav(G.Ctl.move.x);
        clearOneShots();
      }
    },
    /* смотреть из текущего места на точку мира */
    lookAt(world) {
      const P = Game.player, loc = G.Ship.group.worldToLocal(world.clone());
      const eye = Game.piloting ? new V3(0, 1.62, -4.3) : new V3(P.x, 1.65, P.z);
      const d = loc.sub(eye);
      P.yaw = Math.atan2(-d.x, -d.z); P.pitch = Math.atan2(d.y, Math.hypot(d.x, d.z));
      updatePlayer(0);
    },
    /* вернуть мир и игрока в исходное состояние (для тестов) */
    /* ?test в адресе: игра стоит на паузе с первого кадра, чтобы тесты начинались с одного и того же мира */
    paused: /[?&]test\b/.test(location.search),
    reset() {
      G.seed(12345); G.Save.wipe(); G.Tutorial.skip(); G.Save.dirty = false;
      if (G.Settings.isOpen()) G.Settings.close();
      G.Settings.reset(true);
      G.Roles.reset(); G.Voice.reset(); G.Sound.reset(); G.Power.reset(); G.Breach.reset(); G.Silt.reset(); G.Echo.reset(); G.Manip.reset(); G.Cargo.reset(); G.Run.reset(); G.Ship.reset(); G.Eco.reset(); G.Eco.events.length = 0;
      G.SPECIES_ORDER.forEach(k => { G.SPECIES[k].scanned = false; G.SPECIES[k].seen.clear(); });
      G.World.pois.forEach(p => { p.found = false; p.pinged = false; });
      G.Ship.doors.forEach(d => { d.open = false; d.t = 0; });
      if (Game.piloting) Game.toggleHelm();
      const P = Game.player; P.x = 0; P.z = -3; P.yaw = 0; P.pitch = -0.08;
      Object.assign(G.Ctl.padMove, { x: 0, y: 0 }); G.Ctl.btnVert = 0; G.Ctl.actionDown = false; G.Ctl.keys = {};
      $('feed-list').textContent = ''; Game.feedUnread = 0; Game.renderFeed();
      Game.scan.key = null; Game.scan.prog = 0; Game.done = false; Game.shake = 0; Game.vignette = 0;
      ['journal', 'lost', 'intro', 'settings'].forEach(id => { $(id).hidden = true; }); $('hud').hidden = false;
      Game.state = 'play'; updateCounts(); updatePlayer(0);
    },
    get camera() { return camera; },
    /* отрисовать один кадр и вернуть нагрузку (для проверки бюджета) */
    render() { updatePlayer(0); updateEnv(); renderer.render(scene, camera); return Game.debug.info(); },
    teleport: key => G.DebugPanel.teleport(key),
    get pixelRatio() { return curPR; },
    actionLabel: () => $('act-label').textContent,
    feed: () => [...document.querySelectorAll('#feed-list > div')].map(d => d.textContent)
  };

  function resize() {
    const w = window.innerWidth, h = window.innerHeight;
    renderer.setSize(w, h, false); camera.aspect = w / h;
    camera.fov = w < h ? 85 : 72; camera.updateProjectionMatrix();
  }

  /* адаптивное разрешение: держим плавность на слабых телефонах */
  const maxPR = Math.min(window.devicePixelRatio || 1, 1.6);
  let curPR = Math.min(maxPR, 1.25), fpsAcc = 0, fpsN = 0;
  Game.quality = 'auto';
  /* качество графики из настроек: «авто» — адаптивное разрешение, иначе фиксированное */
  Game.setQuality = function (q) {
    const fixed = { low: 0.7, mid: 1, high: Math.min(window.devicePixelRatio || 1, 2) };
    Game.quality = q in fixed ? q : 'auto';
    curPR = Game.quality === 'auto' ? Math.min(maxPR, 1.25) : fixed[Game.quality];
    fpsAcc = 0; fpsN = 0;
    G.World.shafts.forEach(s => { s.visible = Game.quality !== 'low'; });
    if (renderer) { renderer.setPixelRatio(curPR); resize(); }
  };
  Game.resumeClock = () => { if (clock) clock.getDelta(); };
  function adapt(raw) {
    if (Game.quality !== 'auto') return;
    fpsAcc += raw; fpsN++;
    if (fpsAcc < 2.5) return;
    const fps = fpsN / fpsAcc; fpsAcc = 0; fpsN = 0;
    let n = curPR;
    if (fps < 42 && curPR > 0.7) n = Math.max(0.7, curPR - 0.2);
    else if (fps > 58 && curPR < maxPR) n = Math.min(maxPR, curPR + 0.15);
    if (n !== curPR) { curPR = n; renderer.setPixelRatio(curPR); resize(); }
  }

  function loop(time, xrFrame) {
    const raw = clock.getDelta();
    if (Game.state !== 'intro') adapt(raw);
    G.DebugPanel.tick(raw);
    if (Game.debug.paused) { renderer.render(scene, camera); return; } // на паузе время и мир стоят
    const dt = Math.min(raw, 0.05);
    Game.t += dt; G.timeU.value = Game.t;
    const S = G.Ship, C = G.Ctl;
    C.read();
    if (Game.state === 'play') {
      simulate(dt);
    } else if (Game.state === 'intro') {
      camera.quaternion.setFromEuler(tmp.e.set(-0.04, Math.sin(Game.t * 0.08) * 0.7, 0, 'YXZ'));
      S.update(dt, Game.t); G.World.update(dt, Game.t); G.Eco.update(dt, Game.t); G.Sonar.update(dt, Game.t);
      G.Eco.events.length = 0;
    } else if (Game.state === 'journal') {
      if (C.journalPressed) closeJournal();
    } else if (Game.state === 'settings') {
      if (C.journalPressed) G.Settings.close();
    } else if (Game.state === 'vote') G.Run.voteNav(C.move.x); // решение экипажа: мир ждёт
    clearOneShots();
    updateEnv(); updateHUD(dt);
    if (G.AR.active) { // в AR — комната, голостол на столе и иллюминаторы с океаном
      G.AR.frame(xrFrame, renderer.xr.getReferenceSpace(), dt, renderer.xr.getCamera());
      G.AR.renderWindows(renderer, scene); renderer.render(G.AR.scene, G.AR.camera);
    }
    else renderer.render(scene, camera);
  }

  /* один шаг игровой логики в режиме «play» (без рендера) */
  function simulate(dt) {
    const S = G.Ship, C = G.Ctl;
    if (C.journalPressed) Game.openJournal();
    if (C.lightPressed) Game.toggleLight();
    if (C.standPressed && Game.piloting) Game.toggleHelm();
    if (C.pingPressed) { if (G.Roles.lock('sonar')) Game.toast('Сонар — не ваш пост', G.Roles.lockLabel('sonar')); else G.Sonar.ping(); }
    if (G.Power.isOpen()) { // пульт энергии: крестовина управляет пультом, игрок стоит; кнопка действия закрывает
      G.Power.nav(C.move.x, C.move.y, dt); C.move.x = C.move.y = 0;
      if (C.actionPressed) { C.actionPressed = false; G.Power.close(); }
      if (Game.room !== 'eng' || Game.piloting) G.Power.close();
    }
    if (G.Run.isOpen()) { // брифинг на голостоле
      G.Run.nav(C.move.x, C.move.y); C.move.x = C.move.y = 0;
      if (C.actionPressed) { C.actionPressed = false; G.Run.close(); }
      if (Game.room !== 'bridge' || Game.piloting) G.Run.close();
    }
    if (G.Cargo.isOpen()) { // терминал трюма: тот же принцип, что у пульта энергии
      G.Cargo.nav(C.move.x, C.move.y); C.move.x = C.move.y = 0;
      if (C.actionPressed) { C.actionPressed = false; G.Cargo.close(); }
      if (Game.room !== 'cargo' || Game.piloting) G.Cargo.close();
    }
    updatePlayer(dt);
    G.Net.beforeShip(); // ввод гостя экипажа — хосту
    S.update(dt, Game.t); G.World.update(dt, Game.t); G.Eco.update(dt, Game.t); G.Sonar.update(dt, Game.t);
    handleEvents(); updateInteraction(dt); updateDiscover(); G.Run.update(dt); ambience(dt);
    G.Net.update(dt); // хост рассылает корабль, гость тянется к нему
    G.Voice.update(); // кнопка «Связь»
    G.Tutorial.update();
    G.Save.tick(dt);
  }
  function clearOneShots() {
    const C = G.Ctl;
    C.actionPressed = false; C.pingPressed = false; C.lightPressed = false; C.journalPressed = false; C.standPressed = false;
    C.lookDX = C.lookDY = 0;
  }

  /* ---------- игрок ---------- */
  let vigEl = null, vigShown = 0;
  function updatePlayer(dt) {
    const P = Game.player, C = G.Ctl, S = G.Ship, sens = 0.0055 * G.Settings.lookX(), sensY = 0.0055 * G.Settings.lookY();
    const comfort = G.Settings.comfort();
    if (!vigEl) vigEl = $('fx-vignette');
    if (C.gyro && C.gyroOK) {
      if (C.needCalib) { tmp.e.setFromQuaternion(C.gyroQ, 'YXZ'); C.yawOffset = P.yaw - tmp.e.y; C.needCalib = false; }
      C.yawOffset -= C.lookDX * sens;
      tmp.qy.setFromAxisAngle(tmp.up, C.yawOffset);
      camera.quaternion.copy(tmp.qy).multiply(C.gyroQ);
      tmp.e.setFromQuaternion(camera.quaternion, 'YXZ'); P.yaw = tmp.e.y; P.pitch = tmp.e.x;
    } else {
      P.yaw -= C.lookDX * sens;
      P.pitch = G.clamp(P.pitch - C.lookDY * sensY, -1.45, 1.45);
      camera.quaternion.setFromEuler(tmp.e.set(P.pitch, P.yaw, 0, 'YXZ'));
    }
    let cx, cy, cz;
    if (Game.piloting) {
      S.input.thrust = C.move.y; S.input.turn = C.move.x; S.input.vert = C.vert;
      cx = 0; cy = 1.62; cz = -4.3;
    } else {
      S.input.thrust = S.input.turn = S.input.vert = 0;
      let mx = C.move.x, my = C.move.y;
      const len = Math.hypot(mx, my);
      if (len > 0) {
        mx /= len; my /= len;
        const sp = 2.4 * dt * G.Breach.slow(Game.room), fx = -Math.sin(P.yaw), fz = -Math.cos(P.yaw), rx = Math.cos(P.yaw), rz = -Math.sin(P.yaw);
        const dx = (fx * my + rx * mx) * sp, dz = (fz * my + rz * mx) * sp;
        if (S.canStand(P.x + dx, P.z)) P.x += dx;
        if (S.canStand(P.x, P.z + dz)) P.z += dz;
        P.bob += dt * 9;
      }
      Game.room = S.roomAt(P.z);
      cx = P.x; cy = 1.65 + (comfort ? 0 : Math.sin(P.bob) * 0.03); cz = P.z;
    }
    if (Game.piloting) Game.room = 'bridge';
    Game.shake = Math.max(0, Game.shake - dt);
    const sh = Game.shake * (comfort ? 0.1 : 0.25);
    /* тень по краям экрана, пока мир за стеклом поворачивается или корабль резко меняет глубину */
    const vt = comfort && !G.AR.active ? G.clamp(Math.abs(S.turn) * 0.85 + Math.abs(S.vy) / 2.6 * 0.3, 0, 0.85) : 0;
    Game.vignette = comfort ? Game.vignette + (vt - Game.vignette) * Math.min(1, dt * 4) : 0;
    if (Game.vignette < 0.005) Game.vignette = 0;
    if (Math.abs(Game.vignette - vigShown) > 0.01 || (Game.vignette === 0 && vigShown !== 0)) { vigShown = Game.vignette; vigEl.style.opacity = vigShown.toFixed(2); }
    camera.position.set(cx + G.rr(-sh, sh), cy + G.rr(-sh, sh), cz + G.rr(-sh, sh));
  }

  /* ---------- действия ---------- */
  Game.toggleHelm = function () {
    Game.piloting = !Game.piloting;
    const P = Game.player;
    if (Game.piloting) { P.yaw = 0; P.pitch = -0.08; G.Audio.beep(660); toastOnce('helm', 'Вы за штурвалом', 'Крестовина ведёт корабль, «Всплыть» и «Вниз» меняют глубину, «Сонар» показывает, что вокруг. Круглая кнопка — встать или сканировать.'); }
    else { P.x = 0; P.z = -3.2; P.yaw = 0; G.Ship.input.thrust = G.Ship.input.turn = G.Ship.input.vert = 0; G.Audio.beep(440); }
    $('pilotbtns').hidden = !Game.piloting;
    if (G.Ctl.gyro) G.Ctl.needCalib = true;
  };
  Game.toggleLight = function () {
    const S = G.Ship;
    if (!S.light && S.energy < 3) { Game.toast('Мало энергии', 'Прожектор не включить'); return; }
    if (!S.light && G.Power.k('lamp') <= 0) { Game.toast('Прожектор обесточен', G.Power.scram > 0 ? 'Аварийный сброс реактора' : 'Дайте ему энергию в машинном отделении'); return; }
    S.light = !S.light; G.Audio.beep(S.light ? 760 : 380); G.Echo.onLight(S.light);
    if (G.Net.isGuest()) G.Net.pendingLight = Game.t; // попросить хоста переключить свет
    $('b-light').classList.toggle('lit', S.light);
  };
  Game.zap = function () {
    const S = G.Ship;
    if (G.Power.k('zap') <= 0) { Game.toast('Разряд обесточен', G.Power.scram > 0 ? 'Аварийный сброс реактора' : 'В машинном отделении у разряда 0 единиц'); G.Audio.beep(220); return; }
    if (S.energy < 15) { Game.toast('Мало энергии', 'Для разряда нужно 15 единиц'); G.Audio.beep(220); return; }
    S.energy -= 15; S.flicker = 0.8; G.Audio.zap(); flash('rgba(94,242,214,.55)');
    G.Eco.onZap();
  };
  Game.hullHit = function (n, kind) {
    const S = G.Ship; if (S.hull <= 0) return;
    if (G.Cargo.has('hull')) n = Math.max(1, Math.round(n * 0.7)); // броня из огнецвета и игл
    S.hull = Math.max(0, S.hull - n); Game.shake = 0.6; S.flicker = 0.4;
    flash('rgba(255,93,108,.5)'); G.Audio.thud();
    feed(kind === 'scrape' ? `Удар о дно: корпус −${n}%` : `Удар по корпусу: −${n}%`);
    if (S.hull <= 0) lose(); else { G.Breach.onHit(n); G.Silt.onHit(n, kind); }
  };
  Game.feedMsg = (text, isNew) => feed(text, isNew);
  Game.onLatch = function () { G.Audio.latch(); G.Ship.flicker = 1.5; flash('rgba(191,246,255,.4)'); Game.shake = 0.3; };

  function lose() {
    Game.state = 'lost'; $('lost').hidden = false; G.Audio.alarm();
    if (Game.piloting) Game.toggleHelm();
  }
  function restart() {
    G.Breach.reset(); G.Silt.reset(); G.Echo.reset(); G.Ship.reset(); G.Eco.reset(); G.Save.mark(); // груз потерян вместе с кораблём
    const P = Game.player; P.x = 0; P.z = -3; P.yaw = 0; P.pitch = -0.08;
    $('lost').hidden = true; Game.state = 'play'; clock.getDelta();
  }

  /* ---------- сканирование и взаимодействие ---------- */
  function nearestInter() {
    const P = Game.player; let best = null, bd = 1e9;
    const fx = -Math.sin(P.yaw), fz = -Math.cos(P.yaw);
    for (const it of G.Ship.inter) {
      const dx = it.x - P.x, dz = it.z - P.z, d = Math.hypot(dx, dz);
      if (d > it.r || (it.on && !it.on())) continue;
      if (d > 0.9 && (dx * fx + dz * fz) / d < 0.3) continue;
      if (d < bd) { bd = d; best = it; }
    }
    return best;
  }
  function findScanTarget() {
    const camPos = camera.getWorldPosition(tmp.v1), camDir = camera.getWorldDirection(tmp.v2);
    const ld = tmp.v3.copy(camDir).applyQuaternion(tmp.q.copy(G.Ship.group.quaternion).invert());
    if (!G.Ship.throughWindow(camera.position, ld, Game.room)) return null;
    let best = null, bs = 1;
    for (const tg of G.Eco.scanTargets()) {
      if (tg.hidden) continue; // замаскированное существо не берётся в прицел
      const dx = tg.pos.x - camPos.x, dy = tg.pos.y - camPos.y, dz = tg.pos.z - camPos.z;
      const dist = Math.hypot(dx, dy, dz);
      if (dist > 80 || dist < 1) continue;
      const ang = Math.acos(G.clamp((dx * camDir.x + dy * camDir.y + dz * camDir.z) / dist, -1, 1));
      const s = ang / Math.max(0.065, Math.atan(tg.r / dist));
      if (s < bs) { bs = s; best = { sp: tg.sp, dist }; }
    }
    return best;
  }
  function updateInteraction(dt) {
    const C = G.Ctl, SP = G.SPECIES;
    const tgt = findScanTarget();
    $('reticle').classList.toggle('aim', !!tgt);
    $('target').textContent = tgt ? `${SP[tgt.sp].scanned ? SP[tgt.sp].name : 'Неизвестный вид'} · ${Math.round(tgt.dist)} м` : '';
    let act = null;
    let it = Game.piloting ? null : nearestInter();
    if (it && tgt) { // если в прицеле существо, пост перехватывает кнопку только при прямом взгляде на него
      const P = Game.player, ld = camera.getWorldDirection(tmp.v2).applyQuaternion(tmp.q.copy(G.Ship.group.quaternion).invert());
      const dx = it.x - P.x, dy = 1.0 - 1.65, dz = it.z - P.z, d = Math.hypot(dx, dy, dz);
      if ((dx * ld.x + dy * ld.y + dz * ld.z) / d < 0.94) it = null;
    }
    /* манипулятор: образец на дне в прицеле сквозь стеклянный пол лаборатории */
    let smp = null;
    if (!it && Game.room === 'lab' && !Game.piloting) {
      const cp = camera.getWorldPosition(tmp.v1), cd = camera.getWorldDirection(tmp.v2);
      const ld = tmp.v3.copy(cd).applyQuaternion(tmp.q.copy(G.Ship.group.quaternion).invert());
      if (G.Ship.throughWindow(camera.position, ld, 'lab')) smp = G.Manip.find(cp, cd);
      if (smp && tgt && smp.score > 0.6) smp = null; // существо в прицеле точнее — сканируем его
    }
    if (G.Manip.state === 'reach' && !it && Game.room === 'lab') act = { label: 'Манипулятор: взять образец (держать)', holdFn: dt => G.Manip.hold(G.Manip.target, dt), prog: G.Manip.progress };
    else if (G.Manip.state === 'back' && !it && Game.room === 'lab') act = { label: 'Манипулятор: образец в шлюз…', holdFn: () => {}, prog: G.Manip.progress };
    else if (it && G.Roles.lock(it.post)) act = { label: G.Roles.lockLabel(it.post), fn: () => {}, dis: true }; // пост чужой роли
    else if (it) act = { label: it.label(), fn: it.fn, dis: it.ok ? !it.ok() : false, holdFn: it.holdFn, prog: it.prog };
    else if (smp && G.Roles.lock('manip')) act = { label: G.Roles.lockLabel('manip'), fn: () => {}, dis: true };
    else if (smp) { const s = smp.s; act = { label: 'Манипулятор: взять образец (держать)', holdFn: dt => G.Manip.hold(s, dt), prog: G.Manip.progress }; }
    else if (tgt) {
      const sp = SP[tgt.sp];
      act = sp.scanned ? { label: 'Сведения: ' + sp.name, fn: () => Game.openJournal(tgt.sp) } : { label: 'Сканировать (держать)', hold: tgt.sp };
    } else if (Game.piloting) act = { label: 'Встать', fn: () => Game.toggleHelm() };

    if (act && act.hold) {
      if (C.actionDown) {
        if (Game.scan.key !== act.hold) { Game.scan.key = act.hold; Game.scan.prog = 0; }
        Game.scan.prog += dt / 1.5; G.Audio.scanTick(Game.scan.prog);
        if (Game.scan.prog >= 1) { completeScan(act.hold); Game.scan.prog = 0; }
      } else Game.scan.prog = Math.max(0, Game.scan.prog - dt * 2);
    } else Game.scan.prog = 0;
    if (act && act.holdFn && C.actionDown) act.holdFn(dt); // удержание у поста (сварка)
    $('scanring').style.setProperty('--p', (act && act.prog ? act.prog() : Game.scan.prog).toFixed(3));
    if (act && !act.hold && !act.holdFn && !act.dis && C.actionPressed) act.fn();
    const btn = $('b-action'), lbl = act ? act.label : 'Действие';
    if (btn.dataset.l !== lbl) { $('act-label').textContent = lbl; btn.dataset.l = lbl; }
    btn.classList.toggle('dis', !act || !!act.dis);
    btn.classList.toggle('scan', !!(act && (act.hold || act.holdFn)));
  }
  function completeScan(key) {
    const sp = G.SPECIES[key]; if (sp.scanned) return;
    sp.scanned = true; G.Audio.scanDone(); G.Save.mark(); G.Run.note('species');
    Game.toast('Новый вид: ' + sp.name, sp.desc);
    feed('Вид занесён в журнал: ' + sp.name, true);
    updateCounts(); checkComplete();
  }
  function handleEvents() {
    const E = G.Eco, S = G.Ship;
    for (const ev of E.events) {
      if (ev.pos.distanceTo(S.center) > 80) continue;
      const sp = G.SPECIES[ev.sp];
      let isNew = false;
      if (ev.note && !sp.seen.has(ev.note)) { sp.seen.add(ev.note); isNew = true; G.Save.mark(); }
      if (ev.msg) feed(ev.msg(), isNew); else if (isNew) feed('Новое наблюдение: ' + G.nm(ev.sp), true);
    }
    E.events.length = 0;
  }
  function updateDiscover() {
    const S = G.Ship;
    for (const p of G.World.pois) {
      if (p.found) continue;
      if (Math.hypot(p.pos.x - S.pos.x, p.pos.z - S.pos.z) < p.rd) {
        p.found = true; G.Audio.discover(); G.Save.mark(); G.Run.note('places');
        Game.toast('Открытие: ' + p.name, p.desc);
        feed('Место отмечено на сонаре: ' + p.name, true);
        updateCounts(); checkComplete();
      }
    }
  }
  function counts() {
    return { s: G.SPECIES_ORDER.filter(k => G.SPECIES[k].scanned).length, p: G.World.pois.filter(p => p.found).length, sn: G.SPECIES_ORDER.length, pn: G.World.pois.length };
  }
  function updateCounts() { const c = counts(); $('j-count').textContent = `${c.s}/${c.sn} · ${c.p}/${c.pn}`; }
  function checkComplete() {
    const c = counts();
    if (!Game.done && c.s === c.sn && c.p === c.pn) {
      Game.done = true;
      setTimeout(() => Game.toast('Отмель изучена', 'Все виды описаны, все места найдены. Следующий слой — Кристальный лес — появится в новой версии.', 7000), 4200);
    }
  }

  /* ---------- атмосфера ---------- */
  function ambience(dt) {
    const S = G.Ship, E = G.Eco;
    G.Sound.update(dt); // песни ледокрылов, гул рифа, тревоги
    G.Audio.engine(Math.abs(S.input.thrust) * 0.8 + Math.abs(S.speed) / 7 * 0.4);
    let danger = 0, warn = '';
    E.preds.forEach(p => { if (p.state === 'charge') danger = Math.max(danger, 1 - p.p.distanceTo(S.center) / 40); });
    if (danger > 0) warn = 'Хищник идёт на таран! Погасите свет, уйдите под вуаль или дайте разряд';
    if (E.latched) { warn = 'Стеклоуст на корпусе пьёт энергию. Разряд — пульт инженера у левого борта'; danger = Math.max(danger, 0.5); }
    else if (!warn && S.energy < 15) warn = 'Мало энергии: сбавьте ход и погасите прожектор';
    if (S.depthLimit > 0) { S.depthLimit -= dt; warn = 'Предельная глубина. Корпус не рассчитан на большее'; }
    if (!warn && S.hull < 25) warn = 'Корпус повреждён';
    if ($('warn').textContent !== warn) $('warn').textContent = warn;
    $('fx-danger').style.opacity = (danger * (0.6 + 0.4 * Math.sin(Game.t * 8))).toFixed(2);
  }
  const siltCol = new THREE.Color(0x3d3a2e);
  function updateEnv() {
    const k = G.smooth(8, 95, -G.Ship.pos.y);
    scene.fog.color.copy(fogA).lerp(fogB, k).lerp(siltCol, 0.6 * (G.Silt ? G.Silt.k : 0)); scene.background.copy(scene.fog.color); // ил — бурая муть
    scene.fog.density = 0.015 + 0.01 * k + 0.05 * (G.Silt ? G.Silt.k : 0); // в облаке ила вода мутнеет
    hemi.intensity = 0.95 - 0.55 * k; sun.intensity = 0.55 - 0.4 * k;
  }

  /* ---------- интерфейс ---------- */
  let hudT = 0;
  function setBar(id, v) { const el = $(id); el.style.width = v.toFixed(0) + '%'; el.className = v < 25 ? 'lo' : v < 50 ? 'mid' : ''; }
  function updateHUD(dt) {
    hudT -= dt; if (hudT > 0) return; hudT = 0.12;
    const S = G.Ship;
    $('s-depth').textContent = Math.round(-S.pos.y);
    $('s-head').textContent = String(Math.round(((-S.yaw * 180 / Math.PI) % 360 + 360) % 360)).padStart(3, '0');
    $('s-speed').textContent = Math.abs(S.speed).toFixed(1);
    setBar('s-hull', S.hull); setBar('s-energy', S.energy);
    $('s-place').textContent = Game.piloting ? 'За штурвалом' : { bridge: 'Мостик', corr: 'Коридор', lab: 'Лаборатория', eng: 'Машинное', cargo: 'Трюм' }[Game.room];
    $('b-light').classList.toggle('lit', S.light);
  }
  /* лента событий: до 4 строк, новые сверху; свёрнутая — одна последняя строка и число новых на кнопке */
  Game.feedUnread = 0;
  function feed(text, isNew) {
    const box = $('feed-list'), d = document.createElement('div');
    d.textContent = text; if (isNew) { d.className = 'new'; d.dataset.tag = 'в журнал'; }
    box.prepend(d);
    while (box.children.length > 4) box.lastChild.remove();
    if (G.Settings.v.feedMin) { Game.feedUnread++; Game.renderFeed(); } else fitFeed();
    setTimeout(() => { d.style.opacity = '0'; setTimeout(() => { d.remove(); fitFeed(); }, 1000); }, 9000);
  }
  /* на низком экране развёрнутая лента не залезает на приборы: старые строки, которые не влезли, прячутся */
  function fitFeed() {
    const box = $('feed-list'), st = $('stats'); if (!box || !st) return;
    const rows = [...box.children]; rows.forEach(d => d.classList.remove('over'));
    if (G.Settings.v.feedMin) return;
    const lim = st.getBoundingClientRect().bottom + 6;
    for (let i = rows.length - 1; i > 0 && $('feed').getBoundingClientRect().top < lim; i--) rows[i].classList.add('over');
  }
  Game.renderFeed = function () {
    const box = $('feed'), btn = $('b-feed'), badge = $('feed-new'); if (!box || !btn) return;
    const min = G.Settings.v.feedMin;
    if (!min) Game.feedUnread = 0;
    box.classList.toggle('min', min);
    btn.firstChild.textContent = min ? 'Лог ▸' : 'Лог ▾';
    btn.setAttribute('aria-label', min ? 'Развернуть ленту событий' : 'Свернуть ленту событий');
    badge.hidden = !(min && Game.feedUnread > 0);
    badge.textContent = '+' + Game.feedUnread;
    fitFeed();
  };
  Game.toggleFeed = function (min) {
    G.Settings.set('feedMin', typeof min === 'boolean' ? min : !G.Settings.v.feedMin);
    Game.feedUnread = 0; Game.renderFeed();
  };
  let toastTimer = 0;
  Game.toast = function (title, text, ms) {
    const el = $('toast');
    el.innerHTML = ''; const h = document.createElement('h3'); h.textContent = title; el.appendChild(h);
    if (text) { const p = document.createElement('p'); p.textContent = text; el.appendChild(p); }
    el.classList.add('show'); clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove('show'), ms || 4200);
  };
  const shownOnce = new Set();
  function toastOnce(key, a, b) { if (shownOnce.has(key)) return; shownOnce.add(key); Game.toast(a, b, 6000); }
  function flash(color) { const el = $('fx-hit'); el.style.transition = 'none'; el.style.background = color; el.style.opacity = '1'; void el.offsetWidth; el.style.transition = 'opacity .6s'; el.style.opacity = '0'; }

  /* ---------- журнал ---------- */
  Game.resetProgress = function () {
    G.Save.wipe();
    G.SPECIES_ORDER.forEach(k => { G.SPECIES[k].scanned = false; G.SPECIES[k].seen.clear(); });
    G.Tutorial.restart();
    G.World.pois.forEach(p => { p.found = false; p.pinged = false; });
    G.Ship.cargo.length = 0; G.Manip.reset(); G.Cargo.reset(); G.Ship.showTubes(); // трюм пустеет, образцы снова на дне
    Game.done = false; updateCounts();
    if (Game.state === 'journal') renderJournal();
    Game.toast('Журнал очищен', 'Экспедиция начинается заново.');
  };
  Game.openJournal = function (focus) {
    if (Game.state !== 'play') return;
    Game.state = 'journal'; renderJournal(focus); $('journal').hidden = false; G.Audio.beep(520);
  };
  function closeJournal() { $('journal').hidden = true; Game.state = 'play'; clock.getDelta(); }
  function esc(s) { return String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }
  function renderJournal(focus) {
    const SP = G.SPECIES, c = counts();
    let h = `<div class="j-head"><div><div class="tag">Журнал экспедиции · Подлёдный сад</div><h2>Отмель</h2></div><button id="j-close" class="chip">Закрыть</button></div>
      <p class="j-sub">Изучено видов ${c.s} из ${c.sn} · найдено мест ${c.p} из ${c.pn}. Наблюдения записываются, когда существа взаимодействуют рядом с кораблём.</p>
      <h3>Существа</h3><div class="j-grid">`;
    G.SPECIES_ORDER.forEach(k => {
      const s = SP[k], total = Object.keys(s.notes).length;
      const notes = [...s.seen].map(n => `<li>${esc(s.notes[n])}</li>`).join('');
      h += `<article class="j-card ${s.scanned ? '' : 'unk'}" id="j-${k}"><h4>${s.scanned ? esc(s.name) : 'Неизвестный вид'}</h4>
        <p>${s.scanned ? esc(s.desc) : 'Наведите прицел на существо через иллюминатор и удерживайте кнопку действия.'}</p>
        ${notes ? `<div class="k">Наблюдения</div><ul>${notes}</ul>` : ''}<div class="j-prog">наблюдений ${s.seen.size} из ${total}</div></article>`;
    });
    h += '</div><h3>Места</h3><div class="j-grid">';
    G.World.pois.forEach(p => {
      h += `<article class="j-card ${p.found ? '' : 'unk'}"><h4>${p.found ? esc(p.name) : '???'}</h4><p>${p.found ? esc(p.desc) : (p.pinged ? 'Сонар засёк что-то необычное: фиолетовая метка «?» на голостоле.' : 'Ещё не найдено. Импульс сонара покажет необычные места поблизости.')}</p></article>`;
    });
    h += '</div><div class="j-foot"><button id="j-reset" class="chip warn" type="button">Сбросить прогресс</button><span id="j-reset-hint"></span></div>';
    $('journal-body').innerHTML = h;
    $('j-close').onclick = closeJournal;
    const rb = $('j-reset');
    rb.onclick = () => {
      if (rb.dataset.armed === '1') { Game.resetProgress(); return; }
      rb.dataset.armed = '1'; rb.textContent = 'Стереть журнал безвозвратно';
      $('j-reset-hint').textContent = 'Нажмите ещё раз в течение 4 секунд.';
      setTimeout(() => { if (rb.isConnected) { rb.dataset.armed = ''; rb.textContent = 'Сбросить прогресс'; $('j-reset-hint').textContent = ''; } }, 4000);
    };
    if (focus) { const el = $('j-' + focus); if (el) { el.classList.add('focus'); el.scrollIntoView({ block: 'center' }); } }
  }

  function bindUI() {
    $('b-start').onclick = () => {
      G.Audio.init();
      const el = document.documentElement;
      if (matchMedia('(pointer:coarse)').matches && el.requestFullscreen) {
        el.requestFullscreen().then(() => { if (screen.orientation && screen.orientation.lock) screen.orientation.lock('landscape').catch(() => {}); }).catch(() => {});
      }
      $('intro').hidden = true; $('hud').hidden = false;
      Game.state = 'play'; Game.player.yaw = 0; G.Eco.events.length = 0; clock.getDelta();
      if (G.Tutorial.done) Game.toast('Погружение началось', 'Журнал экспедиции продолжается.', 4000);
      G.Tutorial.render();
    };
    $('b-journal').onclick = () => Game.openJournal();
    $('s-net').onclick = () => G.Roles.cycle(); // смена роли в экипаже
    $('b-ar').onclick = () => (G.AR.active ? G.AR.stop() : G.AR.start(renderer));
    $('b-settings').onclick = () => { G.Audio.init(); G.Settings.open(); };
    $('b-feed').onclick = () => Game.toggleFeed();
    $('b-intro-settings').onclick = () => G.Settings.open();
    $('b-restart').onclick = restart;
    $('b-newrun').onclick = () => { G.Run.reset(); G.Power.reset(); G.Breach.reset(); G.Silt.reset(); G.Echo.reset(); G.Manip.reset(); G.Cargo.reset(); restart(); };
    if (G.Ctl.gyroAvailable()) {
      $('b-gyro').hidden = false;
      $('b-gyro').onclick = async () => {
        const on = await G.Ctl.toggleGyro();
        $('b-gyro').classList.toggle('on', on);
        if (on) setTimeout(() => { if (G.Ctl.gyro && !G.Ctl.gyroOK) { G.Ctl.toggleGyro(); $('b-gyro').classList.remove('on'); Game.toast('Гироскоп недоступен', 'Браузер не отдаёт данные датчиков. Откройте игру по ссылке https://'); } }, 1500);
      };
    }
  }

  window.addEventListener('load', () => {
    if (!window.THREE) { $('loading').textContent = 'Не удалось загрузить lib/three.min.js.'; return; }
    try { Game.init(); } catch (e) { $('loading').textContent = 'Ошибка запуска: ' + e.message; console.error(e); }
  });
  window.addEventListener('error', e => { const el = $('errbox'); if (el) { el.hidden = false; el.textContent = 'Ошибка: ' + e.message + ' (' + (e.filename || '').split('/').pop() + ':' + e.lineno + ')'; } });
})(window.G);
