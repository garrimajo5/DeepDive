'use strict';
/* Забег. Брифинг на голостоле: экипаж выбирает маршрут по местам отмели. Маршрут рисуется на сонаре,
   на приборах видно следующую точку и расстояние до неё. Когда все точки пройдены — маршрут закрыт,
   пора решать, глубже или наверх. Брифинг: крестовина вверх/вниз — выбор, вправо — взять маршрут,
   круглая кнопка закрывает. */
(function (G) {
  const ROUTES = [
    { id: 'reef', name: 'Рифовый сад', pois: ['flower', 'bones', 'well'], desc: 'Спокойный путь между рифами. Много жизни — и много серпохвостов.' },
    { id: 'vents', name: 'Тёплые трубы', pois: ['geyser', 'shell'], desc: 'Короткий путь к Раковине древних мимо чёрного курильщика: реактор будет греться.' },
    { id: 'edge', name: 'Край отмели', pois: ['well', 'drop'], desc: 'К обрыву над Кристальным лесом. Оползни поднимают ил — готовьтесь к сонарной тьме.' }
  ];
  const R = G.Run = { ROUTES, route: null, visited: new Set(), done: false, sel: 0, open: false, el: null, hudT: 0,
    depth: 0, voteOpen: false, stats: null, ended: false };
  /* счёт забега: что экипаж успел за погружение */
  R.startStats = function () { R.stats = { t0: G.Game.t, samples: 0, species: 0, places: 0, breaches: 0, routes: 0, hits: 0 }; };
  R.note = function (k, n) { if (!R.stats) R.startStats(); R.stats[k] += n || 1; };
  const poi = key => G.World.pois.find(p => p.key === key);
  R.next = () => (R.route ? R.route.pois.map(poi).find(p => p && !R.visited.has(p.key)) || null : null);
  R.choose = function (id) {
    const r = ROUTES.find(x => x.id === id); if (!r) return false;
    R.route = r; R.visited.clear(); R.done = false;
    const n = R.next();
    G.Game.toast('Маршрут: ' + r.name, `${r.desc} Первая точка — ${n ? n.name : '—'}. Она отмечена на голостоле.`, 5000);
    G.Game.feedMsg && G.Game.feedMsg(`Экипаж выбрал маршрут «${r.name}»`, true);
    G.Audio.discover(); R.render(); R.hud(true);
    return true;
  };
  R.reset = function () {
    R.route = null; R.visited.clear(); R.done = false; R.sel = 0; R.depth = 0; R.ended = false; if (G.Echo) G.Echo.newDive();
    if (R.open) R.close(); if (R.voteOpen) R.closeVote(); R.startStats(); R.hud(true);
    const res = document.getElementById('results'); if (res) res.hidden = true;
  };
  R.update = function (dt) {
    if (R.route && !R.done) {
      const S = G.Ship;
      for (const key of R.route.pois) {
        const p = poi(key); if (!p || R.visited.has(key)) continue;
        if (Math.hypot(p.pos.x - S.pos.x, p.pos.z - S.pos.z) < p.rd) {
          R.visited.add(key);
          const n = R.next();
          if (n) { G.Game.feedMsg && G.Game.feedMsg(`Точка маршрута пройдена: ${p.name}. Дальше — ${n.name}`, true); G.Audio.beep(880); }
          else {
            R.done = true; R.note('routes');
            G.Game.toast('Маршрут пройден', `«${R.route.name}» закрыт. Экипаж собирается у голостола: глубже или наверх?`, 5000);
            G.Game.feedMsg && G.Game.feedMsg(`Маршрут «${R.route.name}» пройден`, true);
            G.Audio.discover(); R.openVote();
          }
        }
      }
    }
    R.hudT -= dt; if (R.hudT <= 0) R.hud();
  };
  /* строка маршрута на приборах */
  R.hud = function (force) {
    R.hudT = 0.3;
    const el = document.getElementById('s-route'); if (!el) return;
    el.hidden = !R.route;
    if (!R.route) return;
    const n = R.next(), S = G.Ship;
    el.textContent = R.done ? `Маршрут «${R.route.name}» пройден` : `${R.route.name} · ${R.visited.size}/${R.route.pois.length} · ${n.name} ${Math.round(Math.hypot(n.pos.x - S.pos.x, n.pos.z - S.pos.z))} м`;
  };

  /* ---------- голосование: глубже или наверх ---------- */
  /* мнения экипажа подсказывают капитану: решает голос игрока */
  R.opinions = function () {
    const S = G.Ship, P = G.Power;
    return [
      { who: 'Пилот', up: S.hull < 50, why: S.hull < 50 ? `корпус ${Math.round(S.hull)}% — второй такой удар не выдержим` : 'корабль слушается, можно идти дальше' },
      { who: 'Инженер', up: S.energy < 40 || P.hot, why: P.hot ? 'реактор перегрет' : S.energy < 40 ? `энергии ${Math.round(S.energy)} — не хватит на обратный путь` : 'реактор в норме' },
      { who: 'Сонарщик', up: !!(G.Silt && G.Silt.inside), why: G.Silt && G.Silt.inside ? 'вокруг ил, мы слепые' : 'сонар чистый' },
      { who: 'Биолог', up: S.cargo.length >= 4, why: S.cargo.length >= 4 ? `в трюме ${S.cargo.length} образцов — пора их довезти` : 'образцов мало, внизу их больше' }
    ];
  };
  R.openVote = function () {
    const el = document.getElementById('vote'); if (!el) return;
    R.voteOpen = true; el.hidden = false; R.back = G.Game.state === 'vote' ? R.back : G.Game.state; G.Game.state = 'vote'; R.voteHeld = true; // ждём, пока отпустят крестовину
    el.querySelector('.vt-crew').innerHTML = R.opinions().map(o => `<div class="vt-op ${o.up ? 'up' : 'deep'}"><b>${o.who}: ${o.up ? 'наверх' : 'глубже'}</b><small>${o.why}</small></div>`).join('');
    el.querySelector('.vt-depth').textContent = R.depth ? `Глубина забега: ${R.depth + 1}-й спуск` : 'Первый спуск';
  };
  R.closeVote = function () { const el = document.getElementById('vote'); if (R.voteOpen && G.Game.state === 'vote') G.Game.state = R.back || 'play'; R.voteOpen = false; if (el) el.hidden = true; if (G.Game.resumeClock) G.Game.resumeClock(); };
  R.isVoteOpen = () => R.voteOpen;
  R.voteNav = function (mx) { if (Math.abs(mx) < 0.5) { R.voteHeld = false; return; } if (R.voteHeld) return; R.decide(mx > 0 ? 'deep' : 'up'); };
  /* решение капитана */
  R.decide = function (choice) {
    R.closeVote();
    if (choice === 'deep') {
      R.depth++; R.route = null; R.visited.clear(); R.done = false; R.hud(true);
      const code = G.Echo ? G.Echo.newDive() : '';
      G.Game.toast('Глубже', `Экипаж идёт дальше. Хищники здесь злее (+${R.depth * 15}% к чутью). Новое кодовое слово: ${code}. Выберите новый маршрут у голостола.`, 5000);
      G.Game.feedMsg && G.Game.feedMsg(`Решение экипажа: глубже (${R.depth + 1}-й спуск)`, true);
      return 'deep';
    }
    R.finish('up'); return 'up';
  };
  /* итоги забега */
  R.finish = function (why) {
    if (!R.stats) R.startStats();
    R.ended = true;
    const st = R.stats, S = G.Ship, el = document.getElementById('results');
    const min = Math.max(0, Math.round((G.Game.t - st.t0) / 60));
    const rows = [
      ['Время под водой', `${min} мин`], ['Спусков', R.depth + 1], ['Маршрутов пройдено', st.routes],
      ['Новых видов в журнале', st.species], ['Новых мест', st.places], ['Образцов поднято', st.samples],
      ['Улучшений', G.Cargo.owned.size], ['Пробоин заварено', st.breaches], ['Корпус на финише', Math.round(S.hull) + '%']
    ];
    const score = st.species * 10 + st.places * 15 + st.samples * 5 + st.routes * 20 + R.depth * 25 + Math.round(S.hull / 10);
    if (el) {
      el.querySelector('.rs-title').textContent = why === 'up' ? 'Экипаж поднялся наверх' : 'Забег окончен';
      el.querySelector('.rs-rows').innerHTML = rows.map(([k, v]) => `<div><span>${k}</span><b>${v}</b></div>`).join('');
      el.querySelector('.rs-score').textContent = `Очки экспедиции: ${score}`;
      el.hidden = false;
    }
    G.Game.state = 'results';
    R.score = score;
    return score;
  };
  R.predK = () => 1 + R.depth * 0.15; // чутьё хищников растёт с каждым спуском

  /* ---------- панель брифинга ---------- */
  R.isOpen = () => R.open;
  R.toggle = () => (R.open ? R.close() : R.openPanel());
  R.openPanel = function () { if (!R.el) return; R.open = true; R.el.hidden = false; R.held = null; R.render(); G.Audio.beep(560); };
  R.close = function () { if (!R.el) return; R.open = false; R.el.hidden = true; G.Audio.beep(420); };
  R.nav = function (mx, my) {
    const dir = Math.abs(my) > 0.5 ? (my > 0 ? 'up' : 'down') : mx > 0.5 ? 'right' : null;
    if (!dir) { R.held = null; return; }
    if (dir === R.held) return; R.held = dir;
    if (dir === 'up') R.sel = (R.sel + ROUTES.length - 1) % ROUTES.length;
    else if (dir === 'down') R.sel = (R.sel + 1) % ROUTES.length;
    else { R.choose(ROUTES[R.sel].id); R.close(); }
    R.render();
  };
  R.render = function () {
    if (!R.el) return;
    R.el.querySelectorAll('.cg-row').forEach((row, i) => {
      row.classList.toggle('sel', i === R.sel);
      row.classList.toggle('own', !!R.route && R.route.id === ROUTES[i].id);
      row.querySelector('button').textContent = R.route && R.route.id === ROUTES[i].id ? 'Выбран' : 'Выбрать';
    });
  };
  R.init = function () {
    const el = R.el = document.getElementById('brief'); if (!el) return;
    el.querySelector('.cg-rows').innerHTML = ROUTES.map(r => `<div class="cg-row" data-r="${r.id}"><div class="pw-name"><b>${r.name}</b><small>${r.pois.map(k => (poi(k) || {}).name).join(' → ')} · ${r.desc}</small></div><button class="chip" type="button">Выбрать</button></div>`).join('');
    el.addEventListener('pointerdown', e => e.stopPropagation());
    el.addEventListener('click', e => {
      const b = e.target.closest('button'); if (!b) return;
      if (b.dataset.a === 'close') { R.close(); return; }
      const row = b.closest('.cg-row'); if (!row) return;
      R.sel = ROUTES.findIndex(r => r.id === row.dataset.r); R.choose(row.dataset.r); R.close();
    });
    R.render(); R.hud(true); R.startStats();
    const vote = document.getElementById('vote');
    if (vote) {
      vote.addEventListener('pointerdown', e => e.stopPropagation());
      vote.addEventListener('click', e => { const b = e.target.closest('button'); if (b && b.dataset.v) R.decide(b.dataset.v); });
    }
  };
})(window.G);
