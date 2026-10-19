'use strict';
/* Мир: отмель «Подлёдный сад» — рельеф, лёд, рифы, места для открытий */
(function (G) {
  const V3 = THREE.Vector3;
  const W = G.World = { pois: [], patches: [], obstacles: [], coralSpots: [], lairs: [], shafts: [], anim: [] };

  W.height = function (x, z) {
    const n = G.fbm(x * 0.006, z * 0.006, 4);
    let h = -64 + (n - 0.5) * 34;
    const r = Math.hypot(x + 10, z + 10);
    const plat = G.smooth(250, 110, r);
    h += plat * 25;
    const rn = G.noise(x * 0.028 + 3.1, z * 0.028 - 1.7);
    const ridge = 1 - Math.abs(rn * 2 - 1);
    h += ridge * ridge * ridge * 9 * plat;
    h -= G.smooth(150, 240, x) * 55;                    // склон в глубину на востоке
    const e = Math.max(Math.abs(x), Math.abs(z));
    h += G.smooth(285, 345, e) * 80;                    // края карты — скальные стены
    h += (G.noise(x * 0.13, z * 0.13) - 0.5) * 1.4;
    return Math.min(h, -7);
  };
  const H = W.height;

  function placeMany(n, cx, cz, R, minH, maxH, minSep) {
    const out = []; let tries = 0;
    while (out.length < n && tries < n * 50) {
      tries++;
      const a = G.rng() * 6.2832, r = Math.sqrt(G.rng()) * R;
      const x = cx + Math.cos(a) * r, z = cz + Math.sin(a) * r;
      const h = H(x, z);
      if (h < minH || h > maxH) continue;
      if (minSep && out.some(p => (p.x - x) ** 2 + (p.z - z) ** 2 < minSep * minSep)) continue;
      out.push(new V3(x, h, z));
    }
    return out;
  }
  function spotNear(x, z, R, minH, maxH) { return placeMany(1, x, z, R, minH, maxH)[0] || new V3(x, H(x, z), z); }
  function mats(list, scaleFn, tilt) {
    const d = new THREE.Object3D();
    return list.map((p, i) => {
      d.position.copy(p);
      d.rotation.set(G.rr(-tilt, tilt), G.rr(0, 6.283), G.rr(-tilt, tilt));
      const s = scaleFn(p, i);
      if (typeof s === 'number') d.scale.setScalar(s); else d.scale.copy(s);
      d.updateMatrix();
      return d.matrix.clone();
    });
  }
  function inst(scene, geo, mat, matrices, colors) {
    const im = new THREE.InstancedMesh(geo, mat, Math.max(1, matrices.length));
    im.count = matrices.length;
    im.frustumCulled = false;
    matrices.forEach((m, i) => { im.setMatrixAt(i, m); if (colors) im.setColorAt(i, colors[i]); });
    im.instanceMatrix.needsUpdate = true;
    if (im.instanceColor) im.instanceColor.needsUpdate = true;
    scene.add(im);
    return im;
  }
  function addPoi(key, name, desc, pos, rd) { W.pois.push({ key, name, desc, pos: pos.clone(), rd, found: false, pinged: false }); }

  function makeCaustics() {
    return G.canvasTex(256, 256, (x, w, h) => {
      const img = x.createImageData(w, h), d = img.data, T = Math.PI * 2;
      for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
        const u = i / w * T, v = j / h * T;
        const s = Math.sin(u * 2 + Math.sin(v * 3) * 1.6) + Math.sin(v * 2 + Math.sin(u * 3) * 1.6) + 0.7 * Math.sin((u + v) * 3 + Math.cos(u * 2 - v) * 1.2);
        const c = Math.pow(Math.max(0, 1 - Math.abs(s) * 0.85), 3) * 255;
        const k = (j * w + i) * 4; d[k] = c; d[k + 1] = c; d[k + 2] = c; d[k + 3] = 255;
      }
      x.putImageData(img, 0, 0);
    });
  }

  function branchCoral(depth, len0, rad0) {
    const body = [], tips = [], up = new V3(0, 1, 0);
    (function br(base, dir, len, rad, d) {
      const g = new THREE.CylinderGeometry(rad * 0.68, rad, len, 5, 1);
      g.translate(0, len / 2, 0);
      body.push({ g, m: new THREE.Matrix4().compose(base, new THREE.Quaternion().setFromUnitVectors(up, dir), new V3(1, 1, 1)) });
      const tip = base.clone().addScaledVector(dir, len);
      if (d > 0) {
        const n = 2 + (G.rng() < 0.45 ? 1 : 0);
        for (let i = 0; i < n; i++) {
          const nd = dir.clone().add(new V3(G.rr(-0.9, 0.9), G.rr(0.1, 0.6), G.rr(-0.9, 0.9))).normalize();
          br(tip, nd, len * G.rr(0.62, 0.82), rad * 0.7, d - 1);
        }
      } else {
        tips.push({ g: new THREE.SphereGeometry(rad * 1.6, 6, 4), m: new THREE.Matrix4().makeTranslation(tip.x, tip.y, tip.z) });
      }
    })(new V3(), up.clone(), len0, rad0, depth);
    return { body: G.merge(body), tips: G.merge(tips) };
  }

  function shaft(scene, x, z, rt, rb, len, op, tilt) {
    const geo = new THREE.CylinderGeometry(rt, rb, len, 24, 1, true);
    geo.translate(0, -len / 2, 0);
    const pos = geo.attributes.position, col = new Float32Array(pos.count * 3);
    for (let i = 0; i < pos.count; i++) { const k = 1 - (-pos.getY(i) / len); col[i * 3] = col[i * 3 + 1] = col[i * 3 + 2] = k * k; }
    geo.setAttribute('color', new THREE.BufferAttribute(col, 3));
    const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: 0xbff6ff, vertexColors: true, transparent: true, opacity: op, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false }));
    m.position.set(x, -0.5, z); m.rotation.z = tilt || 0.1; m.rotation.y = G.rr(0, 6.28);
    m.userData.op = op; m.userData.ph = G.rr(0, 6);
    scene.add(m); W.shafts.push(m);
    return m;
  }

  W.build = function (scene) {
    /* ---------- рельеф ---------- */
    const seg = 180, SZ = 700;
    const geo = new THREE.PlaneGeometry(SZ, SZ, seg, seg); geo.rotateX(-Math.PI / 2);
    const pos = geo.attributes.position;
    for (let i = 0; i < pos.count; i++) pos.setY(i, H(pos.getX(i), pos.getZ(i)));
    geo.computeVertexNormals();
    const nor = geo.attributes.normal, cols = new Float32Array(pos.count * 3);
    const sand = new THREE.Color(0.80, 0.74, 0.60), rock = new THREE.Color(0.42, 0.28, 0.48), moss = new THREE.Color(0.20, 0.48, 0.44), deep = new THREE.Color(0.08, 0.13, 0.22), c = new THREE.Color();
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
      const slope = 1 - nor.getY(i);
      c.copy(sand).lerp(rock, G.clamp(slope * 3.2, 0, 1));
      c.lerp(moss, G.smooth(0.55, 0.8, G.noise(x * 0.03 + 7, z * 0.03)) * 0.7);
      c.lerp(deep, G.smooth(-55, -110, y));
      const v = 0.82 + G.noise(x * 0.4, z * 0.4) * 0.3;
      cols[i * 3] = c.r * v; cols[i * 3 + 1] = c.g * v; cols[i * 3 + 2] = c.b * v;
    }
    geo.setAttribute('color', new THREE.BufferAttribute(cols, 3));
    W.caust = makeCaustics();
    W.caust.wrapS = W.caust.wrapT = THREE.RepeatWrapping; W.caust.repeat.set(80, 80);
    W.terrain = new THREE.Mesh(geo, new THREE.MeshLambertMaterial({ vertexColors: true, emissive: 0x47c2cf, emissiveIntensity: 0.45, emissiveMap: W.caust }));
    scene.add(W.terrain);

    /* ---------- лёд над головой ---------- */
    const iceTex = G.canvasTex(512, 512, (x, w, h) => {
      x.fillStyle = '#86bccb'; x.fillRect(0, 0, w, h);
      for (let i = 0; i < 40; i++) { x.fillStyle = `rgba(30,70,90,${G.rr(0.05, 0.22).toFixed(2)})`; x.beginPath(); x.arc(G.rr(0, w), G.rr(0, h), G.rr(20, 90), 0, 7); x.fill(); }
      x.strokeStyle = 'rgba(240,255,255,0.9)';
      for (let i = 0; i < 26; i++) {
        let px = G.rr(0, w), py = G.rr(0, h);
        x.lineWidth = G.rr(0.6, 2.6); x.beginPath(); x.moveTo(px, py);
        for (let k = 0; k < 14; k++) { px += G.rr(-26, 26); py += G.rr(-26, 26); x.lineTo(px, py); }
        x.stroke();
      }
    });
    iceTex.wrapS = iceTex.wrapT = THREE.RepeatWrapping; iceTex.repeat.set(6, 6);
    const ice = new THREE.Mesh(new THREE.PlaneGeometry(900, 900), new THREE.MeshBasicMaterial({ map: iceTex, side: THREE.DoubleSide }));
    ice.rotation.x = Math.PI / 2; scene.add(ice);

    /* ---------- лучи света сквозь трещины ---------- */
    for (let i = 0; i < 11; i++) shaft(scene, G.rr(-200, 180), G.rr(-200, 180), G.rr(1.5, 4), G.rr(8, 16), G.rr(55, 80), G.rr(0.035, 0.06), G.rr(0.05, 0.18));

    /* ---------- рифы ---------- */
    const reefC = [-10, 10];
    // ветвистые кораллы со светящимися кончиками
    const corA = branchCoral(2, 1.3, 0.18), corB = branchCoral(2, 1.5, 0.16);
    const coralCols = [0xff5fa2, 0xff9a3c, 0xb56cff, 0x4fe3c1, 0xffd84f, 0xff6f6f].map(c => new THREE.Color(c));
    [corA, corB].forEach((cor, vi) => {
      const list = placeMany(85, reefC[0], reefC[1], 210, -58, -12, 3);
      const ms = mats(list, () => G.rr(1.1, 3.4), 0.2);
      const cs = list.map(() => G.pick(coralCols).clone());
      inst(scene, cor.body, new THREE.MeshLambertMaterial({ vertexColors: true, emissive: 0x1a0a14 }), ms, cs.map(c => c.clone().multiplyScalar(0.75)));
      inst(scene, cor.tips, new THREE.MeshBasicMaterial({ vertexColors: true }), ms, cs.map(c => c.clone().lerp(new THREE.Color(1, 1, 1), 0.35)));
      list.forEach((p, i) => { if (vi === 0) W.coralSpots.push(p.clone().setY(p.y + 2)); });
    });
    // кораллы-подушки
    {
      const g = G.jitter(new THREE.SphereGeometry(1, 10, 7), 0.12, 2.2); g.scale(1, 0.55, 1); // экономия треугольников: 150 подушек
      const list = placeMany(150, reefC[0], reefC[1], 230, -62, -10, 2);
      const pal = [0x8a4fa8, 0xc76a5a, 0x3f8f86, 0xa0a050, 0x6a5ac8].map(c => new THREE.Color(c));
      inst(scene, g, new THREE.MeshLambertMaterial({ color: 0xffffff, emissive: 0x0c0610 }), mats(list, () => new V3(G.rr(0.8, 2.6), G.rr(0.6, 1.6), G.rr(0.8, 2.6)), 0.15), list.map(() => G.pick(pal)));
    }
    // губки-трубки
    {
      const parts = [];
      for (let k = 0; k < 4; k++) {
        const h = G.rr(0.8, 2), r = G.rr(0.16, 0.3);
        const c = new THREE.CylinderGeometry(r, r * 1.2, h, 9, 1, true); c.translate(0, h / 2, 0);
        parts.push({ g: c, m: new THREE.Matrix4().makeRotationZ(G.rr(-0.25, 0.25)).setPosition(G.rr(-0.4, 0.4), 0, G.rr(-0.4, 0.4)) });
      }
      const g = G.merge(parts);
      const list = placeMany(90, reefC[0], reefC[1], 220, -60, -12, 3);
      const pal = [0xd07a2e, 0x5a7fd6, 0xc8c040, 0xd65a8a].map(c => new THREE.Color(c));
      inst(scene, g, new THREE.MeshLambertMaterial({ vertexColors: true, side: THREE.DoubleSide, emissive: 0x100804 }), mats(list, () => G.rr(0.8, 1.8), 0.1), list.map(() => G.pick(pal)));
    }
    // светящиеся анемоны
    {
      const parts = [{ g: new THREE.CylinderGeometry(0.16, 0.22, 0.18, 6), m: new THREE.Matrix4().makeTranslation(0, 0.09, 0), c: new THREE.Color(0.35, 0.35, 0.4) }];
      for (let k = 0; k < 18; k++) {
        const cg = new THREE.ConeGeometry(0.035, 1, 3, 1, true); cg.translate(0, 0.5, 0); // тонкие щупальца: 3 грани без донышка
        const a = k / 18 * 6.283;
        const m = new THREE.Matrix4().makeRotationAxis(new V3(Math.sin(a), 0, -Math.cos(a)), G.rr(0.15, 0.6)).setPosition(Math.cos(a) * 0.12, 0.15, Math.sin(a) * 0.12);
        parts.push({ g: cg, m });
      }
      const g = G.merge(parts);
      const list = placeMany(170, reefC[0], reefC[1], 220, -60, -10, 2);
      const pal = [0x5ef2d6, 0xff7ad9, 0x9d8cff, 0x7fe7ff].map(c => new THREE.Color(c));
      inst(scene, g, G.sway(new THREE.MeshBasicMaterial({ vertexColors: true }), 0.22), mats(list, () => G.rr(0.5, 1.4), 0.15), list.map(() => G.pick(pal)));
    }
    // ленточник — длинные водоросли
    {
      const g = new THREE.PlaneGeometry(0.4, 1, 1, 7); g.translate(0, 0.5, 0);
      const list = placeMany(300, 0, 0, 280, -95, -30, 1.5);
      const pal = [0x5f9a4a, 0x8aa83c, 0xb08a3a, 0x3f8f7a].map(c => new THREE.Color(c));
      inst(scene, g, G.sway(new THREE.MeshLambertMaterial({ color: 0xffffff, side: THREE.DoubleSide, emissive: 0x0b1a10 }), 1.1), mats(list, () => new V3(1, G.rr(3.5, 9), 1), 0.08), list.map(() => G.pick(pal)));
    }
    // камни
    const rockGeo = G.jitter(new THREE.DodecahedronGeometry(1, 1), 0.18, 1.5);
    const rockMat = new THREE.MeshLambertMaterial({ color: 0x5f586c, flatShading: true });
    {
      const list = placeMany(140, 0, 0, 290, -120, -8, 4);
      inst(scene, rockGeo, rockMat, mats(list, () => new V3(G.rr(0.6, 3.2), G.rr(0.5, 2), G.rr(0.6, 3.2)), 0.5));
    }
    // поле кристаллов на севере (предвестник Кристального леса)
    const crystalGeo = (function () {
      const parts = [];
      for (let k = 0; k < 4; k++) {
        const o = new THREE.OctahedronGeometry(1, 0); o.scale(0.32, G.rr(1.6, 2.8), 0.32);
        parts.push({ g: o, m: new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(G.rr(-0.5, 0.5), G.rr(0, 3), G.rr(-0.5, 0.5))).setPosition(G.rr(-0.6, 0.6), 1, G.rr(-0.6, 0.6)) });
      }
      return G.merge(parts);
    })();
    const crystalMat = new THREE.MeshPhongMaterial({ color: 0x8ff7ff, emissive: 0x1aa5b5, emissiveIntensity: 0.7, shininess: 90, flatShading: true, transparent: true, opacity: 0.88 });
    inst(scene, crystalGeo, crystalMat, mats(placeMany(60, 30, -170, 80, -80, -10, 4), () => G.rr(0.8, 2.2), 0.25));

    /* ---------- пятна светящегося мха (еда скребунов) ---------- */
    const mossPos = [], mossCol = [], mossIdx = []; // все пятна мха — один меш, яркость пятна в альфе вершин
    placeMany(22, -10, 30, 170, -56, -12, 18).forEach(p => {
      const pg = new THREE.PlaneGeometry(7, 7, 8, 8); pg.rotateX(-Math.PI / 2);
      const pp = pg.attributes.position, col = new Float32Array(pp.count * 4);
      for (let i = 0; i < pp.count; i++) {
        const lx = pp.getX(i), lz = pp.getZ(i);
        pp.setY(i, H(p.x + lx, p.z + lz) - p.y + 0.14);
        const a = G.smooth(3.4, 1.0, Math.hypot(lx, lz)) * (0.55 + G.noise(lx * 1.3 + p.x, lz * 1.3) * 0.6);
        col.set([0.45, 1, 0.75, a], i * 4);
      }
      const v0 = mossPos.length / 3, base = new Float32Array(pp.count);
      for (let i = 0; i < pp.count; i++) { mossPos.push(pp.getX(i) + p.x, pp.getY(i) + p.y, pp.getZ(i) + p.z); mossCol.push(col[i * 4], col[i * 4 + 1], col[i * 4 + 2], col[i * 4 + 3]); base[i] = col[i * 4 + 3]; }
      for (let i = 0; i < pg.index.count; i++) mossIdx.push(pg.index.array[i] + v0);
      pg.dispose();
      W.patches.push({ x: p.x, y: p.y, z: p.z, food: G.rr(0.6, 1), v0, base, alpha: -1 });
    });
    {
      const mg = new THREE.BufferGeometry();
      mg.setAttribute('position', new THREE.Float32BufferAttribute(mossPos, 3));
      mg.setAttribute('color', new THREE.Float32BufferAttribute(mossCol, 4));
      mg.setIndex(mossIdx);
      W.moss = new THREE.Mesh(mg, new THREE.MeshBasicMaterial({ color: 0x9dffd0, vertexColors: true, transparent: true, depthWrite: false }));
      W.moss.frustumCulled = false; scene.add(W.moss);
      W.patches.forEach(mossAlpha);
    }

    /* ---------- логова стеклоустов ---------- */
    [[28, 52], [-62, -8], [62, -45]].forEach(([x, z]) => {
      const p = spotNear(x, z, 18, -58, -14);
      const out = new V3(G.rr(-1, 1), 0, G.rr(-1, 1)).normalize();
      const side = new V3(out.z, 0, -out.x);
      const back = p.clone().addScaledVector(out, -2.4);
      [[0, 0.2, 2.7], [1.7, 1.0, 1.9], [-1.7, 1.0, 1.9], [0, 2.6, 2.1], [0.6, -0.2, 2.2]].forEach(([sx, sy, r]) => {
        const m = new THREE.Mesh(rockGeo, rockMat); m.userData.mergeLair = true;
        m.position.copy(back).addScaledVector(side, sx); m.position.y += sy;
        m.scale.setScalar(r); m.rotation.set(G.rr(0, 3), G.rr(0, 3), 0);
        scene.add(m);
      });
      W.lairs.push({ mouth: p.clone().add(new V3(0, 1.1, 0)).addScaledVector(out, 0.3), out });
    });

    /* ---------- места для открытий ---------- */
    // Каменный цветок
    {
      const p = spotNear(60, -60, 30, -60, -16);
      const cor = branchCoral(4, 2.2, 0.55);
      const grp = new THREE.Group();
      grp.add(new THREE.Mesh(cor.body, new THREE.MeshLambertMaterial({ color: 0xd06a94, vertexColors: true, emissive: 0x200810 })));
      grp.add(new THREE.Mesh(cor.tips, new THREE.MeshBasicMaterial({ color: 0xffd6ec })));
      grp.scale.setScalar(3.1); grp.position.copy(p); scene.add(grp);
      addPoi('flower', 'Каменный цветок', 'Коралл-исполин высотой с девятиэтажный дом. Светящиеся кончики видны издалека, вокруг кормятся стаи.', p, 45);
      W.obstacles.push({ x: p.x, z: p.z, r: 5, top: p.y + 28 });
    }
    // Чёрный курильщик
    {
      const p = spotNear(-110, 50, 25, -90, -15);
      const cg = G.jitter(new THREE.CylinderGeometry(1.4, 4.2, 9, 12, 5), 0.35); cg.translate(0, 4.5, 0);
      const m = new THREE.Mesh(cg, new THREE.MeshLambertMaterial({ color: 0x3a2a2e, flatShading: true }));
      m.position.copy(p); m.position.y -= 1; scene.add(m);
      const ring = new THREE.Mesh(new THREE.TorusGeometry(1.3, 0.25, 8, 20), new THREE.MeshBasicMaterial({ color: 0xff8a3c }));
      ring.rotation.x = Math.PI / 2; ring.position.set(p.x, p.y + 7.8, p.z); scene.add(ring);
      const N = 180, arr = new Float32Array(N * 3), sp = [];
      for (let i = 0; i < N; i++) { arr[i * 3] = p.x + G.rr(-1, 1); arr[i * 3 + 1] = p.y + 8 + G.rr(0, Math.max(5, -p.y - 9)); arr[i * 3 + 2] = p.z + G.rr(-1, 1); sp.push(G.rr(2, 5)); }
      const bg = new THREE.BufferGeometry(); bg.setAttribute('position', new THREE.BufferAttribute(arr, 3));
      const pts = new THREE.Points(bg, new THREE.PointsMaterial({ color: 0xdffaff, size: 0.35, transparent: true, opacity: 0.8 }));
      pts.frustumCulled = false; scene.add(pts);
      W.anim.push((dt, t) => {
        for (let i = 0; i < N; i++) {
          arr[i * 3 + 1] += sp[i] * dt; arr[i * 3] += Math.sin(t * 2 + i) * 0.01;
          if (arr[i * 3 + 1] > -0.5) { arr[i * 3 + 1] = p.y + 8; arr[i * 3] = p.x + G.rr(-0.8, 0.8); arr[i * 3 + 2] = p.z + G.rr(-0.8, 0.8); }
        }
        bg.attributes.position.needsUpdate = true;
        ring.material.color.setHSL(0.07, 1, 0.5 + Math.sin(t * 3) * 0.1);
      });
      addPoi('geyser', 'Чёрный курильщик', 'Гидротермальный источник выбрасывает тёплую воду и пузыри. Рядом на несколько градусов теплее.', p, 45);
      W.obstacles.push({ x: p.x, z: p.z, r: 4.5, top: p.y + 9 });
    }
    // Раковина древних
    {
      const p = spotNear(150, -30, 25, -105, -20);
      const parts = [];
      for (let i = 0; i < 70; i++) {
        const a = i * 0.28, R = 0.35 * Math.exp(0.085 * a);
        parts.push({ g: new THREE.SphereGeometry(R * 1.05, 10, 8), m: new THREE.Matrix4().makeTranslation(Math.cos(a) * R * 2.2, Math.sin(a) * R * 2.2, Math.sin(i * 0.5) * 0.05) });
      }
      const grp = new THREE.Group();
      grp.add(new THREE.Mesh(G.merge(parts), new THREE.MeshLambertMaterial({ color: 0xcdbba1, vertexColors: true })));
      const glyphs = [];
      for (let k = 0; k < 5; k++) {
        const t = new THREE.Mesh(new THREE.TorusGeometry(1.2 + k * 1.1, 0.05, 6, 40), new THREE.MeshBasicMaterial({ color: 0xc79bff, transparent: true, opacity: 0.8 }));
        t.position.z = 1.2 + k * 0.15; grp.add(t); glyphs.push(t);
      }
      grp.scale.setScalar(1.4); grp.position.copy(p); grp.position.y += 3; grp.rotation.set(0.35, G.rr(0, 6.28), 0.2);
      scene.add(grp);
      W.anim.push((dt, t) => glyphs.forEach((g, k) => { g.material.opacity = 0.25 + 0.75 * Math.max(0, Math.sin(t * 1.5 - k * 0.8)); }));
      addPoi('shell', 'Раковина древних', 'Спиральная постройка из незнакомого материала. На витках светятся кольца знаков. Похоже, её кто-то сделал.', p, 45);
      W.obstacles.push({ x: p.x, z: p.z, r: 9, top: p.y + 12 });
    }
    // Кости левиафана
    {
      const p = spotNear(-50, -150, 25, -90, -20);
      const grp = new THREE.Group(), bm = new THREE.MeshLambertMaterial({ color: 0xd8d2c0 });
      const spine = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.35, 34, 8), bm); spine.rotation.z = Math.PI / 2; spine.position.y = 0.4; grp.add(spine);
      for (let k = 0; k < 9; k++) {
        const rib = new THREE.Mesh(new THREE.TorusGeometry(5.2 - Math.abs(k - 3) * 0.45, 0.28, 6, 18, Math.PI), bm);
        rib.rotation.set(G.rr(-0.08, 0.08), Math.PI / 2, 0); rib.position.set(-14 + k * 3.4, 0, 0); grp.add(rib);
      }
      const skull = new THREE.Mesh(new THREE.SphereGeometry(3.4, 12, 10), bm); skull.scale.set(1.6, 0.9, 1.1); skull.position.set(19, 1.2, 0); grp.add(skull);
      grp.position.copy(p); grp.position.y -= 0.8; grp.rotation.set(0, G.rr(0, 6.28), 0.05);
      scene.add(grp);
      addPoi('bones', 'Кости левиафана', 'Скелет существа длиной больше тридцати метров. Рёбра обросли мхом, между ними прячется молодь.', p, 45);
      W.obstacles.push({ x: p.x, z: p.z, r: 11, top: p.y + 6 });
    }
    // Световой колодец
    {
      const x = -170, z = -70;
      shaft(scene, x, z, 9, 30, 95, 0.15, 0.04);
      const stM = new THREE.MeshPhongMaterial({ color: 0xcff6ff, emissive: 0x2a6a7a, shininess: 80, transparent: true, opacity: 0.92 });
      for (let i = 0; i < 16; i++) {
        const len = G.rr(5, 16);
        const c = new THREE.Mesh(new THREE.ConeGeometry(G.rr(0.8, 2.2), len, 7), stM);
        c.rotation.x = Math.PI; c.position.set(x + G.rr(-24, 24), -len / 2 + 0.5, z + G.rr(-24, 24));
        scene.add(c); c.userData.mergeIce = true;
      }
      const glow = new THREE.Mesh(new THREE.CircleGeometry(10, 32), new THREE.MeshBasicMaterial({ color: 0xffffff, fog: false }));
      glow.rotation.x = Math.PI / 2; glow.position.set(x, -0.3, z); scene.add(glow);
      addPoi('well', 'Световой колодец', 'Сквозная трещина во льду. Через неё на дно падает настоящий солнечный свет, и мох здесь растёт гуще всего.', new V3(x, -20, z), 50);
    }
    // Край отмели
    {
      const x = 215, z = 90;
      inst(scene, crystalGeo, crystalMat, mats(placeMany(26, x, z, 40, -150, -30, 4), () => G.rr(1.5, 3.5), 0.3));
      addPoi('drop', 'Край отмели', 'Дно обрывается в синюю темноту. Где-то внизу начинается Кристальный лес, но корпус «Ковчега» пока не выдержит такой глубины.', new V3(x, -60, z), 55);
    }

    /* ---------- слить неподвижные камни логов и сосульки ---------- */
    ['mergeLair', 'mergeIce'].forEach(tag => { const list = scene.children.filter(o => o.isMesh && o.userData[tag]); G.mergeMeshes(list, scene); });

    /* ---------- морской снег вокруг корабля ---------- */
    {
      const N = 1400, B = 50, arr = new Float32Array(N * 3), base = new Float32Array(N * 3);
      for (let i = 0; i < N * 3; i++) base[i] = G.rr(0, B);
      const sg = new THREE.BufferGeometry(); sg.setAttribute('position', new THREE.BufferAttribute(arr, 3));
      const pts = new THREE.Points(sg, new THREE.PointsMaterial({ color: 0xcfeff2, size: 0.09, transparent: true, opacity: 0.7 }));
      pts.frustumCulled = false; scene.add(pts);
      W.snow = { N, B, arr, base, sg };
    }
  };

  /* яркость пятна мха: 0.15 у объеденного, 1 у нетронутого */
  function mossAlpha(p) {
    const a = 0.15 + 0.85 * p.food;
    if (Math.abs(a - p.alpha) < 0.002) return false;
    p.alpha = a;
    const arr = W.moss.geometry.attributes.color.array;
    for (let i = 0; i < p.base.length; i++) arr[(p.v0 + i) * 4 + 3] = p.base[i] * a;
    return true;
  }
  W.mossAlpha = mossAlpha;
  const mod = (a, b) => ((a % b) + b) % b;
  W.update = function (dt, t) {
    W.caust.offset.set(t * 0.012, t * 0.007);
    W.shafts.forEach(s => { s.material.opacity = s.userData.op * (0.75 + 0.25 * Math.sin(t * 0.4 + s.userData.ph)); });
    W.anim.forEach(f => f(dt, t));
    let mossDirty = false;
    W.patches.forEach(p => { p.food = Math.min(1, p.food + dt * 0.012); if (mossAlpha(p)) mossDirty = true; });
    if (mossDirty) W.moss.geometry.attributes.color.needsUpdate = true;
    const s = W.snow, c = G.Ship.pos, B = s.B, h = B / 2;
    for (let i = 0; i < s.N; i++) {
      const k = i * 3;
      s.arr[k] = c.x + mod(s.base[k] + Math.sin(t * 0.3 + i) * 0.4 - c.x, B) - h;
      s.arr[k + 1] = c.y + mod(s.base[k + 1] - t * 0.22 - c.y, B) - h;
      s.arr[k + 2] = c.z + mod(s.base[k + 2] - c.z, B) - h;
    }
    s.sg.attributes.position.needsUpdate = true;
  };
})(window.G);
