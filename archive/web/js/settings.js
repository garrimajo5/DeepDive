'use strict';
/* Настройки: чувствительность обзора, инверсия по вертикали, громкость, качество графики, защита от укачивания,
   свёрнутая лента событий.
   Хранятся отдельно от журнала (сброс прогресса их не трогает) и применяются сразу. */
(function (G) {
  const KEY = 'pogrujenie.settings.v1';
  const DEF = { sens: 1, invert: false, volume: 0.7, quality: 'auto', comfort: true, feedMin: false };
  const QUALITY = ['auto', 'low', 'mid', 'high'];
  const QNAME = { auto: 'Авто', low: 'Низкое', mid: 'Среднее', high: 'Высокое' };
  const St = G.Settings = { KEY, QUALITY, QNAME, v: Object.assign({}, DEF), el: null, back: null };
  function store() { try { return window.localStorage; } catch (_) { return null; } }
  const round1 = x => Math.round(x * 10) / 10;

  /* приводит значения к допустимым: битые данные не ломают игру */
  function clean(o) {
    const r = Object.assign({}, DEF);
    if (!o || typeof o !== 'object') return r;
    if (typeof o.sens === 'number' && isFinite(o.sens)) r.sens = round1(G.clamp(o.sens, 0.4, 2));
    if (typeof o.invert === 'boolean') r.invert = o.invert;
    if (typeof o.volume === 'number' && isFinite(o.volume)) r.volume = round1(G.clamp(o.volume, 0, 1));
    if (QUALITY.includes(o.quality)) r.quality = o.quality;
    if (typeof o.comfort === 'boolean') r.comfort = o.comfort;
    if (typeof o.feedMin === 'boolean') r.feedMin = o.feedMin;
    return r;
  }
  St.defaults = () => Object.assign({}, DEF);
  St.apply = function () {
    G.Audio.setVolume(St.v.volume);
    if (G.Game.setQuality) G.Game.setQuality(St.v.quality);
    if (G.Game.renderFeed) G.Game.renderFeed();
  };
  St.set = function (key, val) {
    const next = Object.assign({}, St.v); next[key] = val;
    St.v = clean(next); St.apply(); St.save(); St.render();
    return St.v[key];
  };
  St.save = function () { const s = store(); if (!s) return false; try { s.setItem(KEY, JSON.stringify(St.v)); return true; } catch (_) { return false; } };
  St.load = function () {
    const s = store(); let raw = null;
    try { raw = s && s.getItem(KEY); } catch (_) { raw = null; }
    let data = null; try { data = raw ? JSON.parse(raw) : null; } catch (_) { data = null; }
    St.v = clean(data); St.apply(); St.render();
    return !!data;
  };
  St.reset = function (wipe) {
    St.v = St.defaults();
    if (wipe) { const s = store(); try { if (s) s.removeItem(KEY); } catch (_) {} } else St.save();
    St.apply(); St.render();
  };
  /* множители для обзора: свайп по X и по Y */
  St.lookX = () => St.v.sens;
  St.lookY = () => St.v.sens * (St.v.invert ? -1 : 1);
  /* защита от укачивания: горизонт без крена, без покачивания шага, слабее тряска, затемнение краёв на поворотах */
  St.comfort = () => St.v.comfort;

  /* ---------- экран настроек ---------- */
  St.isOpen = () => !!St.el && !St.el.hidden;
  St.open = function () {
    if (!St.el || St.isOpen()) return;
    St.back = G.Game.state; G.Game.state = 'settings';
    St.render(); St.el.hidden = false; G.Audio.beep(520);
  };
  St.close = function () {
    if (!St.isOpen()) return;
    St.el.hidden = true; G.Game.state = St.back || 'play'; St.back = null;
    if (G.Game.resumeClock) G.Game.resumeClock();
  };
  const pct = v => Math.round(v * 100) + '%';
  St.render = function () {
    if (!St.el) return;
    const v = St.v, q = St.el.querySelector.bind(St.el);
    q('[data-v="sens"]').textContent = v.sens.toFixed(1) + '×';
    q('[data-v="volume"]').textContent = v.volume === 0 ? 'выкл' : pct(v.volume);
    const inv = q('[data-a="invert"]'); inv.textContent = v.invert ? 'Вкл' : 'Выкл'; inv.classList.toggle('on', v.invert);
    const cf = q('[data-a="comfort"]'); cf.textContent = v.comfort ? 'Вкл' : 'Выкл'; cf.classList.toggle('on', v.comfort);
    St.el.querySelectorAll('[data-q]').forEach(b => b.classList.toggle('on', b.dataset.q === v.quality));
    q('[data-a="sens-"]').disabled = v.sens <= 0.4; q('[data-a="sens+"]').disabled = v.sens >= 2;
    q('[data-a="vol-"]').disabled = v.volume <= 0; q('[data-a="vol+"]').disabled = v.volume >= 1;
    const pr = G.Game.debug && G.Game.debug.pixelRatio;
    q('#set-qhint').textContent = (v.quality === 'auto' ? 'Разрешение подстраивается под плавность.' : v.quality === 'low' ? 'Без световых столбов, низкое разрешение — для слабых телефонов.' : 'Разрешение зафиксировано.') + (pr ? ` Сейчас ×${pr.toFixed(2)}.` : '');
    const sb = document.getElementById('b-settings'); if (sb) sb.classList.toggle('off', v.volume === 0);
  };
  St.init = function () {
    St.el = document.getElementById('settings');
    St.el.addEventListener('click', e => {
      const b = e.target.closest('button'); if (!b) return;
      const a = b.dataset.a, v = St.v;
      if (b.dataset.q) St.set('quality', b.dataset.q);
      else if (a === 'sens-') St.set('sens', v.sens - 0.2);
      else if (a === 'sens+') St.set('sens', v.sens + 0.2);
      else if (a === 'vol-') { G.Audio.init(); St.set('volume', v.volume - 0.1); }
      else if (a === 'vol+') { G.Audio.init(); St.set('volume', v.volume + 0.1); G.Audio.beep(700); }
      else if (a === 'invert') St.set('invert', !v.invert);
      else if (a === 'comfort') St.set('comfort', !v.comfort);
      else if (a === 'defaults') St.reset(false);
      else if (a === 'close') St.close();
    });
    St.el.addEventListener('pointerdown', e => e.stopPropagation());
    St.load();
  };
})(window.G);
