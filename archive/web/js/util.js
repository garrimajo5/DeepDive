'use strict';
/* Общие утилиты: детерминированный рандом, шум, слияние геометрий */
window.G = window.G || {};
(function (G) {
  function mulberry32(a) {
    return function () {
      a |= 0; a = a + 0x6D2B79F5 | 0;
      let t = Math.imul(a ^ a >>> 15, 1 | a);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }
  G.rng = mulberry32(20261018);
  G.seed = n => { const r = mulberry32(n); G.rng = r; };
  G.rr = (a, b) => a + (b - a) * G.rng();
  G.pick = arr => arr[Math.floor(G.rng() * arr.length)];
  G.clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
  G.lerp = (a, b, t) => a + (b - a) * t;
  G.smooth = (e0, e1, x) => { const t = G.clamp((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t); };
  G.cap = s => s.charAt(0).toUpperCase() + s.slice(1);

  function hash2(ix, iz) {
    let h = (Math.imul(ix, 374761393) + Math.imul(iz, 668265263)) | 0;
    h = Math.imul(h ^ (h >>> 13), 1274126177);
    h ^= h >>> 16;
    return (h >>> 0) / 4294967295;
  }
  G.noise = function (x, z) {
    const ix = Math.floor(x), iz = Math.floor(z);
    const fx = x - ix, fz = z - iz;
    const ux = fx * fx * (3 - 2 * fx), uz = fz * fz * (3 - 2 * fz);
    const a = hash2(ix, iz), b = hash2(ix + 1, iz), c = hash2(ix, iz + 1), d = hash2(ix + 1, iz + 1);
    return a + (b - a) * ux + (c - a) * uz + (a - b - c + d) * ux * uz;
  };
  G.fbm = function (x, z, oct) {
    let s = 0, amp = 0.5, f = 1, n = 0;
    for (let i = 0; i < oct; i++) { s += amp * G.noise(x * f + i * 17.3, z * f - i * 9.1); n += amp; amp *= 0.5; f *= 2; }
    return s / n;
  };

  /* parts: [{g: BufferGeometry, m?: Matrix4, c?: Color}] -> одна геометрия с цветами вершин */
  G.merge = function (parts) {
    let total = 0;
    const prepped = parts.map(p => {
      const g = p.g.index ? p.g.toNonIndexed() : p.g.clone();
      if (p.m) g.applyMatrix4(p.m);
      if (!g.attributes.normal) g.computeVertexNormals();
      total += g.attributes.position.count;
      p.g.dispose();
      return { g, c: p.c };
    });
    const pos = new Float32Array(total * 3), nor = new Float32Array(total * 3), col = new Float32Array(total * 3);
    let o = 0;
    prepped.forEach(({ g, c }) => {
      const n = g.attributes.position.count;
      pos.set(g.attributes.position.array, o * 3);
      nor.set(g.attributes.normal.array, o * 3);
      const r = c ? c.r : 1, gg = c ? c.g : 1, b = c ? c.b : 1;
      for (let i = 0; i < n; i++) { col[(o + i) * 3] = r; col[(o + i) * 3 + 1] = gg; col[(o + i) * 3 + 2] = b; }
      o += n; g.dispose();
    });
    const out = new THREE.BufferGeometry();
    out.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    out.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
    out.setAttribute('color', new THREE.BufferAttribute(col, 3));
    return out;
  };

  /* Смещение вершин шумом (одинаковые позиции -> одинаковое смещение, без щелей) */
  G.jitter = function (geo, amt, freq) {
    const p = geo.attributes.position, f = freq || 1.7;
    for (let i = 0; i < p.count; i++) {
      const x = p.getX(i), y = p.getY(i), z = p.getZ(i);
      p.setXYZ(i,
        x + (G.noise(x * f + 11, y * f + z * 0.7) - 0.5) * amt * 2,
        y + (G.noise(y * f - 5, z * f + x * 0.3) - 0.5) * amt * 2,
        z + (G.noise(z * f + 3, x * f - y * 0.5) - 0.5) * amt * 2);
    }
    geo.computeVertexNormals();
    return geo;
  };

  G.canvasTex = function (w, h, draw) {
    const c = document.createElement('canvas'); c.width = w; c.height = h;
    const x = c.getContext('2d'); draw(x, w, h);
    const t = new THREE.CanvasTexture(c); t.userData.ctx = x; t.userData.canvas = c;
    return t;
  };

  /* Слить меши с общим материалом в один (позиции, нормали, uv). Меши удаляются из сцены. */
  G.mergeMeshes = function (list, parent) {
    if (list.length < 2) return null;
    parent.updateMatrixWorld(true);
    const inv = new THREE.Matrix4().copy(parent.matrixWorld).invert(), mat = list[0].material;
    const geos = list.map(o => { o.updateMatrixWorld(true); const geo = o.geometry.index ? o.geometry.toNonIndexed() : o.geometry.clone(); geo.applyMatrix4(new THREE.Matrix4().multiplyMatrices(inv, o.matrixWorld)); if (!geo.attributes.normal) geo.computeVertexNormals(); return geo; });
    const hasUV = geos.every(x => x.attributes.uv);
    let n = 0; geos.forEach(x => { n += x.attributes.position.count; });
    const pos = new Float32Array(n * 3), nor = new Float32Array(n * 3), uv = hasUV ? new Float32Array(n * 2) : null;
    let o3 = 0, o2 = 0;
    geos.forEach(x => {
      pos.set(x.attributes.position.array, o3); nor.set(x.attributes.normal.array, o3); o3 += x.attributes.position.array.length;
      if (uv) { uv.set(x.attributes.uv.array, o2); o2 += x.attributes.uv.array.length; }
      x.dispose();
    });
    const mg = new THREE.BufferGeometry();
    mg.setAttribute('position', new THREE.BufferAttribute(pos, 3)); mg.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
    if (uv) mg.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
    mg.computeBoundingSphere();
    const mesh = new THREE.Mesh(mg, mat); mesh.name = 'merged'; mesh.renderOrder = list[0].renderOrder;
    list.forEach(o => {
      if (o.children.length) { o.geometry = new THREE.BufferGeometry(); o.userData.emptied = true; }
      else o.parent.remove(o);
    });
    parent.add(mesh);
    return mesh;
  };

  G.timeU = { value: 0 };

  /* Покачивание растений в вершинном шейдере (геометрия нормирована по высоте 0..1) */
  G.sway = function (mat, amp) {
    mat.onBeforeCompile = sh => {
      sh.uniforms.uTime = G.timeU;
      sh.vertexShader = 'uniform float uTime;\n' + sh.vertexShader.replace('#include <begin_vertex>', `#include <begin_vertex>
        #ifdef USE_INSTANCING
          float swPh = instanceMatrix[3].x * 0.23 + instanceMatrix[3].z * 0.19;
        #else
          float swPh = 0.0;
        #endif
        float swK = clamp(position.y, 0.0, 1.0);
        transformed.x += sin(uTime * 1.2 + swPh + position.y * 2.0) * swK * swK * ${amp.toFixed(3)};
        transformed.z += cos(uTime * 0.9 + swPh * 1.3) * swK * swK * ${(amp * 0.6).toFixed(3)};`);
    };
    return mat;
  };
})(window.G);
