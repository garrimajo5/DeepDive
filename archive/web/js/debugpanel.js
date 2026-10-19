'use strict';
/* Отладочная панель: FPS, нагрузка на видеокарту, состояние экосистемы, телепорт к местам.
   Включается адресом с #debug или тройным касанием по панели приборов. */
(function (G) {
  const P = G.DebugPanel = { on: false, fps: 0, frames: 0, acc: 0, el: null };

  P.teleport = function (key) {
    const st = /^station(\d)$/.exec(key || ''), hv = /^hvaten(\d)$/.exec(key || '');
    if (key === 'krab' && !G.Eco.crab) return false;
    if (key === 'grot' && !G.Eco.grot) return false;
    if (key === 'skalnik' && !G.Eco.skalnik) return false;
    const rd = /^raduzh(\d)$/.exec(key || ''), pl = /^plankton(\d)$/.exec(key || ''), gl = /^glazun(\d)$/.exec(key || '');
    const p = st ? (G.Eco.stations[+st[1]] && { pos: G.Eco.stations[+st[1]].top })
      : hv ? (G.Eco.anemones[+hv[1]] && { pos: G.Eco.anemones[+hv[1]].top })
      : rd ? (G.Eco.swarms[+rd[1]] && { pos: G.Eco.swarms[+rd[1]].home })
      : pl ? (G.Eco.clouds[+pl[1]] && { pos: G.Eco.clouds[+pl[1]].home })
      : gl ? (G.Eco.glazuns[+gl[1]] && { pos: G.Eco.glazuns[+gl[1]].p })
      : key === 'grot' ? { pos: G.Eco.grot.back }
      : key === 'skalnik' ? { pos: G.Eco.skalnik.home }
      : key === 'krab' ? { pos: G.Eco.crab.den } : G.World.pois.find(x => x.key === key);
    if (!p) return false;
    const S = G.Ship;
    S.pos.set(p.pos.x + 18, -12, p.pos.z + 18);
    S.speed = 0; S.vy = 0;
    S.pos.y = Math.max(-90, Math.min(-6, S.clearance(S.pos.x, S.pos.z, S.yaw) + 6));
    S.applyTransform();
    return true;
  };

  P.stats = function () {
    const E = G.Eco, st = {};
    E.preds.forEach(p => { st[p.state] = (st[p.state] || 0) + 1; });
    const r = G.Game.debug.info();
    return {
      fps: Math.round(P.fps), calls: r.calls, tris: r.tris,
      fish: E.fish.filter(f => f.alive).length + '/' + E.fish.length,
      grazers: E.grazers.filter(g => g.alive).length + '/' + E.grazers.length,
      preds: Object.entries(st).map(([k, v]) => k + ':' + v).join(' '),
      latched: !!E.latched, hidden: E.shipHidden, sheltered: !!E.shipSheltered, leech: E.preds.filter(p => p.leech).length,
      pos: G.Ship.pos.toArray().map(v => Math.round(v)).join(', ')
    };
  };

  function build() {
    const el = P.el = document.createElement('div');
    el.id = 'dbg';
    el.innerHTML = '<pre id="dbg-text"></pre><div class="dbg-row" id="dbg-tp"></div><div class="dbg-row"><button data-a="energy">Энергия 100</button><button data-a="hull">Корпус 100</button><button data-a="close">Скрыть</button></div>';
    const tp = el.querySelector('#dbg-tp');
    G.World.pois.forEach(p => { const b = document.createElement('button'); b.dataset.tp = p.key; b.textContent = '→ ' + p.name; tp.appendChild(b); });
    G.Eco.stations.forEach((s, i) => { const b = document.createElement('button'); b.dataset.tp = 'station' + i; b.textContent = '→ Станция чистки ' + (i + 1); tp.appendChild(b); });
    if (G.Eco.anemones.length) { const b = document.createElement('button'); b.dataset.tp = 'hvaten0'; b.textContent = '→ Хватень'; tp.appendChild(b); }
    if (G.Eco.swarms.length) { const b = document.createElement('button'); b.dataset.tp = 'raduzh0'; b.textContent = '→ Радужники'; tp.appendChild(b); }
    if (G.Eco.clouds.length) { const b = document.createElement('button'); b.dataset.tp = 'plankton1'; b.textContent = '→ Облако планктона'; tp.appendChild(b); }
    if (G.Eco.glazuns.length) { const b = document.createElement('button'); b.dataset.tp = 'glazun0'; b.textContent = '→ Монетники и глазун'; tp.appendChild(b); }
    if (G.Eco.grot) { const b = document.createElement('button'); b.dataset.tp = 'grot'; b.textContent = '→ Гротовик'; tp.appendChild(b); }
    if (G.Eco.skalnik) { const b = document.createElement('button'); b.dataset.tp = 'skalnik'; b.textContent = '→ Скальник'; tp.appendChild(b); }
    if (G.Eco.crab) { const b = document.createElement('button'); b.dataset.tp = 'krab'; b.textContent = '→ Нора кольчужника'; tp.appendChild(b); }
    el.addEventListener('pointerdown', e => e.stopPropagation());
    el.addEventListener('click', e => {
      const b = e.target.closest('button'); if (!b) return;
      if (b.dataset.tp) P.teleport(b.dataset.tp);
      else if (b.dataset.a === 'energy') G.Ship.energy = 100;
      else if (b.dataset.a === 'hull') G.Ship.hull = 100;
      else if (b.dataset.a === 'close') P.set(false);
    });
    document.getElementById('hud').appendChild(el);
  }

  P.set = function (on) {
    P.on = !!on;
    if (P.on && !P.el) build();
    if (P.el) P.el.hidden = !P.on;
  };

  P.tick = function (raw) {
    P.frames++; P.acc += raw;
    if (P.acc >= 0.5) { P.fps = P.frames / P.acc; P.frames = 0; P.acc = 0; if (P.on) render(); }
  };
  function render() {
    const s = P.stats();
    P.el.querySelector('#dbg-text').textContent =
      `FPS ${s.fps}  вызовы ${s.calls}  треуг. ${(s.tris / 1000).toFixed(0)} тыс.\n` +
      `рыбы ${s.fish}  скребуны ${s.grazers}\nхищники ${s.preds}\n` +
      `стеклоуст на корпусе: ${s.latched ? 'да' : 'нет'}  под вуалью: ${s.hidden ? 'да' : 'нет'}\nкорабль ${s.pos}`;
  }

  P.init = function () {
    if (location.hash === '#debug') P.set(true);
    addEventListener('hashchange', () => P.set(location.hash === '#debug'));
    const stats = document.getElementById('stats');
    let taps = [];
    stats.style.pointerEvents = 'auto';
    stats.addEventListener('pointerdown', () => {
      const now = performance.now(); taps = taps.filter(t => now - t < 900); taps.push(now);
      if (taps.length >= 3) { taps = []; P.set(!P.on); }
    });
  };
})(window.G);
