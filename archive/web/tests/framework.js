'use strict';
/* Мини-фреймворк тестов. Тесты выполняются внутри настоящей игры (index.html),
   перед каждым тестом мир сбрасывается через G.Game.debug.reset(). */
(function () {
  const T = window.T = { cases: [], group: '' };
  T.describe = (name, fn) => { const prev = T.group; T.group = name; fn(); T.group = prev; };
  T.test = (name, fn) => T.cases.push({ name: (T.group ? T.group + ' › ' : '') + name, fn });
  const fail = (msg) => { throw new Error(msg); };
  const show = v => { try { return JSON.stringify(v); } catch (_) { return String(v); } };
  T.ok = (c, msg) => { if (!c) fail(msg || 'ожидалось true'); };
  T.eq = (a, b, msg) => { if (a !== b) fail((msg ? msg + ': ' : '') + `ожидалось ${show(b)}, получено ${show(a)}`); };
  T.near = (a, b, eps, msg) => { if (!(Math.abs(a - b) <= eps)) fail((msg ? msg + ': ' : '') + `ожидалось ${b}±${eps}, получено ${a}`); };
  T.gt = (a, b, msg) => { if (!(a > b)) fail((msg ? msg + ': ' : '') + `ожидалось > ${b}, получено ${a}`); };
  T.lt = (a, b, msg) => { if (!(a < b)) fail((msg ? msg + ': ' : '') + `ожидалось < ${b}, получено ${a}`); };
  T.V = (x, y, z) => new THREE.Vector3(x, y, z);
  /* перехват событий экосистемы на время теста */
  T.captureEvents = () => {
    const list = [], orig = G.Eco.emit;
    G.Eco.emit = (sp, note, pos, msg) => { list.push({ sp, note, pos: pos.clone() }); orig(sp, note, pos, msg); };
    T._restore.push(() => { G.Eco.emit = orig; });
    return list;
  };
  T._restore = [];
  T.run = async (filter) => {
    const out = [];
    G.Game.debug.paused = true;
    for (const c of T.cases) {
      if (filter && !c.name.includes(filter)) continue;
      const t0 = performance.now();
      try {
        G.Game.debug.reset();
        await c.fn();
        out.push({ name: c.name, ok: true, ms: Math.round(performance.now() - t0) });
      } catch (e) {
        out.push({ name: c.name, ok: false, err: String(e && e.message || e), ms: Math.round(performance.now() - t0) });
      } finally {
        T._restore.splice(0).forEach(f => f());
      }
    }
    G.Game.debug.paused = false;
    return out;
  };
})();
