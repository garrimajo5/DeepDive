'use strict';
/* Общий маркер стола. Квадрат 15 см с рисунком из блоков, крестом в центре и стрелкой «НОС».
   Его печатают (marker.html) и кладут на стол. Телефоны, которые умеют отслеживать картинки (WebXR image-tracking),
   сами ставят голостол на маркер. Остальные ставят по двум касаниям: центр креста, потом стрелка «НОС».
   Так у всех телефонов голостол стоит в одном месте и нос корабля смотрит в одну сторону.
   Рисунок без three.js — его рисует и страница для печати. */
(function (G) {
  const SIZE_M = 0.15, GRID = 8;
  const Mk = G.Marker = { SIZE_M, GRID };
  /* детерминированный узор: одинаковый на всех устройствах; верх и низ разные, чтобы различать поворот */
  Mk.cells = function () {
    const out = []; let s = 7;
    for (let j = 0; j < GRID; j++) for (let i = 0; i < GRID; i++) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      const inArrow = j < 3 && i >= 2 && i <= 5, inCross = j >= 3 && j <= 4 && i >= 3 && i <= 4;
      out.push(!inArrow && !inCross && (s >> 16) % 2 ? 1 : 0);
    }
    return out;
  };
  Mk.draw = function (ctx, size) {
    const b = size * 0.08, inner = size - b * 2, c = inner / GRID;
    ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, size, size);
    ctx.fillStyle = '#000'; ctx.fillRect(0, 0, size, b); ctx.fillRect(0, size - b, size, b); ctx.fillRect(0, 0, b, size); ctx.fillRect(size - b, 0, b, size);
    Mk.cells().forEach((v, k) => { if (v) ctx.fillRect(b + (k % GRID) * c, b + Math.floor(k / GRID) * c, c + 0.5, c + 0.5); });
    /* стрелка «НОС» к верхнему краю */
    const cx = size / 2;
    ctx.beginPath(); ctx.moveTo(cx, b + c * 0.2); ctx.lineTo(cx + c * 1.6, b + c * 1.7); ctx.lineTo(cx + c * 0.6, b + c * 1.7); ctx.lineTo(cx + c * 0.6, b + c * 2.8); ctx.lineTo(cx - c * 0.6, b + c * 2.8); ctx.lineTo(cx - c * 0.6, b + c * 1.7); ctx.lineTo(cx - c * 1.6, b + c * 1.7); ctx.closePath(); ctx.fill();
    /* крест в центре */
    ctx.lineWidth = Math.max(2, c * 0.14); ctx.strokeStyle = '#000';
    ctx.beginPath(); ctx.moveTo(cx - c * 0.9, cx); ctx.lineTo(cx + c * 0.9, cx); ctx.moveTo(cx, cx - c * 0.9); ctx.lineTo(cx, cx + c * 0.9); ctx.stroke();
    ctx.font = `700 ${Math.round(b * 0.62)}px sans-serif`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillStyle = '#fff';
    ctx.fillText('НОС', cx, b / 2); ctx.fillText('КОВЧЕГ-7', cx, size - b / 2);
  };
  Mk.canvas = function (size) {
    const cv = document.createElement('canvas'); cv.width = cv.height = size || 512;
    Mk.draw(cv.getContext('2d'), cv.width); return cv;
  };
})(window.G = window.G || {});
