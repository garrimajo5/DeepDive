'use strict';
/* Обучение первых минут: пять шагов-заданий, которые засчитываются по действиям игрока.
   Прогресс хранится в сохранении, пройденное обучение не показывается снова. */
(function (G) {
  const Tu = G.Tutorial = { i: 0, done: false, mark: null, el: null };
  Tu.steps = [
    { id: 'helm', text: 'Подойдите к штурвалу у носового окна и нажмите круглую кнопку', check: () => G.Game.piloting },
    { id: 'move', text: 'Ведите корабль крестовиной: проплывите 20 метров', check: () => Tu.mark && G.Ship.pos.distanceTo(Tu.mark.pos) > 20 },
    { id: 'ping', text: 'Нажмите «Сонар»: голостол покажет существ и необычные места', check: () => Tu.mark && G.Sonar.pingT > Tu.mark.t },
    { id: 'scan', text: 'Наведите прицел на существо в окне и удерживайте круглую кнопку', check: () => G.SPECIES_ORDER.some(k => G.SPECIES[k].scanned) },
    { id: 'lab', text: 'Встаньте, откройте люк в корме мостика и пройдите в лабораторию', check: () => !G.Game.piloting && G.Game.room === 'lab' }
  ];
  function enter() { Tu.mark = { pos: G.Ship.pos.clone(), t: G.Game.t }; }
  Tu.render = function () {
    if (!Tu.el) return;
    Tu.el.hidden = Tu.done;
    if (Tu.done) return;
    Tu.el.querySelector('b').textContent = `Шаг ${Tu.i + 1} из ${Tu.steps.length}`;
    Tu.el.querySelector('span').textContent = Tu.steps[Tu.i].text;
  };
  Tu.update = function () {
    if (Tu.done) return;
    if (!Tu.mark) enter();
    if (Tu.steps[Tu.i].check()) {
      Tu.i++; G.Audio.beep(880); G.Save.mark();
      if (Tu.i >= Tu.steps.length) { Tu.done = true; G.Game.toast('Обучение пройдено', 'Дальше — сами: изучите шесть видов и найдите шесть мест.'); }
      enter(); Tu.render();
    }
  };
  Tu.skip = function () { Tu.done = true; Tu.i = Tu.steps.length; G.Save.mark(); Tu.render(); };
  Tu.restart = function () { Tu.done = false; Tu.i = 0; Tu.mark = null; Tu.render(); };
  Tu.state = () => ({ i: Tu.i, done: Tu.done });
  Tu.apply = function (s) {
    if (!s) return;
    Tu.i = Math.max(0, Math.min(Tu.steps.length, s.i | 0)); Tu.done = !!s.done || Tu.i >= Tu.steps.length; Tu.mark = null; Tu.render();
  };
  Tu.init = function () {
    Tu.el = document.getElementById('tut');
    Tu.el.querySelector('button').addEventListener('click', Tu.skip);
    Tu.el.addEventListener('pointerdown', e => e.stopPropagation());
    Tu.render();
  };
})(window.G);
