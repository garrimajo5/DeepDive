'use strict';
/* Событие «пробоина». Сильный удар (укус серпохвоста, таран дна на скорости) пробивает борт:
   из трещины бьёт струя, отсек заливает водой, корпус слабеет, воет сирена и мигает красный свет.
   Трещину заваривают, удерживая кнопку действия у неё. Потом насосы откачивают воду;
   их скорость зависит от доли жизнеобеспечения в реакторе. */
(function (G) {
  const V3 = THREE.Vector3;
  const HIT_MIN = 10, COOLDOWN = 45, WELD_RATE = 28, WATER_RISE = 0.016, WATER_MAX = 0.55, PUMP = 0.02, HULL_DRAIN = 0.6, HULL_FLOOR = 15, SPRAY = 160;
  /* места пробоин в координатах корабля: точка на внутренней поверхности стены (стены толщиной 0,2 м), нормаль внутрь отсека, где стоять со сваркой */
  const SPOTS = [
    { room: 'bridge', name: 'мостик', p: new V3(-4.88, 1.0, -3.4), n: new V3(1, 0, 0), at: { x: -4.0, z: -3.4 }, floor: { x: 0, z: -2, w: 10, d: 8 } },
    { room: 'corr', name: 'коридор', p: new V3(0.98, 1.0, 5.0), n: new V3(-1, 0, 0), at: { x: 0.2, z: 5.0 }, floor: { x: 0, z: 5, w: 2.2, d: 6 } },
    { room: 'lab', name: 'лаборатория', p: new V3(-2.6, 1.0, 8.12), n: new V3(0, 0, 1), at: { x: -2.6, z: 8.9 }, floor: { x: 0, z: 11, w: 8, d: 6 } },
    { room: 'eng', name: 'машинное отделение', p: new V3(-2.88, 1.0, 18.6), n: new V3(1, 0, 0), at: { x: -2.1, z: 18.6 }, floor: { x: 0, z: 16.75, w: 6, d: 5.5 } }
  ];
  const B = G.Breach = { SPOTS, active: null, count: 0, cd: 0, weld: 0, welding: false, water: 0, waterRoom: null, t: 0, msgCd: 0 };

  function crackTex(mode) {
    const x = B.crackCtx; x.clearRect(0, 0, 256, 170);
    x.lineCap = 'round';
    x.beginPath(); B.path.forEach(([px, py], i) => (i ? x.lineTo(px, py) : x.moveTo(px, py)));
    if (mode === 'active') {
      x.shadowColor = '#ff3040'; x.shadowBlur = 14; x.strokeStyle = 'rgba(255,70,80,.95)'; x.lineWidth = 7; x.stroke();
      x.shadowBlur = 0; x.strokeStyle = '#e9feff'; x.lineWidth = 2; x.stroke();
    } else {
      x.strokeStyle = '#4a5559'; x.lineWidth = 8; x.stroke();
      x.strokeStyle = '#ffb259'; x.lineWidth = 2; x.setLineDash([4, 5]); x.stroke(); x.setLineDash([]);
    }
    B.crackTexObj.needsUpdate = true;
  }
  function pts(n, size, color, add) {
    const g = new THREE.BufferGeometry(), a = new Float32Array(n * 3).fill(-999);
    g.setAttribute('position', new THREE.BufferAttribute(a, 3));
    const m = new THREE.Points(g, new THREE.PointsMaterial({ size, color, transparent: true, opacity: 0.85, depthWrite: false, blending: add ? THREE.AdditiveBlending : THREE.NormalBlending }));
    m.frustumCulled = false; m.visible = false; m.userData.dynamic = true;
    return { m, a, v: new Float32Array(n * 3), life: new Float32Array(n), n };
  }
  B.build = function (group) {
    B.path = []; let y = 85; for (let x = 20; x <= 236; x += 12) { y += Math.sin(x * 0.37) * 14 + Math.cos(x * 0.11) * 6; y = Math.max(40, Math.min(130, y)); B.path.push([x, y]); }
    B.crackTexObj = G.canvasTex(256, 170, () => {}); B.crackCtx = B.crackTexObj.userData.ctx;
    B.crack = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 0.9), new THREE.MeshBasicMaterial({ map: B.crackTexObj, transparent: true, depthWrite: false }));
    B.crack.visible = false; B.crack.userData.dynamic = true; group.add(B.crack);
    B.waterMesh = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshLambertMaterial({ color: 0x0f5566, transparent: true, opacity: 0.6, emissive: 0x05202a, depthWrite: false }));
    B.waterMesh.rotation.x = -Math.PI / 2; B.waterMesh.visible = false; B.waterMesh.userData.dynamic = true; group.add(B.waterMesh);
    B.spray = pts(SPRAY, 0.05, 0x9fe8f0, false); B.sparks = pts(60, 0.05, 0xffd08a, true);
    group.add(B.spray.m); group.add(B.sparks.m);
    B.alarmCol = new THREE.Color(0xff3040);
  };
  B.at = room => SPOTS.find(s => s.room === room);
  /* сильный удар — пробоина; слабый корпус не пробивает */
  B.onHit = function (n) {
    if (n < HIT_MIN || B.active || B.cd > 0 || G.Ship.hull <= 0) return false;
    B.start(SPOTS[B.count % SPOTS.length]); return true;
  };
  B.start = function (spot) {
    B.active = spot; B.count++; B.weld = 0; B.welding = false; B.cd = COOLDOWN;
    if (B.waterRoom !== spot.room) { B.water = 0; B.waterRoom = spot.room; }
    B.crack.position.copy(spot.p).addScaledVector(spot.n, 0.02);
    B.crack.quaternion.setFromUnitVectors(new V3(0, 0, 1), spot.n);
    B.crack.visible = true; crackTex('active');
    for (let i = 0; i < B.spray.n; i++) B.spray.life[i] = -Math.random() * 1.2;
    B.spray.m.visible = true;
    G.Game.toast('Пробоина!', `Борт пробит: ${spot.name}. Бегите к трещине и удерживайте кнопку — сварка шва.`, 5000);
    G.Game.feedMsg && G.Game.feedMsg(`Пробоина: ${spot.name} — вода прибывает`);
    G.Audio.creak();
  };
  B.end = function () {
    const spot = B.active; B.active = null; B.welding = false; B.weld = 0; G.Run.note('breaches');
    crackTex('welded'); B.spray.m.visible = false; B.sparks.m.visible = false;
    G.Game.toast('Пробоина заделана', `Корпус ${Math.round(G.Ship.hull)}%. Насосы откачивают воду.`);
    G.Game.feedMsg && G.Game.feedMsg(`Шов заварен: ${spot.name}`);
    G.Audio.scanDone();
  };
  B.reset = function () {
    B.active = null; B.count = 0; B.cd = 0; B.weld = 0; B.welding = false; B.water = 0; B.waterRoom = null;
    if (!B.crack) return;
    B.crack.visible = false; B.waterMesh.visible = false; B.spray.m.visible = false; B.sparks.m.visible = false;
    if (G.Audio.siren) G.Audio.siren(0);
    B.alert(false);
  };
  /* удержание кнопки у трещины: шов прирастает, искры летят */
  B.holdWeld = function (dt) { if (!B.active) return; B.welding = true; B.weld = Math.min(100, B.weld + dt * WELD_RATE); if (B.weld >= 100) B.end(); };
  B.progress = () => B.weld / 100;
  /* вода по щиколотку и выше мешает ходить */
  B.slow = room => (B.waterRoom === room && B.water > 0.2 ? 0.55 : 1);

  B.alert = function (on) {
    const el = document.getElementById('alert'); if (!el) return;
    el.hidden = !on;
    if (on) el.textContent = `ПРОБОИНА · ${B.active.name.toUpperCase()} · ВОДА ${Math.round(B.water * 100)} см`;
  };
  B.update = function (dt, t) {
    const S = G.Ship;
    B.cd -= dt;
    const sp = B.active;
    if (sp) {
      B.water = Math.min(WATER_MAX, B.water + dt * WATER_RISE);
      if (S.hull > HULL_FLOOR) S.hull = Math.max(HULL_FLOOR, S.hull - dt * HULL_DRAIN);
      /* струя из трещины внутрь отсека */
      const s = B.spray, a = s.a;
      for (let i = 0; i < s.n; i++) {
        s.life[i] -= dt;
        if (s.life[i] <= 0) {
          if (s.life[i] < -0.05 || Math.random() < 0.5) {
            a[i * 3] = sp.p.x; a[i * 3 + 1] = sp.p.y + (Math.random() - 0.5) * 0.2; a[i * 3 + 2] = sp.p.z;
            const k = 2 + Math.random() * 2.2;
            s.v[i * 3] = sp.n.x * k + (Math.random() - 0.5) * 1.2; s.v[i * 3 + 1] = 0.6 + (Math.random() - 0.5) * 1.4; s.v[i * 3 + 2] = sp.n.z * k + (Math.random() - 0.5) * 1.2;
            s.life[i] = 1.5;
          }
          continue;
        }
        s.v[i * 3 + 1] -= 6 * dt;
        a[i * 3] += s.v[i * 3] * dt; a[i * 3 + 1] += s.v[i * 3 + 1] * dt; a[i * 3 + 2] += s.v[i * 3 + 2] * dt;
        if (a[i * 3 + 1] < B.water) s.life[i] = 0;
      }
      s.m.geometry.attributes.position.needsUpdate = true;
      /* искры сварки */
      B.sparks.m.visible = B.welding;
      if (B.welding) {
        const k = B.sparks;
        for (let i = 0; i < k.n; i++) { k.a[i * 3] = sp.p.x + sp.n.x * 0.1 + (Math.random() - 0.5) * 0.5; k.a[i * 3 + 1] = sp.p.y + (Math.random() - 0.5) * 0.4; k.a[i * 3 + 2] = sp.p.z + sp.n.z * 0.1 + (Math.random() - 0.5) * 0.5; }
        k.m.geometry.attributes.position.needsUpdate = true;
      }
      B.welding = false; // держат кнопку — выставят снова в этом кадре
      /* красный свет и сирена */
      const on = Math.sin(t * 6) > 0;
      S.lights.forEach(o => { if (!o.col0) o.col0 = o.l.color.clone(); o.l.color.copy(on ? B.alarmCol : o.col0); o.l.intensity *= on ? 1.6 : 0.35; });
      if (G.Audio.siren) G.Audio.siren(1, t);
    } else {
      if (B.water > 0) B.water = Math.max(0, B.water - dt * PUMP * G.Power.k('life')); // насосы питаются от жизнеобеспечения
      S.lights.forEach(o => { if (o.col0) { o.l.color.copy(o.col0); o.col0 = null; } });
      if (G.Audio.siren) G.Audio.siren(0);
    }
    const W = B.waterMesh, room = B.waterRoom && B.at(B.waterRoom);
    W.visible = B.water > 0.005 && !!room;
    if (W.visible) { W.position.set(room.floor.x, B.water, room.floor.z); W.scale.set(room.floor.w - 0.1, room.floor.d - 0.1, 1); }
    B.msgCd -= dt;
    if (sp && B.msgCd <= 0) { B.msgCd = 0.25; B.alert(true); } else if (!sp && B.wasActive) B.alert(false); // табло отдаём перегреву
    B.wasActive = !!sp;
  };
})(window.G);
