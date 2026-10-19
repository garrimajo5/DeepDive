'use strict';
/* Шлюз и манипулятор. Под стеклянным полом лаборатории сложена рука-манипулятор. Биолог смотрит
   сквозь пол на образец на дне и удерживает кнопку: рука выдвигается, хватает образец и втягивает его
   в шлюз, а оттуда он попадает в колбу лаборатории. Дотянуться можно метров на 14 от пола. */
(function (G) {
  const V3 = THREE.Vector3;
  const REACH = 14, GRAB_T = 1.4, BACK_T = 1.2;
  const KIND = {
    moss: { name: 'Светящийся мох', color: 0x9dffd0 },
    shell: { name: 'Ракушка моллюска', color: 0xe8c9a8 },
    coral: { name: 'Ветка огнецвета', color: 0xff8a3c },
    spine: { name: 'Игла шипоежа', color: 0x8cdcff }
  };
  const M = G.Manip = { KIND, REACH, samples: [], got: new Set(), holding: false, arm: null, target: null, state: 'idle', t: 0, prog: 0 };
  const tv = new V3(), tv2 = new V3(), base = new V3(), tip = new V3();

  /* образцы на дне: у пятен мха, под волнолистом, у станций огнецвета, у норы кольчужника */
  M.build = function (scene) {
    const E = G.Eco, W = G.World, list = [];
    W.patches.slice(0, 8).forEach(p => list.push({ kind: 'moss', pos: new V3(p.x + 0.8, G.World.height(p.x + 0.8, p.z) + 0.15, p.z) }));
    [0, 4].forEach(i => { const fe = E.ferns[i]; if (fe) list.push({ kind: 'shell', pos: new V3(fe.p.x + 0.4, G.World.height(fe.p.x + 0.4, fe.p.z) + 0.1, fe.p.z) }); });
    E.stations.forEach(st => list.push({ kind: 'coral', pos: st.base.clone().add(new V3(1.6, 0, 0.4)).setY(G.World.height(st.base.x + 1.6, st.base.z + 0.4) + 0.15) }));
    if (E.crab) { const d = E.crab.den.clone().addScaledVector(E.crab.out, 2.2); d.y = G.World.height(d.x, d.z) + 0.1; list.push({ kind: 'spine', pos: d }); }
    M.samples = list.map((s, i) => Object.assign(s, { i, taken: false, pos0: s.pos.clone() }));
    const g = new THREE.OctahedronGeometry(0.22, 0);
    M.im = new THREE.InstancedMesh(g, new THREE.MeshBasicMaterial(), Math.max(1, M.samples.length));
    M.im.frustumCulled = false; scene.add(M.im);
    const c = new THREE.Color();
    M.samples.forEach(s => M.im.setColorAt(s.i, c.set(KIND[s.kind].color)));
    M.place();
    /* рука под лабораторией: плечо, предплечье, клешня */
    const sh = G.Ship.group, mat = new THREE.MeshLambertMaterial({ color: 0x8aa0a8, emissive: 0x1a2226 });
    const seg = () => { const m = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.12, 1, 8), mat); m.userData.dynamic = true; sh.add(m); return m; };
    const claw = new THREE.Mesh(new THREE.ConeGeometry(0.2, 0.4, 6, 1, true), new THREE.MeshLambertMaterial({ color: 0xffb259, side: THREE.DoubleSide })); claw.userData.dynamic = true; sh.add(claw);
    const carry = new THREE.Mesh(new THREE.OctahedronGeometry(0.2, 0), new THREE.MeshBasicMaterial({ color: 0xffffff })); carry.userData.dynamic = true; carry.visible = false; sh.add(carry);
    M.arm = { a: seg(), b: seg(), claw, carry, mount: new V3(0, -0.25, 11), fold: new V3(0.9, -0.45, 12.2), tipL: new V3(0.9, -0.45, 12.2) };
    M.pose(M.arm.fold);
  };
  M.place = function () {
    M.samples.forEach(s => {
      if (s.taken) tv.set(0, -999, 0); else tv.copy(s.pos);
      const m = new THREE.Matrix4().compose(tv, new THREE.Quaternion().setFromEuler(new THREE.Euler(0, s.i, 0.4)), new V3(1, s.taken ? 0.001 : 1.3, 1));
      M.im.setMatrixAt(s.i, m);
    });
    M.im.instanceMatrix.needsUpdate = true; if (M.im.instanceColor) M.im.instanceColor.needsUpdate = true;
  };
  /* сочленение руки: от крепления до кончика (в координатах корабля), локоть провисает вниз */
  function bone(m, from, to) {
    tv.subVectors(to, from); const L = tv.length();
    m.position.copy(from).addScaledVector(tv, 0.5); m.scale.set(1, Math.max(0.01, L), 1);
    m.quaternion.setFromUnitVectors(tv2.set(0, 1, 0), L > 1e-4 ? tv.normalize() : tv2);
  }
  M.pose = function (tipLocal) {
    const A = M.arm; A.tipL.copy(tipLocal);
    const mid = tv2.copy(A.mount).lerp(tipLocal, 0.5); mid.y -= 0.25 + 0.15 * A.mount.distanceTo(tipLocal) * 0.1;
    const elbow = mid.clone();
    bone(A.a, A.mount, elbow); bone(A.b, elbow, tipLocal);
    A.claw.position.copy(tipLocal); A.claw.quaternion.copy(A.b.quaternion);
    A.carry.position.copy(tipLocal).y -= 0.15;
  };
  /* какой образец сейчас в прицеле сквозь пол лаборатории */
  M.find = function (camPos, camDir) {
    if (G.Game.room !== 'lab' || G.Game.piloting || M.state !== 'idle') return null;
    G.Ship.group.localToWorld(base.set(0, 0, 11));
    let best = null, bs = 1;
    for (const s of M.samples) {
      if (s.taken || s.pos.distanceTo(base) > REACH) continue;
      tv.subVectors(s.pos, camPos); const d = tv.length();
      const ang = Math.acos(Math.max(-1, Math.min(1, tv.dot(camDir) / d)));
      const sc = ang / Math.max(0.06, Math.atan(0.6 / d));
      if (sc < bs) { bs = sc; best = s; }
    }
    return best ? { s: best, score: bs } : null;
  };
  /* удержание кнопки: рука тянется к образцу; отпустили — возвращается */
  M.hold = function (s, dt) {
    if (M.state !== 'idle' && M.state !== 'reach') return;
    if (M.target !== s) { M.target = s; M.prog = 0; }
    M.state = 'reach'; M.prog = Math.min(1, M.prog + dt / GRAB_T); M.holding = true;
    if (M.prog >= 1) { M.state = 'back'; M.t = BACK_T; s.taken = true; M.place(); M.arm.carry.visible = true; M.arm.carry.material.color.set(KIND[s.kind].color); G.Audio.beep(820); }
  };
  M.progress = () => (M.state === 'reach' ? M.prog : M.state === 'back' ? 1 : 0);
  M.update = function (dt) {
    if (!M.arm) return;
    const A = M.arm;
    if (M.state === 'reach') {
      if (!M.holding) { M.prog = Math.max(0, M.prog - dt * 2); if (M.prog <= 0) { M.state = 'idle'; M.target = null; } }
      G.Ship.group.worldToLocal(tip.copy(M.target.pos));
      M.pose(tv.copy(A.fold).lerp(tip, M.prog));
    } else if (M.state === 'back') {
      M.t -= dt;
      G.Ship.group.worldToLocal(tip.copy(M.target.pos));
      M.pose(tv.copy(A.fold).lerp(tip, Math.max(0, M.t / BACK_T)));
      if (M.t <= 0) M.stow(M.target);
    } else M.pose(A.fold);
    M.holding = false;
  };
  /* образец в шлюзе: попадает в колбу лаборатории */
  M.stow = function (s) {
    M.state = 'idle'; M.target = null; M.prog = 0; M.arm.carry.visible = false;
    G.Ship.cargo.push({ kind: s.kind, name: KIND[s.kind].name, i: s.i }); G.Run.note('samples');
    M.got.add(s.i); // поднятый образец больше не лежит на дне, даже если его потратят на улучшение
    G.Ship.showTubes && G.Ship.showTubes();
    G.Save.mark();
    G.Game.toast('Образец в шлюзе', `${KIND[s.kind].name} — в колбе лаборатории. Всего образцов: ${G.Ship.cargo.length}.`);
    G.Game.feedMsg && G.Game.feedMsg(`Манипулятор достал образец: ${KIND[s.kind].name.toLowerCase()}`, true);
    G.Audio.scanDone();
  };
  /* скальник выхватывает образец, пока рука несёт его в шлюз */
  M.steal = function () {
    if (M.state !== 'back' || !M.target) return null;
    const s = M.target; M.state = 'idle'; M.target = null; M.prog = 0; M.arm.carry.visible = false;
    G.Game.toast('Образец украден', 'Скальник выхватил образец прямо из клешни. Он уносит его к себе в нору.');
    return s;
  };
  /* образец снова лежит на дне — его можно достать ещё раз */
  M.drop = function (s, pos) { s.taken = false; s.pos.set(pos.x, G.World.height(pos.x, pos.z) + 0.15, pos.z); M.place(); };
  /* из сохранения: какие образцы уже подняты со дна и что лежит в трюме */
  M.restore = function (got, cargo) {
    M.reset();
    (Array.isArray(got) ? got : []).forEach(i => { const s = Number.isInteger(i) && M.samples[i]; if (s) { s.taken = true; M.got.add(i); } });
    const used = new Set(), list = [];
    (Array.isArray(cargo) ? cargo : []).forEach(c => {
      if (!c || !KIND[c.kind]) return;
      if (c.i != null) { // образец со дна: тот же вид, поднят и ещё не лежит в трюме
        const s = Number.isInteger(c.i) && M.samples[c.i];
        if (!s || s.kind !== c.kind || used.has(c.i)) return;
        used.add(c.i); s.taken = true; M.got.add(c.i);
      }
      list.push({ kind: c.kind, name: KIND[c.kind].name, i: c.i != null ? c.i : null });
    });
    G.Ship.cargo.length = 0; list.forEach(c => G.Ship.cargo.push(c));
    M.place(); G.Ship.showTubes();
  };
  M.reset = function () {
    M.got.clear();
    M.samples.forEach(s => { s.taken = false; s.pos.copy(s.pos0); }); M.state = 'idle'; M.target = null; M.prog = 0;
    if (M.arm) { M.arm.carry.visible = false; M.pose(M.arm.fold); }
    if (M.im) M.place();
  };
})(window.G);
