'use strict';
/* Защита от укачивания: ровный горизонт, без покачивания шага, слабая тряска, тень по краям на поворотах */
T.describe('Защита от укачивания', () => {
  const St = G.Settings, S = () => G.Ship, D = () => G.Game.debug, cam = () => D().camera;
  const vigOpacity = () => parseFloat(document.getElementById('fx-vignette').style.opacity || '0');
  const turnAtHelm = (n) => { G.Game.toggleHelm(); G.Ctl.padMove.y = 1; G.Ctl.padMove.x = 1; D().frame(n); };

  T.test('включена по умолчанию, кнопка в настройках переключает и сохраняет', () => {
    T.eq(St.v.comfort, true);
    St.open();
    const b = document.querySelector('#settings [data-a="comfort"]');
    T.eq(b.textContent, 'Вкл'); T.ok(b.classList.contains('on'));
    b.click();
    T.eq(St.v.comfort, false); T.eq(b.textContent, 'Выкл');
    St.close();
    St.v = St.defaults(); T.ok(St.load());
    T.eq(St.v.comfort, false, 'после перезагрузки');
    localStorage.setItem(St.KEY, JSON.stringify({ comfort: 'нет' }));
    St.load(); T.eq(St.v.comfort, true, 'битое значение');
  });
  T.test('на повороте за штурвалом горизонт не заваливается', () => {
    turnAtHelm(60);
    T.gt(Math.abs(S().turn), 0.5, 'корабль поворачивает');
    T.lt(Math.abs(S().roll), 1e-6); T.lt(Math.abs(S().pitch), 1e-6);
  });
  T.test('без защиты корабль кренится на повороте', () => {
    St.set('comfort', false);
    turnAtHelm(60);
    T.gt(Math.abs(S().roll), 0.02);
  });
  T.test('тень по краям появляется на повороте и гаснет на прямом ходу', () => {
    turnAtHelm(30);
    T.gt(G.Game.vignette, 0.4); T.gt(vigOpacity(), 0.4);
    G.Ctl.padMove.x = 0; D().frame(80);
    T.eq(G.Game.vignette, 0); T.eq(vigOpacity(), 0);
  });
  T.test('без защиты тени нет', () => {
    St.set('comfort', false);
    turnAtHelm(30);
    T.eq(G.Game.vignette, 0); T.eq(vigOpacity(), 0);
  });
  T.test('при ходьбе голова не покачивается', () => {
    const ys = new Set();
    G.Ctl.padMove.y = 1;
    for (let i = 0; i < 10; i++) { D().frame(1); ys.add(cam().position.y.toFixed(4)); }
    T.eq(ys.size, 1, 'высота взгляда');
    St.set('comfort', false); ys.clear();
    G.Ctl.padMove.y = -1;
    for (let i = 0; i < 10; i++) { D().frame(1); ys.add(cam().position.y.toFixed(4)); }
    T.gt(ys.size, 3, 'без защиты шаг покачивает');
  });
  T.test('тряска от удара слабее', () => {
    const maxDev = () => { let m = 0; for (let i = 0; i < 20; i++) { G.Game.shake = 1; D().frame(1); m = Math.max(m, Math.abs(cam().position.y - 1.65)); } return m; };
    const soft = maxDev();
    St.set('comfort', false);
    const hard = maxDev();
    T.lt(soft, 0.1); T.gt(hard, 0.12); T.gt(hard, soft * 1.8);
  });
});
