'use strict';
/* Сохранение журнала экспедиции в localStorage: изученные виды, наблюдения, найденные и отмеченные места,
   груз трюма, поднятые со дна образцы и установленные улучшения.
   Запись не чаще раза в секунду после изменений; хранилище может быть недоступно — тогда игра просто не сохраняет. */
(function (G) {
  const KEY = 'pogrujenie.save.v1';
  const S = G.Save = { KEY, dirty: false, timer: 0 };
  function store() { try { return window.localStorage; } catch (_) { return null; } }

  S.snapshot = function () {
    const species = {};
    G.SPECIES_ORDER.forEach(k => { species[k] = { scanned: !!G.SPECIES[k].scanned, seen: [...G.SPECIES[k].seen] }; });
    const pois = G.World.pois.filter(p => p.found || p.pinged).map(p => ({ key: p.key, found: !!p.found, pinged: !!p.pinged }));
    const cargo = G.Ship.cargo.map(c => ({ kind: c.kind, i: c.i != null ? c.i : null }));
    return { v: 1, species, pois, cargo, got: [...G.Manip.got], ups: [...G.Cargo.owned], tutorial: G.Tutorial ? G.Tutorial.state() : null };
  };
  S.apply = function (data) {
    if (!data || data.v !== 1 || typeof data.species !== 'object') return false;
    Object.entries(data.species).forEach(([k, s]) => {
      const sp = G.SPECIES[k]; if (!sp || !s) return;
      sp.scanned = !!s.scanned;
      sp.seen = new Set((Array.isArray(s.seen) ? s.seen : []).filter(n => sp.notes[n]));
    });
    (Array.isArray(data.pois) ? data.pois : []).forEach(d => {
      const p = G.World.pois.find(x => x.key === d.key); if (!p) return;
      p.found = !!d.found; p.pinged = !!d.pinged;
    });
    if ((Array.isArray(data.cargo) || Array.isArray(data.got)) && G.Manip.samples.length) G.Manip.restore(data.got, data.cargo);
    if (Array.isArray(data.ups)) G.Cargo.restore(data.ups);
    if (data.tutorial && G.Tutorial) G.Tutorial.apply(data.tutorial);
    return true;
  };
  S.save = function () {
    const st = store(); if (!st) return false;
    try { st.setItem(KEY, JSON.stringify(S.snapshot())); S.dirty = false; S.timer = 0; return true; } catch (_) { return false; }
  };
  S.load = function () {
    const st = store(); if (!st) return false;
    let raw = null; try { raw = st.getItem(KEY); } catch (_) { return false; }
    if (!raw) return false;
    try { return S.apply(JSON.parse(raw)); } catch (_) { return false; }
  };
  S.mark = function () { S.dirty = true; };
  S.tick = function (dt) { if (!S.dirty) return; S.timer += dt; if (S.timer >= 1) S.save(); };
  S.wipe = function () { const st = store(); try { if (st) st.removeItem(KEY); } catch (_) {} S.dirty = false; S.timer = 0; };
  S.hasProgress = function () { const s = S.snapshot(); return s.pois.length > 0 || s.cargo.length > 0 || s.ups.length > 0 || Object.values(s.species).some(x => x.scanned || x.seen.length); };

  addEventListener('visibilitychange', () => { if (document.visibilityState === 'hidden' && S.dirty) S.save(); });
  addEventListener('pagehide', () => { if (S.dirty) S.save(); });
})(window.G);
