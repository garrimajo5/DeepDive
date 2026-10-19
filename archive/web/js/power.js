'use strict';
/* Машинное отделение: реактор даёт 100 единиц, инженер делит их между пятью системами.
   Доля системы меняет её силу: тягу двигателей, дальность сонара, восстановление корпуса,
   радиус разряда и дальность луча прожектора. У нуля система обесточена.
   Пульт: крестовина вверх/вниз выбирает систему, влево/вправо снимает или добавляет 5 единиц,
   кнопка действия закрывает пульт. На телефоне работают и кнопки −/+ на панели. */
(function (G) {
  const KEYS = ['eng', 'son', 'life', 'zap', 'lamp'];
  const NAME = { eng: 'Двигатели', son: 'Сонар', life: 'Жизнеобеспечение', zap: 'Разряд по корпусу', lamp: 'Прожектор' };
  const HINT = { eng: 'тяга', son: 'дальность импульса', life: 'ремонт корпуса', zap: 'радиус разряда', lamp: 'дальность луча' };
  const DEF = { eng: 30, son: 20, life: 25, zap: 15, lamp: 10 }; // базовые доли: при них системы работают как раньше
  const TOTAL = 100, MAX = 60, STEP = 5;
  /* перегрев: у чёрного курильщика (тёплая вода плохо охлаждает) или раз в несколько минут реактор
     держит только SAFE единиц. Лишняя нагрузка греет его; на 100° — аварийный сброс: все системы
     обесточены на SCRAM секунд. Если урезать нагрузку до предела, реактор остывает и событие кончается. */
  const SAFE = 60, SCRAM = 12, HEAT_UP = 0.12, COOL = 0.25, MIN_T = 20, VENT_R = 45, PERIOD = 420, FIRST = 240;
  const P = G.Power = { KEYS, NAME, DEF, TOTAL, MAX, STEP, SAFE, v: Object.assign({}, DEF), sel: 0, el: null, open: false, held: 0, rep: 0,
    hot: false, heat: 0, hotT: 0, scram: 0, nextHot: FIRST, ventCd: 0 };

  P.used = () => KEYS.reduce((a, k) => a + P.v[k], 0);
  P.free = () => TOTAL - P.used();
  /* множитель системы относительно базовой доли: 1 — как раньше, 0 — обесточена */
  P.k = key => (P.scram > 0 ? 0 : P.v[key] / DEF[key]); // при аварийном сбросе всё обесточено
  P.limit = () => (P.hot ? SAFE : TOTAL);
  P.set = function (key, val) {
    if (!KEYS.includes(key)) return P.v[key];
    const others = P.used() - P.v[key];
    P.v[key] = Math.max(0, Math.min(MAX, Math.round(val / STEP) * STEP, TOTAL - others));
    P.render(); G.Ship.drawPower && G.Ship.drawPower();
    return P.v[key];
  };
  P.add = (key, d) => P.set(key, P.v[key] + d);
  P.reset = function () {
    P.v = Object.assign({}, DEF); P.sel = 0; if (P.open) P.close();
    P.hot = false; P.heat = 0; P.hotT = 0; P.scram = 0; P.nextHot = FIRST; P.ventCd = 0;
    P.render(); G.Ship.drawPower && G.Ship.drawPower();
  };
  P.startHot = function (why) {
    if (P.hot) return false;
    P.hot = true; P.hotT = 0; P.heat = Math.max(P.heat, 20);
    G.Game.toast('Перегрев реактора', `${why === 'vent' ? 'Тёплая вода у курильщика не охлаждает реактор. ' : ''}Безопасно только ${SAFE} единиц — урежьте нагрузку в машинном отделении.`, 5000);
    G.Game.feedMsg && G.Game.feedMsg(`Перегрев реактора: держите нагрузку не выше ${SAFE}`);
    G.Audio.alarm(); P.render(); return true;
  };
  P.update = function (dt, t) {
    const S = G.Ship;
    P.ventCd -= dt;
    if (P.scram > 0) { P.scram -= dt; if (P.scram <= 0) { P.heat = 50; G.Game.toast('Реактор перезапущен', 'Системы снова под напряжением. Урежьте нагрузку, пока он не перегрелся снова.'); } }
    if (!P.hot) {
      P.nextHot -= dt;
      const vent = G.World.pois.find(p => p.key === 'geyser');
      const nearVent = vent && Math.hypot(S.pos.x - vent.pos.x, S.pos.z - vent.pos.z) < VENT_R;
      if (nearVent && P.ventCd <= 0) { P.ventCd = 90; P.startHot('vent'); }
      else if (P.nextHot <= 0) P.startHot('time');
      if (!P.hot) P.heat = Math.max(0, P.heat - dt * 2);
    } else {
      P.hotT += dt;
      const over = P.used() - SAFE;
      if (P.scram <= 0) P.heat = Math.max(0, Math.min(100, P.heat + (over > 0 ? over * HEAT_UP : (over - 5) * COOL) * dt)); // при 60 остывает ~1,25°/с
      if (P.heat >= 100 && P.scram <= 0) {
        P.scram = SCRAM; S.light = false;
        G.Game.toast('Аварийный сброс реактора', `Все системы обесточены на ${SCRAM} секунд.`, 5000);
        G.Game.feedMsg && G.Game.feedMsg('Аварийный сброс реактора: системы обесточены');
        G.Audio.alarm();
      }
      if (P.heat <= 0 && P.hotT > MIN_T) { // остыл
        P.hot = false; P.nextHot = PERIOD;
        G.Game.toast('Реактор остыл', 'Можно снова раздать все 100 единиц.');
        G.Game.feedMsg && G.Game.feedMsg('Реактор остыл');
      }
    }
    P.renderT = (P.renderT || 0) - dt;
    if (P.renderT <= 0) { P.renderT = 0.25; P.render(); G.Ship.drawPower && G.Ship.drawPower(); P.alert(); }
  };
  P.alert = function () {
    const el = document.getElementById('alert'); if (!el || (G.Breach && G.Breach.active)) return; // пробоина важнее
    const on = P.hot || P.scram > 0;
    if (!on) { if (P.shown) { el.hidden = true; P.shown = false; } return; } // чужое табло не трогаем
    el.hidden = false; P.shown = true;
    el.textContent = P.scram > 0 ? `АВАРИЙНЫЙ СБРОС · ${Math.ceil(P.scram)} с` : `ПЕРЕГРЕВ ${Math.round(P.heat)}° · НАГРУЗКА ${P.used()}/${SAFE}`;
  };

  /* ---------- пульт ---------- */
  P.isOpen = () => P.open;
  P.toggle = () => (P.open ? P.close() : P.openPanel());
  P.openPanel = function () {
    if (!P.el) return;
    P.open = true; P.el.hidden = false; P.held = 0; P.render(); G.Audio.beep(560);
    if (!P.hinted) { P.hinted = true; G.Game.toast('Пульт энергии', 'Крестовина вверх-вниз выбирает систему, влево-вправо снимает или добавляет 5 единиц. Круглая кнопка — закрыть.'); }
  };
  P.close = function () { if (!P.el) return; P.open = false; P.el.hidden = true; G.Audio.beep(420); };
  /* ввод с крестовины: срабатывает при нажатии и повторяется, пока держат */
  P.nav = function (mx, my, dt) {
    const dir = Math.abs(my) > 0.5 ? (my > 0 ? 'up' : 'down') : Math.abs(mx) > 0.5 ? (mx > 0 ? 'right' : 'left') : null;
    if (!dir) { P.held = null; return; }
    if (dir === P.held) { P.rep -= dt; if (P.rep > 0) return; P.rep = 0.18; } else { P.held = dir; P.rep = 0.4; }
    if (dir === 'up') P.sel = (P.sel + KEYS.length - 1) % KEYS.length;
    else if (dir === 'down') P.sel = (P.sel + 1) % KEYS.length;
    else { const before = P.v[KEYS[P.sel]]; if (P.add(KEYS[P.sel], dir === 'right' ? STEP : -STEP) !== before) G.Audio.beep(dir === 'right' ? 700 : 500); }
    P.render();
  };

  P.render = function () {
    if (!P.el) return;
    KEYS.forEach((k, i) => {
      const row = P.el.querySelector(`[data-k="${k}"]`); if (!row) return;
      row.classList.toggle('sel', i === P.sel);
      row.querySelector('output').textContent = P.v[k];
      row.querySelector('i').style.width = (P.v[k] / MAX * 100) + '%';
      row.querySelector('[data-d="-"]').disabled = P.v[k] <= 0;
      row.querySelector('[data-d="+"]').disabled = P.v[k] >= MAX || P.free() <= 0;
      row.classList.toggle('off', P.v[k] === 0);
    });
    P.el.querySelector('#pw-free').textContent = P.scram > 0 ? `Аварийный сброс: ${Math.ceil(P.scram)} с` : P.hot ? `Перегрев ${Math.round(P.heat)}° · безопасно ${SAFE}, сейчас ${P.used()}` : `Резерв: ${P.free()} из ${TOTAL}`;
    P.el.classList.toggle('hot', P.hot);
  };
  P.init = function () {
    const el = P.el = document.getElementById('power'); if (!el) return;
    el.querySelector('.pw-rows').innerHTML = KEYS.map(k => `<div class="pw-row" data-k="${k}"><div class="pw-name"><b>${NAME[k]}</b><small>${HINT[k]}</small></div>
      <button class="chip" data-d="-" type="button" aria-label="Меньше">−</button><div class="pw-bar"><i></i></div><output>0</output><button class="chip" data-d="+" type="button" aria-label="Больше">+</button></div>`).join('');
    el.addEventListener('pointerdown', e => e.stopPropagation());
    el.addEventListener('click', e => {
      const b = e.target.closest('button'); if (!b) return;
      if (b.dataset.a === 'close') { P.close(); return; }
      const row = b.closest('.pw-row'); if (!row) return;
      P.sel = KEYS.indexOf(row.dataset.k); P.add(row.dataset.k, b.dataset.d === '+' ? STEP : -STEP);
    });
    P.render();
  };
})(window.G);
