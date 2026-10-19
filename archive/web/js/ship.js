'use strict';
/* Батискаф «Ковчег-7»: отсеки, посты, люки, физика движения.
   Корабльная система координат: нос смотрит в -Z, пол на y=0.
   Мостик z[-6,2], коридор z[2,8], лаборатория z[8,14]. */
(function (G) {
  const V3 = THREE.Vector3;
  const tv = new V3();
  const S = G.Ship = {
    start: new V3(0, -20, 95), pos: new V3(0, -20, 95), yaw: 0, speed: 0, vy: 0, turn: 0, roll: 0, pitch: 0,
    hull: 100, energy: 100, light: true, input: { thrust: 0, turn: 0, vert: 0 }, cargo: [], tubeOrbs: [],
    windows: [], inter: [], doors: [], obst: [], lights: [],
    center: new V3(), front: new V3(), hitCd: 0, flicker: 0, depthLimit: 0, scrT: 0
  };
  let g, M;

  function roundRectPath(p, x, y, w, h, r) {
    p.moveTo(x - w / 2 + r, y - h / 2);
    p.lineTo(x + w / 2 - r, y - h / 2); p.quadraticCurveTo(x + w / 2, y - h / 2, x + w / 2, y - h / 2 + r);
    p.lineTo(x + w / 2, y + h / 2 - r); p.quadraticCurveTo(x + w / 2, y + h / 2, x + w / 2 - r, y + h / 2);
    p.lineTo(x - w / 2 + r, y + h / 2); p.quadraticCurveTo(x - w / 2, y + h / 2, x - w / 2, y + h / 2 - r);
    p.lineTo(x - w / 2, y - h / 2 + r); p.quadraticCurveTo(x - w / 2, y - h / 2, x - w / 2 + r, y - h / 2);
    return p;
  }
  function panelGeo(w, h, holes, depth) {
    const s = new THREE.Shape();
    s.moveTo(-w / 2, 0); s.lineTo(w / 2, 0); s.lineTo(w / 2, h); s.lineTo(-w / 2, h); s.lineTo(-w / 2, 0);
    holes.forEach(o => {
      const p = new THREE.Path();
      if (!o.w) p.absarc(o.x, o.y, o.r, 0, Math.PI * 2, true); else roundRectPath(p, o.x, o.y, o.w, o.h, o.rr || 0.3);
      s.holes.push(p);
    });
    const geo = new THREE.ExtrudeGeometry(s, { depth, bevelEnabled: false, curveSegments: 20 });
    geo.translate(0, 0, -depth / 2);
    return geo;
  }
  function box(w, h, d, mat, x, y, z) { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat); m.position.set(x, y, z); g.add(m); return m; }
  function rectFrame(w, h) {
    const f = new THREE.Group();
    [[0, h / 2, w + 0.14, 0.08], [0, -h / 2, w + 0.14, 0.08]].forEach(([x, y, ww, hh]) => { const b = new THREE.Mesh(new THREE.BoxGeometry(ww, hh, 0.26), M.frame); b.position.set(x, y, 0); f.add(b); });
    [[-w / 2, 0], [w / 2, 0]].forEach(([x, y]) => { const b = new THREE.Mesh(new THREE.BoxGeometry(0.08, h, 0.26), M.frame); b.position.set(x, y, 0); f.add(b); });
    return f;
  }
  function addWindow(m, o, room, roomC) {
    let gGeo, frame;
    if (!o.w) { gGeo = new THREE.CircleGeometry(o.r, 32); frame = new THREE.Mesh(new THREE.TorusGeometry(o.r + 0.02, 0.07, 8, 36), M.frame); }
    else { gGeo = new THREE.ShapeGeometry(roundRectPath(new THREE.Shape(), 0, 0, o.w, o.h, o.rr || 0.3), 12); frame = rectFrame(o.w, o.h); }
    const glass = new THREE.Mesh(gGeo, M.glass); glass.position.set(o.x, o.y, 0); glass.renderOrder = 2; m.add(glass);
    frame.position.set(o.x, o.y, 0); m.add(frame);
    const q = m.quaternion;
    const c = new V3(o.x, o.y, 0).applyMatrix4(m.matrix);
    const n = new V3(0, 0, 1).applyQuaternion(q);
    if (n.dot(new V3().subVectors(roomC, c)) > 0) n.negate();
    S.windows.push({ c, n, u: new V3(1, 0, 0).applyQuaternion(q), v: new V3(0, 1, 0).applyQuaternion(q), r: o.w ? 0 : o.r, hw: o.w ? o.w / 2 : 0, hh: o.h ? o.h / 2 : 0, room });
  }
  function wall(w, h, holes, mat, pos, rot, room, roomC) {
    const m = new THREE.Mesh(panelGeo(w, h, holes, 0.2), mat);
    m.position.copy(pos); m.rotation.copy(rot); g.add(m); m.updateMatrix();
    holes.forEach(o => addWindow(m, o, room, roomC));
    return m;
  }
  function plight(color, intensity, dist, x, y, z) {
    const l = new THREE.PointLight(color, intensity, dist, 1); l.position.set(x, y, z); g.add(l);
    S.lights.push({ l, base: intensity });
    return l;
  }
  function screen(w, h, cw, ch, x, y, z, rx, ry) {
    const tex = G.canvasTex(cw, ch, () => {});
    const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ map: tex }));
    m.position.set(x, y, z); m.rotation.set(rx || 0, ry || 0, 0, 'YXZ'); g.add(m);
    return tex;
  }

  S.build = function (scene) {
    g = S.group = new THREE.Group(); scene.add(g);

    const panelTex = G.canvasTex(256, 256, (x, w, h) => {
      x.fillStyle = '#62808b'; x.fillRect(0, 0, w, h);
      for (let i = 0; i < 300; i++) { x.fillStyle = `rgba(0,0,0,${G.rr(0, 0.05).toFixed(3)})`; x.fillRect(G.rr(0, w), G.rr(0, h), G.rr(2, 30), G.rr(2, 30)); }
      x.strokeStyle = '#3c535c'; x.lineWidth = 3;
      [0, 128].forEach(v => { x.beginPath(); x.moveTo(v, 0); x.lineTo(v, h); x.stroke(); x.beginPath(); x.moveTo(0, v); x.lineTo(w, v); x.stroke(); });
      x.fillStyle = '#9fb4bb';
      for (let i = 8; i < 256; i += 20) [6, 134].forEach(v => { x.fillRect(v, i, 3, 3); x.fillRect(i, v, 3, 3); });
    });
    panelTex.wrapS = panelTex.wrapT = THREE.RepeatWrapping; panelTex.repeat.set(0.5, 0.5);
    const floorTex = G.canvasTex(128, 128, (x, w, h) => {
      x.fillStyle = '#1b262b'; x.fillRect(0, 0, w, h);
      x.strokeStyle = '#33444b'; x.lineWidth = 2;
      for (let i = 0; i <= w; i += 16) { x.beginPath(); x.moveTo(i, 0); x.lineTo(i, h); x.stroke(); x.beginPath(); x.moveTo(0, i); x.lineTo(w, i); x.stroke(); }
    });
    floorTex.wrapS = floorTex.wrapT = THREE.RepeatWrapping; floorTex.repeat.set(6, 6);
    const labFloorTex = floorTex.clone(); labFloorTex.needsUpdate = true; labFloorTex.repeat.set(0.75, 0.75);

    M = {
      wall: new THREE.MeshLambertMaterial({ color: 0xc4d6dc, map: panelTex }),
      wall2: new THREE.MeshLambertMaterial({ color: 0xdfeef2, map: panelTex }),
      floor: new THREE.MeshLambertMaterial({ map: floorTex }),
      labFloor: new THREE.MeshLambertMaterial({ map: labFloorTex }),
      ceil: new THREE.MeshLambertMaterial({ color: 0x2a3940 }),
      frame: new THREE.MeshLambertMaterial({ color: 0x8aa0a8 }),
      glass: new THREE.MeshBasicMaterial({ color: 0x9fe8ff, transparent: true, opacity: 0.06, depthWrite: false, side: THREE.DoubleSide }),
      dark: new THREE.MeshLambertMaterial({ color: 0x1f2b30 }),
      door: new THREE.MeshLambertMaterial({ color: 0x7f949b }),
      trim: new THREE.MeshBasicMaterial({ color: 0xffb259 }),
      lamp: new THREE.MeshBasicMaterial({ color: 0xffe2b8 }),
      cyan: new THREE.MeshBasicMaterial({ color: 0x5ef2d6 }),
      red: new THREE.MeshBasicMaterial({ color: 0xff5d6c })
    };
    const bridgeC = new V3(0, 1.6, -2), corrC = new V3(0, 1.3, 5), labC = new V3(0, 1.7, 11), engC = new V3(0, 1.6, 16.75), cargoC = new V3(0, 1.5, 21.75);
    const E0 = new THREE.Euler(0, 0, 0), EL = new THREE.Euler(0, Math.PI / 2, 0), ER = new THREE.Euler(0, -Math.PI / 2, 0);

    /* ----- полы и потолки ----- */
    box(10, 0.1, 8, M.floor, 0, -0.05, -2);
    box(2.2, 0.1, 6, M.floor, 0, -0.05, 5);
    wall(8, 6, [{ x: 0, y: 3, w: 3.2, h: 3.2, rr: 0.5 }], M.labFloor, new V3(0, -0.1, 14), new THREE.Euler(-Math.PI / 2, 0, 0), 'lab', labC);
    box(10, 0.1, 8, M.ceil, 0, 3.25, -2);
    box(2.2, 0.1, 6, M.ceil, 0, 2.65, 5);
    box(8, 0.1, 6, M.ceil, 0, 3.45, 11);
    box(6, 0.1, 5.5, M.floor, 0, -0.05, 16.75);
    box(6, 0.1, 5.5, M.ceil, 0, 3.25, 16.75);
    box(5, 0.1, 4.5, M.floor, 0, -0.05, 21.75);
    box(5, 0.1, 4.5, M.ceil, 0, 3.05, 21.75);

    /* ----- мостик ----- */
    wall(10, 3.2, [{ x: 0, y: 1.75, w: 7.6, h: 1.9, rr: 0.5 }], M.wall, new V3(0, 0, -6), E0, 'bridge', bridgeC);
    wall(8, 3.2, [{ x: 2.3, y: 1.65, r: 0.42 }], M.wall, new V3(-5, 0, -2), EL, 'bridge', bridgeC);
    wall(8, 3.2, [{ x: -2.3, y: 1.65, r: 0.42 }, { x: 1.2, y: 1.65, r: 0.42 }], M.wall, new V3(5, 0, -2), ER, 'bridge', bridgeC);
    box(4.2, 3.2, 0.2, M.wall, -2.9, 1.6, 2); box(4.2, 3.2, 0.2, M.wall, 2.9, 1.6, 2); box(1.6, 0.9, 0.2, M.wall, 0, 2.75, 2);
    [-5.2, -3, -1, 1].forEach(z => { box(0.18, 3.2, 0.28, M.frame, -4.86, 1.6, z); box(0.18, 3.2, 0.28, M.frame, 4.86, 1.6, z); });
    box(0.2, 0.04, 5, M.lamp, -2.5, 3.19, -2); box(0.2, 0.04, 5, M.lamp, 2.5, 3.19, -2);
    box(9.6, 0.05, 0.08, M.trim, 0, 0.03, -5.85);

    /* ----- коридор ----- */
    wall(6, 2.6, [{ x: -1.5, y: 1.5, r: 0.32 }, { x: 1.5, y: 1.5, r: 0.32 }], M.wall, new V3(-1.1, 0, 5), EL, 'corr', corrC);
    wall(6, 2.6, [{ x: -1.5, y: 1.5, r: 0.32 }, { x: 1.5, y: 1.5, r: 0.32 }], M.wall, new V3(1.1, 0, 5), ER, 'corr', corrC);
    box(0.15, 0.03, 5.6, M.lamp, 0, 2.59, 5);
    box(0.05, 0.02, 6, M.trim, -0.95, 0.01, 5); box(0.05, 0.02, 6, M.trim, 0.95, 0.01, 5);

    /* ----- лаборатория ----- */
    box(3.2, 3.4, 0.2, M.wall2, -2.4, 1.7, 8); box(3.2, 3.4, 0.2, M.wall2, 2.4, 1.7, 8); box(1.6, 1.1, 0.2, M.wall2, 0, 2.85, 8);
    wall(6, 3.4, [{ x: 0, y: 1.75, w: 3.6, h: 1.6, rr: 0.4 }], M.wall2, new V3(-4, 0, 11), EL, 'lab', labC);
    wall(6, 3.4, [{ x: 0, y: 1.75, w: 3.6, h: 1.6, rr: 0.4 }], M.wall2, new V3(4, 0, 11), ER, 'lab', labC);
    box(3.2, 3.4, 0.2, M.wall2, -2.4, 1.7, 14); box(3.2, 3.4, 0.2, M.wall2, 2.4, 1.7, 14); box(1.6, 1.1, 0.2, M.wall2, 0, 2.85, 14); // кормовая переборка с люком в машинное

    /* ----- машинное отделение ----- */
    wall(5.5, 3.2, [{ x: 0, y: 1.6, r: 0.32 }], M.wall, new V3(-3, 0, 16.75), EL, 'eng', engC);
    wall(5.5, 3.2, [{ x: 0.8, y: 1.6, r: 0.32 }], M.wall, new V3(3, 0, 16.75), ER, 'eng', engC);
    box(2.2, 3.2, 0.2, M.wall, -1.9, 1.6, 19.5); box(2.2, 3.2, 0.2, M.wall, 1.9, 1.6, 19.5); box(1.6, 0.9, 0.2, M.wall, 0, 2.75, 19.5); // корма машинного: люк в трюм

    /* ----- грузовой отсек (трюм) ----- */
    wall(4.5, 3, [], M.wall2, new V3(-2.5, 0, 21.75), EL, 'cargo', cargoC);
    wall(4.5, 3, [], M.wall2, new V3(2.5, 0, 21.75), ER, 'cargo', cargoC);
    wall(5, 3, [{ x: 0, y: 1.9, r: 0.3 }], M.wall2, new V3(0, 0, 24), E0, 'cargo', cargoC);
    box(0.15, 0.04, 3.8, M.lamp, 0, 2.99, 21.75);
    const slots = [];
    [-1, 1].forEach(sx => [0.55, 1.3, 2.05].forEach(y => { // полки вдоль бортов, на каждой по два-три образца
      box(0.55, 0.05, 3.6, M.frame, sx * 2.1, y, 21.9);
      [20.6, 21.4, 22.2, 23.0].forEach((z, k) => { if (slots.length < 24) slots.push(new V3(sx * 2.1, y + 0.19, z)); });
    }));
    S.obst.push({ x: -2.1, z: 21.9, r: 0.45 }, { x: 2.1, z: 21.9, r: 0.45 }, { x: -2.1, z: 20.6, r: 0.45 }, { x: 2.1, z: 20.6, r: 0.45 }, { x: -2.1, z: 23.2, r: 0.45 }, { x: 2.1, z: 23.2, r: 0.45 });
    G.Cargo.build(g, slots);
    box(1.2, 1.0, 0.45, M.dark, 0, 0.5, 23.6);
    S.cargoScreen = screen(1.0, 0.55, 256, 128, 0, 1.3, 23.36, -0.4, 0);
    (function (x) { x.fillStyle = '#04141b'; x.fillRect(0, 0, 256, 128); x.fillStyle = '#ffb259'; x.font = '600 20px monospace'; x.textAlign = 'center'; x.fillText('ТРЮМ', 128, 50); x.fillText('УЛУЧШЕНИЯ', 128, 82); x.strokeStyle = '#ffb259'; x.strokeRect(6, 6, 244, 116); })(S.cargoScreen.userData.ctx);
    S.cargoScreen.needsUpdate = true;
    S.obst.push({ x: 0, z: 23.6, r: 0.55 });
    S.inter.push({ x: 0, z: 22.8, r: 1.5, post: 'cargo', label: () => (G.Cargo.isOpen() ? 'Закрыть терминал' : 'Терминал трюма: улучшения'), fn: () => G.Cargo.toggle() });
    box(0.2, 0.04, 4.6, M.lamp, -2.2, 3.19, 16.75); box(0.2, 0.04, 4.6, M.lamp, 2.2, 3.19, 16.75);
    // реактор: тёмное основание, светящийся стержень в стеклянном кожухе, кольца охлаждения
    box(1.9, 0.3, 1.9, M.dark, 0, 0.15, 17.2);
    S.reactorCore = new THREE.Mesh(new THREE.CylinderGeometry(0.32, 0.32, 2.5, 16), new THREE.MeshBasicMaterial({ color: 0x6fe3ff }));
    S.reactorCore.position.set(0, 1.55, 17.2); g.add(S.reactorCore);
    const shellR = new THREE.Mesh(new THREE.CylinderGeometry(0.62, 0.62, 2.5, 20, 1, true), M.glass); shellR.position.set(0, 1.55, 17.2); g.add(shellR);
    [0.55, 1.55, 2.55].forEach(y => { const r = new THREE.Mesh(new THREE.TorusGeometry(0.66, 0.06, 6, 24), M.frame); r.rotation.x = Math.PI / 2; r.position.set(0, y, 17.2); g.add(r); });
    box(1.3, 0.25, 1.3, M.frame, 0, 2.95, 17.2);
    S.obst.push({ x: 0, z: 17.2, r: 1.05 });
    // пульт распределения энергии у правого борта
    box(0.5, 1.0, 1.4, M.dark, 2.7, 0.5, 15.6);
    S.powerScreen = screen(1.15, 0.85, 256, 192, 2.44, 1.45, 15.6, 0, -Math.PI / 2);
    S.obst.push({ x: 2.7, z: 15.6, r: 0.6 });
    S.inter.push({ x: 2.0, z: 15.6, r: 1.5, post: 'power', label: () => (G.Power.isOpen() ? 'Закрыть пульт энергии' : 'Распределить энергию'), fn: () => G.Power.toggle() });
    const ring = new THREE.Mesh(new THREE.TorusGeometry(1.6, 0.05, 6, 48), M.cyan); ring.rotation.x = Math.PI / 2; ring.position.set(0, 3.38, 11); g.add(ring);
    // колбы с образцами
    const tubeM = new THREE.MeshBasicMaterial({ color: 0x5ef2d6, transparent: true, opacity: 0.18, depthWrite: false });
    [[-3.3, 13.3], [-2.5, 13.4], [3.3, 9.0]].forEach(([x, z], i) => {
      box(0.6, 0.3, 0.6, M.dark, x, 0.15, z);
      const t = new THREE.Mesh(new THREE.CylinderGeometry(0.25, 0.25, 1.6, 16, 1, true), tubeM); t.position.set(x, 1.1, z); g.add(t);
      const o = new THREE.Mesh(new THREE.SphereGeometry(0.12, 8, 6), new THREE.MeshBasicMaterial({ color: [0xff7ad9, 0xffd36b, 0x7fe7ff][i] })); o.position.set(x, 1.1, z); g.add(o);
      o.userData.dynamic = true; o.visible = false; S.tubeOrbs.push(o); // колба пуста, пока манипулятор не достанет образец
      S.obst.push({ x, z, r: 0.4 });
    });

    /* ----- свет внутри ----- */
    plight(0xffcf96, 1.1, 13, 0, 2.9, -2.5);
    plight(0xffcf96, 0.7, 7, 0, 2.4, 5);
    plight(0x9fe8ff, 1.0, 12, 0, 3.1, 11);
    S.reactorLight = plight(0x6fe3ff, 0.9, 9, 0, 2.4, 17.2);

    /* ----- пост пилота ----- */
    box(1.9, 0.55, 0.55, M.dark, 0, 0.275, -5.6);
    box(1.3, 0.66, 0.06, M.dark, 0, 0.7, -5.58).rotation.x = -1.1;
    S.helmScreen = screen(1.15, 0.57, 256, 128, 0, 0.725, -5.56, -1.1, 0);
    S.wheel = new THREE.Group();
    const wr = new THREE.Mesh(new THREE.TorusGeometry(0.28, 0.035, 8, 28), M.frame); S.wheel.add(wr);
    [0, Math.PI / 2].forEach(a => { const sp = new THREE.Mesh(new THREE.BoxGeometry(0.56, 0.03, 0.03), M.frame); sp.rotation.z = a; S.wheel.add(sp); });
    S.wheel.position.set(0, 0.72, -5.05); S.wheel.rotation.x = -0.6; S.wheel.scale.setScalar(0.85); g.add(S.wheel);
    [[-0.7, M.trim], [0.7, M.red]].forEach(([x, m]) => { box(0.05, 0.35, 0.05, M.frame, x, 0.7, -5.25); box(0.1, 0.1, 0.1, m, x, 0.88, -5.25); });
    box(0.6, 0.1, 0.6, M.dark, 0, 0.5, -4.05); box(0.6, 0.7, 0.08, M.dark, 0, 0.9, -3.75); box(0.12, 0.5, 0.12, M.frame, 0, 0.25, -4.05);
    S.obst.push({ x: 0, z: -5.5, r: 1.0 }, { x: 0, z: -3.95, r: 0.35 });
    S.inter.push({ x: 0, z: -4.3, r: 1.7, post: 'helm', label: () => 'Сесть за штурвал', fn: () => G.Game.toggleHelm() });

    /* ----- голостол сонара ----- */
    const tb = new THREE.Mesh(new THREE.CylinderGeometry(1.1, 1.25, 0.95, 28), M.dark); tb.position.set(0, 0.475, -1.2); g.add(tb);
    const rim = new THREE.Mesh(new THREE.TorusGeometry(1.08, 0.035, 6, 48), M.cyan); rim.rotation.x = Math.PI / 2; rim.position.set(0, 0.96, -1.2); g.add(rim);
    const holo = new THREE.Mesh(new THREE.CircleGeometry(1.02, 48), new THREE.MeshBasicMaterial({ map: G.Sonar.tex, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    holo.rotation.x = -Math.PI / 2; holo.position.set(0, 1.0, -1.2); g.add(holo);
    const col = new THREE.Mesh(new THREE.CylinderGeometry(1.0, 1.0, 0.7, 32, 1, true), new THREE.MeshBasicMaterial({ color: 0x5ef2d6, transparent: true, opacity: 0.05, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
    col.position.set(0, 1.36, -1.2); g.add(col);
    S.obst.push({ x: 0, z: -1.2, r: 1.2 });
    S.inter.push({ x: 0, z: -1.2, r: 2.2, post: 'sonar', label: () => (S.energy >= 6 ? 'Сонар: импульс' : 'Сонар: мало энергии'), ok: () => S.energy >= 6, fn: () => G.Sonar.ping() });
    S.inter.push({ x: -1.9, z: -1.2, r: 0.9, label: () => (G.Run.isOpen() ? 'Закрыть брифинг' : G.Run.done ? 'Голосование: глубже или наверх' : G.Run.route ? 'Брифинг: сменить маршрут' : 'Брифинг: выбрать маршрут'), fn: () => (G.Run.done ? G.Run.openVote() : G.Run.toggle()) }); // левый край голостола

    /* ----- пульт инженера (левый борт) ----- */
    box(0.25, 1.6, 1.7, M.dark, -4.85, 1.35, -0.6);
    S.engScreen = screen(1.15, 1.15, 256, 256, -4.71, 1.55, -0.6, 0, Math.PI / 2);
    S.lever = new THREE.Group();
    const lh = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.45, 6), M.frame); lh.position.y = 0.22; S.lever.add(lh);
    const lb = new THREE.Mesh(new THREE.SphereGeometry(0.07, 8, 6), M.red); lb.position.y = 0.45; S.lever.add(lb);
    S.lever.position.set(-4.68, 0.75, 0.15); g.add(S.lever);
    S.inter.push({ x: -4.2, z: -0.6, r: 1.5, post: 'zap', label: () => 'Разряд по корпусу', ok: () => S.energy >= 15, fn: () => G.Game.zap() });

    /* ----- пульт лаборатории ----- */
    box(1.0, 0.95, 0.6, M.dark, 2.9, 0.475, 12.9);
    const labTex = screen(0.9, 0.5, 256, 128, 2.9, 1.2, 12.75, -0.5, 0);
    (function (x) { x.fillStyle = '#04141b'; x.fillRect(0, 0, 256, 128); x.fillStyle = '#5ef2d6'; x.font = '600 22px monospace'; x.textAlign = 'center'; x.fillText('ЖУРНАЛ', 128, 54); x.fillText('ЭКСПЕДИЦИИ', 128, 84); x.strokeStyle = '#5ef2d6'; x.strokeRect(6, 6, 244, 116); })(labTex.userData.ctx);
    labTex.needsUpdate = true;
    S.obst.push({ x: 2.9, z: 12.9, r: 0.65 });
    S.inter.push({ x: 2.9, z: 12.6, r: 1.6, label: () => 'Открыть журнал', fn: () => G.Game.openJournal() });

    /* ----- люки ----- */
    [2, 8, 14, 19.5].forEach(z => {
      const d = new THREE.Mesh(new THREE.BoxGeometry(1.6, 2.3, 0.08), M.door); d.position.set(0, 1.15, z); g.add(d);
      const st = new THREE.Mesh(new THREE.BoxGeometry(1.6, 0.08, 0.1), M.trim); st.position.y = 0.2; d.add(st);
      const wnd = new THREE.Mesh(new THREE.CircleGeometry(0.16, 20), M.cyan); wnd.position.set(0, 0.55, 0.05); d.add(wnd);
      const wnd2 = wnd.clone(); wnd2.position.z = -0.05; wnd2.rotation.y = Math.PI; d.add(wnd2);
      [-0.84, 0.84].forEach(x => box(0.06, 2.3, 0.26, M.trim, x, 1.15, z));
      box(1.74, 0.06, 0.26, M.trim, 0, 2.33, z);
      const door = { mesh: d, z, open: false, t: 0 };
      S.doors.push(door);
      S.inter.push({ x: 0, z, r: 1.5, label: () => (door.open ? 'Закрыть люк' : 'Открыть люк'), fn: () => { door.open = !door.open; G.Audio.door(); } });
    });

    /* ----- прожектор ----- */
    S.spot = new THREE.SpotLight(0xe6fbff, 0, 120, 0.45, 0.6, 1);
    S.spot.position.set(0, 0.8, -6.8); g.add(S.spot);
    const tgt = new THREE.Object3D(); tgt.position.set(0, -10, -40); g.add(tgt); S.spot.target = tgt;
    const bg = new THREE.CylinderGeometry(0.3, 13, 55, 24, 1, true); bg.translate(0, -27.5, 0);
    const bp = bg.attributes.position, bc = new Float32Array(bp.count * 3);
    for (let i = 0; i < bp.count; i++) { const k = 1 + bp.getY(i) / 55; const v = k * k * 0.9 + 0.1 * k; bc[i * 3] = bc[i * 3 + 1] = bc[i * 3 + 2] = v; }
    bg.setAttribute('color', new THREE.BufferAttribute(bc, 3));
    S.beam = new THREE.Mesh(bg, new THREE.MeshBasicMaterial({ color: 0xcff6ff, vertexColors: true, transparent: true, opacity: 0.06, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false }));
    S.beam.position.copy(S.spot.position);
    S.beam.quaternion.setFromUnitVectors(new V3(0, -1, 0), new V3(0, -10, -40).sub(S.spot.position).normalize());
    g.add(S.beam);

    /* ----- пробоины: трещина, струя, вода, место для сварки ----- */
    G.Breach.build(g);
    G.Breach.SPOTS.forEach(spot => S.inter.push({ x: spot.at.x, z: spot.at.z, r: 1.4, on: () => G.Breach.active === spot,
      label: () => 'Заварить пробоину (держать)', holdFn: dt => G.Breach.holdWeld(dt), prog: () => G.Breach.progress(), fn: () => {} }));

    S.mergeStatic();
    S.reset();
  };

  /* Слить неподвижные детали отсеков с одинаковым материалом в один меш: меньше вызовов отрисовки.
     Подвижное (люки, штурвал, рычаг, экраны, прожектор) помечается userData.dynamic и не трогается. */
  S.mergeStatic = function () {
    [S.wheel, S.lever, S.beam, S.spot, S.reactorCore].concat(S.doors.map(d => d.mesh)).forEach(o => o && o.traverse(c => { c.userData.dynamic = true; }));
    const canvasMaps = new Set([S.helmScreen, S.engScreen, S.powerScreen, S.cargoScreen].filter(Boolean));
    const groups = new Map();
    g.traverse(o => {
      if (!o.isMesh || o.userData.dynamic || o.isInstancedMesh || Array.isArray(o.material)) return;
      if (o.material.map && (canvasMaps.has(o.material.map) || o.material.map === G.Sonar.tex)) return;
      if (!groups.has(o.material)) groups.set(o.material, []);
      groups.get(o.material).push(o);
    });
    let removed = 0;
    groups.forEach(list => { if (G.mergeMeshes(list, g)) removed += list.length; });
    S.merged = removed;
  };

  const FOOT = [[0, -6.6], [-5, -6], [5, -6], [-5, 2], [5, 2], [-1.1, 8], [1.1, 8], [-4, 14], [4, 14], [0, 11]];
  S.clearance = function (px, pz, yaw) {
    let m = -1e9; const c = Math.cos(yaw), s = Math.sin(yaw);
    for (const [lx, lz] of FOOT) m = Math.max(m, G.World.height(px + lx * c + lz * s, pz - lx * s + lz * c));
    return m;
  };
  /* Объём корпуса в корабельных координатах: коробки отсеков по внешним граням стен
     [x0, x1, y0, y1, z0, z1]. Существа не заходят внутрь: S.pushOut выталкивает их наружу. */
  const HULL = S.HULL = [
    [-5.1, 5.1, -0.15, 3.3, -6.1, 2.1],   // мостик
    [-1.2, 1.2, -0.15, 2.7, 2.1, 8.1],    // коридор
    [-4.1, 4.1, -0.2, 3.5, 7.9, 14.1],    // лаборатория
    [-3.1, 3.1, -0.15, 3.3, 14.1, 19.6],  // машинное отделение
    [-2.6, 2.6, -0.15, 3.1, 19.6, 24.1]   // трюм
  ];
  const hInv = new THREE.Matrix4(), hl = new V3(), hq = new V3(), hn = new V3();
  const inBox = (b, x, y, z, r) => x > b[0] - r && x < b[1] + r && y > b[2] - r && y < b[3] + r && z > b[4] - r && z < b[5] + r;
  const inHull = (x, y, z, r) => HULL.some(b => inBox(b, x, y, z, r));
  /* расстояние от точки (мир) до корпуса: >0 снаружи, ≤0 внутри */
  S.hullDist = function (p) {
    hl.copy(p).applyMatrix4(hInv);
    let best = 1e9;
    for (const b of HULL) {
      const dx = Math.max(b[0] - hl.x, hl.x - b[1]), dy = Math.max(b[2] - hl.y, hl.y - b[3]), dz = Math.max(b[4] - hl.z, hl.z - b[5]);
      const d = dx > 0 || dy > 0 || dz > 0 ? Math.hypot(Math.max(dx, 0), Math.max(dy, 0), Math.max(dz, 0)) : Math.max(dx, dy, dz);
      if (d < best) best = d;
    }
    return best;
  };
  /* вытолкнуть точку p (мир) из корпуса с запасом r; v — скорость: её часть внутрь корпуса гасится.
     Возвращает true, если точка была внутри. */
  S.pushOut = function (p, r, v) {
    if (p.distanceToSquared(S.center) > (22 + r) * (22 + r)) return false;
    hl.copy(p).applyMatrix4(hInv);
    let moved = false;
    for (let it = 0; it < 4; it++) { // на стыке отсеков точка может попасть из одного в другой — повторить
      const b = HULL.find(bx => inBox(bx, hl.x, hl.y, hl.z, r));
      if (!b) break;
      /* грани коробки по глубине проникновения; берём ближайшую, за которой нет соседнего отсека */
      const faces = [[0, -1, hl.x - b[0] + r], [0, 1, b[1] + r - hl.x], [1, -1, hl.y - b[2] + r], [1, 1, b[3] + r - hl.y], [2, -1, hl.z - b[4] + r], [2, 1, b[5] + r - hl.z]].sort((a, c) => a[2] - c[2]);
      let face = faces[0];
      for (const f of faces) {
        hq.copy(hl).setComponent(f[0], hl.getComponent(f[0]) + f[1] * (f[2] + 0.01));
        if (!inHull(hq.x, hq.y, hq.z, r)) { face = f; break; }
      }
      hl.setComponent(face[0], hl.getComponent(face[0]) + face[1] * (face[2] + 0.01));
      if (v) {
        hn.set(0, 0, 0).setComponent(face[0], face[1]).applyQuaternion(g.quaternion);
        const vn = v.dot(hn); if (vn < 0) v.addScaledVector(hn, -vn);
      }
      moved = true;
    }
    if (!moved) return false;
    p.copy(hl).applyMatrix4(g.matrixWorld);
    return true;
  };
  /* пересекает ли отрезок a–b (корабельные координаты) корпус с запасом r */
  function segHits(a, b, r) {
    for (const bx of HULL) {
      let t0 = 0, t1 = 1, hit = true;
      for (let k = 0; k < 3 && hit; k++) {
        const o = a.getComponent(k), d = b.getComponent(k) - o, lo = bx[k * 2] - r, hi = bx[k * 2 + 1] + r;
        if (Math.abs(d) < 1e-9) { if (o <= lo || o >= hi) hit = false; continue; }
        let u0 = (lo - o) / d, u1 = (hi - o) / d; if (u0 > u1) { const s = u0; u0 = u1; u1 = s; }
        t0 = Math.max(t0, u0); t1 = Math.min(t1, u1); if (t0 >= t1) hit = false;
      }
      if (hit) return true;
    }
    return false;
  }
  const dA = new V3(), dB = new V3();
  /* обход корпуса: если прямой путь от p к goal идёт сквозь корабль, вернуть точку сбоку от него
     (в out), иначе сам goal. Существо плывёт вдоль борта и сворачивает к цели за кораблём. */
  S.detour = function (p, goal, r, out) {
    if (p.distanceToSquared(S.center) > 900) return goal;
    dA.copy(p).applyMatrix4(hInv); dB.copy(goal).applyMatrix4(hInv);
    if (!segHits(dA, dB, r)) return goal;
    const side = dA.x < 0 ? -1 : 1, fwd = dB.z < dA.z;
    let z = dA.z + (fwd ? -6 : 6);
    if (fwd ? z < dB.z : z > dB.z) z = dB.z + (fwd ? -1 : 1);
    return out.set(side * (5.5 + r + 0.6), dA.y, z).applyMatrix4(g.matrixWorld);
  };
  S.reset = function () {
    S.pos.copy(S.start); S.yaw = 0;
    S.pos.y = Math.min(-9, S.clearance(S.pos.x, S.pos.z, 0) + 9);
    S.speed = S.vy = S.turn = S.roll = S.pitch = 0;
    S.hull = 100; S.energy = 100; S.light = true; S.cargo.length = 0; if (S.showTubes && G.Manip.KIND) S.showTubes(); if (G.Cargo.shelves) G.Cargo.shelves();
    S.input.thrust = S.input.turn = S.input.vert = 0;
    S.applyTransform();
  };
  S.applyTransform = function () {
    g.position.copy(S.pos); g.rotation.set(S.pitch, S.yaw, S.roll, 'YXZ'); g.updateMatrixWorld(true);
    S.center.set(0, 1.5, 4); g.localToWorld(S.center);
    S.front.set(0, 1.8, -6.6); g.localToWorld(S.front);
    hInv.copy(g.matrixWorld).invert();
  };

  /* Можно ли стоять игроку в точке (x,z) корабельных координат */
  /* в колбах лаборатории — три последних образца */
  S.showTubes = function () {
    if (G.Cargo.shelves) G.Cargo.shelves();
    const last = S.cargo.slice(-S.tubeOrbs.length);
    S.tubeOrbs.forEach((o, i) => { const c = last[i]; o.visible = !!c; if (c) o.material.color.set(G.Manip.KIND[c.kind].color); });
  };
  /* экран пульта энергии в машинном отделении */
  S.drawPower = function () {
    if (!S.powerScreen) return;
    const x = S.powerScreen.userData.ctx, P = G.Power;
    x.fillStyle = '#04141b'; x.fillRect(0, 0, 256, 192);
    x.strokeStyle = '#5ef2d6'; x.strokeRect(4, 4, 248, 184);
    x.fillStyle = P.hot ? '#ff5d6c' : '#5ef2d6'; x.font = '600 16px monospace'; x.textAlign = 'left'; x.fillText(P.scram > 0 ? 'АВАРИЙНЫЙ СБРОС' : P.hot ? 'ПЕРЕГРЕВ ' + Math.round(P.heat) + '° · ' + P.used() + '/' + P.SAFE : 'РЕАКТОР ' + P.used() + '/' + P.TOTAL, 14, 26);
    P.KEYS.forEach((k, i) => {
      const y = 46 + i * 28;
      x.fillStyle = '#9fb4bb'; x.font = '13px monospace'; x.fillText(P.NAME[k].slice(0, 12).toUpperCase(), 14, y + 12);
      x.fillStyle = '#16323b'; x.fillRect(130, y, 110, 16);
      x.fillStyle = P.v[k] ? '#ffb259' : '#ff5d6c'; x.fillRect(130, y, 110 * P.v[k] / P.MAX, 16);
    });
    S.powerScreen.needsUpdate = true;
  };
  S.canStand = function (x, z) {
    const r = 0.35; let ok = false;
    if (x > -5 + r && x < 5 - r && z > -6 + r && z < 2 - r) ok = true;
    else if (x > -1.1 + r && x < 1.1 - r) {
      if (z >= 2.45 && z <= 7.55) ok = true;
      else if (z > 1.4 && z < 2.6 && S.doors[0].t > 0.85) ok = true;
      else if (z > 7.4 && z < 8.6 && S.doors[1].t > 0.85) ok = true;
    }
    if (!ok && x > -4 + r && x < 4 - r && z > 8 + r && z < 14 - r) ok = true;
    if (!ok && x > -3 + r && x < 3 - r && z > 14 + r && z < 19.5 - r) ok = true; // машинное отделение
    if (!ok && x > -1.1 + r && x < 1.1 - r && z > 13.4 && z < 14.6 && S.doors[2].t > 0.85) ok = true;
    if (!ok && x > -2.5 + r && x < 2.5 - r && z > 19.5 + r && z < 24 - r) ok = true; // трюм
    if (!ok && x > -1.1 + r && x < 1.1 - r && z > 18.9 && z < 20.1 && S.doors[3].t > 0.85) ok = true;
    if (!ok) return false;
    for (const o of S.obst) if (Math.hypot(x - o.x, z - o.z) < o.r + r) return false;
    return true;
  };
  S.roomAt = z => (z < 1.9 ? 'bridge' : z < 8 ? 'corr' : z < 14 ? 'lab' : z < 19.5 ? 'eng' : 'cargo');

  /* Проходит ли взгляд (из точки p в направлении d, всё в координатах корабля) через иллюминатор */
  S.throughWindow = function (p, d, room) {
    for (const w of S.windows) {
      if (w.room !== room) continue;
      const dn = d.dot(w.n); if (dn <= 0.05) continue;
      const t = tv.copy(w.c).sub(p).dot(w.n) / dn;
      if (t < 0 || t > 14) continue;
      const hx = p.x + d.x * t - w.c.x, hy = p.y + d.y * t - w.c.y, hz = p.z + d.z * t - w.c.z;
      const a = hx * w.u.x + hy * w.u.y + hz * w.u.z, b = hx * w.v.x + hy * w.v.y + hz * w.v.z;
      if (w.r ? a * a + b * b < w.r * w.r : Math.abs(a) < w.hw && Math.abs(b) < w.hh) return true;
    }
    return false;
  };

  S.update = function (dt, t) {
    const inp = S.input, en = S.energy > 2, k = (en ? 1 : 0.25) * G.Power.k('eng'); // доля двигателей в реакторе
    const drag = 0.45 + 0.025 * (G.Eco.hullRemoras || 0); // прилипалы на корпусе тормозят
    S.speed += (inp.thrust * (inp.thrust < 0 ? 1.6 : 3.0) * k - S.speed * drag) * dt;
    S.turn += (inp.turn - S.turn) * Math.min(1, dt * 2.5);
    S.yaw -= S.turn * 0.42 * dt;
    S.vy += (inp.vert * 2.6 * k - S.vy) * Math.min(1, dt * 1.6);
    const px = S.pos.x, pz = S.pos.z;
    S.pos.x += -Math.sin(S.yaw) * S.speed * dt;
    S.pos.z += -Math.cos(S.yaw) * S.speed * dt;
    S.pos.y += S.vy * dt;
    if (G.Eco.current) { S.pos.x += G.Eco.current.x * dt; S.pos.z += G.Eco.current.z * dt; } // течение сносит корабль
    S.pos.x = G.clamp(S.pos.x, -300, 300); S.pos.z = G.clamp(S.pos.z, -300, 300);
    if (S.pos.y > -5) { S.pos.y = -5; if (S.vy > 0) S.vy = 0; }
    if (S.pos.y < -96) { S.pos.y = -96; if (S.vy < 0) S.vy = 0; S.depthLimit = 1.5; }

    S.hitCd -= dt;
    let req = S.clearance(S.pos.x, S.pos.z, S.yaw) + 1.2;
    if (req > -5) { // дальше не пролезть
      S.pos.x = px; S.pos.z = pz;
      if (Math.abs(S.speed) > 2 && S.hitCd <= 0) { S.hitCd = 1.2; G.Game.hullHit(Math.round(Math.abs(S.speed) * 1.4), 'scrape'); }
      S.speed *= -0.2;
      req = S.clearance(S.pos.x, S.pos.z, S.yaw) + 1.2;
    }
    if (S.pos.y < req) {
      if (req - S.pos.y > 0.6 && Math.abs(S.speed) > 2.4 && S.hitCd <= 0) { S.hitCd = 1.2; G.Game.hullHit(Math.round(Math.abs(S.speed) * 1.4), 'scrape'); S.speed *= -0.25; }
      S.pos.y = Math.min(req, -5); if (S.vy < 0) S.vy = 0;
    }
    for (const o of G.World.obstacles) {
      const dx = S.pos.x - o.x, dz = S.pos.z - o.z, d = Math.hypot(dx, dz), minD = o.r + 6;
      if (d < minD && S.pos.y < o.top && d > 0.01) {
        S.pos.x = o.x + dx / d * minD; S.pos.z = o.z + dz / d * minD;
        if (Math.abs(S.speed) > 2.4 && S.hitCd <= 0) { S.hitCd = 1.2; G.Game.hullHit(Math.round(Math.abs(S.speed) * 1.4), 'scrape'); }
        S.speed *= 0.5;
      }
    }

    const tilt = G.Settings.comfort() ? 0 : 1; // защита от укачивания: горизонт не заваливается
    S.roll += (-S.turn * 0.06 * Math.min(1, Math.abs(S.speed) / 3 + 0.3) * tilt - S.roll) * Math.min(1, dt * 2);
    S.pitch += (S.vy * 0.012 * tilt - S.pitch) * Math.min(1, dt * 2);
    S.applyTransform();

    // энергия и корпус
    let drain = Math.abs(inp.thrust) * 0.35 + Math.abs(inp.vert) * 0.15 + (S.light ? 0.22 : 0);
    if (G.Eco.latched) drain += 3.2;
    S.energy = G.clamp(S.energy + ((G.Cargo.has('batt') ? 1.54 : 1.1) - drain) * dt, 0, 100); // живые аккумуляторы из мха
    if (S.energy <= 0.5 && S.light) { S.light = false; G.Game.toast('Прожектор погас', 'Не хватает энергии'); }
    if (S.light && G.Power.k('lamp') <= 0) { S.light = false; G.Game.toast('Прожектор обесточен', G.Power.scram > 0 ? 'Аварийный сброс реактора' : 'В машинном отделении у прожектора 0 единиц'); }
    G.Power.update(dt, t);
    if (S.reactorCore) { // стержень краснеет от перегрева и гаснет при аварийном сбросе
      const P = G.Power, h = P.heat / 100, pulse = 0.75 + 0.25 * Math.sin(t * (2.2 + h * 6)), off = P.scram > 0 ? 0.15 : 1;
      S.reactorCore.material.color.setRGB((0.3 + 0.7 * h) * pulse * off, (0.8 - 0.6 * h) * pulse * off + 0.05, (0.95 - 0.8 * h) * off);
      S.reactorLight.color.setRGB(0.4 + 0.6 * h, 0.9 - 0.6 * h, 1 - 0.8 * h); S.reactorLight.intensity = (0.7 + 0.3 * pulse) * off;
    }
    if (S.hull > 0 && S.hull < 100) S.hull = Math.min(100, S.hull + dt * 0.15 * G.Power.k('life')); // жизнеобеспечение чинит корпус

    // свет
    S.flicker = Math.max(0, S.flicker - dt);
    const fl = (G.Eco.latched || S.flicker > 0) ? (G.rng() < 0.25 ? 0.15 : 1) : 1;
    S.lights.forEach(o => { o.l.intensity = o.base * fl; });
    G.Breach.update(dt, t); // пробоина: вода, сирена, красный свет поверх обычного
    G.Manip.update(dt);
    const on = S.light && S.energy > 0.5;
    S.spot.intensity = on ? 2.8 * fl : 0;
    S.beam.visible = on;
    if (on) { const bk = Math.sqrt(Math.max(0.25, G.Power.k('lamp'))); S.beam.scale.set(bk, bk, bk); S.spot.distance = 120 * bk; }

    // люки, штурвал, рычаг
    S.doors.forEach(d => { d.t = G.clamp(d.t + (d.open ? 1 : -1) * dt * 1.8, 0, 1); d.mesh.position.x = G.smooth(0, 1, d.t) * 1.75; });
    S.wheel.rotation.z = -S.turn * 1.4;
    S.lever.rotation.z = S.flicker > 0 ? -0.9 : 0;

    S.scrT -= dt;
    if (S.scrT <= 0) { S.scrT = 0.25; drawScreens(); }
  };

  function drawScreens() {
    let x = S.helmScreen.userData.ctx;
    x.fillStyle = '#04141b'; x.fillRect(0, 0, 256, 128);
    const hdg = Math.round(((-S.yaw * 180 / Math.PI) % 360 + 360) % 360);
    x.strokeStyle = 'rgba(255,178,89,.6)'; x.lineWidth = 2; x.beginPath();
    for (let a = -60; a <= 60; a += 10) { const deg = ((Math.round(hdg / 10) * 10 + a) % 360 + 360) % 360; const px = 128 + (deg - hdg + (Math.abs(deg - hdg) > 180 ? (deg > hdg ? -360 : 360) : 0)) * 1.8; x.moveTo(px, 10); x.lineTo(px, deg % 30 === 0 ? 26 : 18); }
    x.stroke();
    x.fillStyle = '#ffb259'; x.font = '600 20px monospace'; x.textAlign = 'center'; x.fillText(String(hdg).padStart(3, '0') + '°', 128, 48);
    x.textAlign = 'left'; x.font = '600 17px monospace';
    x.fillStyle = '#d8e8ea'; x.fillText('ГЛУБ ' + Math.round(-S.pos.y) + ' м', 12, 80); x.fillText('СКОР ' + Math.abs(S.speed).toFixed(1), 12, 108);
    x.fillStyle = S.light ? '#5ef2d6' : '#86a3aa'; x.fillText(S.light ? 'СВЕТ ВКЛ' : 'СВЕТ ВЫКЛ', 150, 80);
    x.fillStyle = S.energy < 20 ? '#ff5d6c' : '#5ef2d6'; x.fillText('ЭН ' + Math.round(S.energy), 150, 108);
    S.helmScreen.needsUpdate = true;

    x = S.engScreen.userData.ctx;
    x.fillStyle = '#04141b'; x.fillRect(0, 0, 256, 256);
    x.fillStyle = '#ffb259'; x.font = '600 18px monospace'; x.textAlign = 'left'; x.fillText('РЕАКТОР И КОРПУС', 14, 30);
    [['КОРПУС', S.hull], ['ЭНЕРГИЯ', S.energy]].forEach(([n, v], i) => {
      const y = 62 + i * 52; x.fillStyle = '#86a3aa'; x.font = '600 15px monospace'; x.fillText(n + ' ' + Math.round(v) + '%', 14, y);
      x.fillStyle = '#123240'; x.fillRect(14, y + 8, 228, 14); x.fillStyle = v < 25 ? '#ff5d6c' : v < 50 ? '#ffb259' : '#5ef2d6'; x.fillRect(14, y + 8, 228 * v / 100, 14);
    });
    x.font = '600 15px monospace'; x.fillStyle = '#d8e8ea'; x.fillText('РАЗРЯД: 15 ед.', 14, 186);
    if (G.Eco.latched) { x.fillStyle = (Date.now() / 300 | 0) % 2 ? '#ff5d6c' : '#04141b'; x.fillRect(8, 200, 240, 44); x.fillStyle = '#fff'; x.fillText('СТЕКЛОУСТ НА КОРПУСЕ', 18, 228); }
    S.engScreen.needsUpdate = true;
  }
})(window.G);
