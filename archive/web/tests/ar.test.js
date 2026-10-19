'use strict';
/* AR на телефоне: кнопка по поддержке браузера, прицел hit-test, голостол на столе */
T.describe('AR', () => {
  const AR = () => G.AR;
  const fakeXR = ok => ({ isSessionSupported: async mode => ok && mode === 'immersive-ar' });
  /* поза поверхности: стол в метре впереди и на 70 см ниже телефона */
  const tableAt = (x, y, z) => new THREE.Matrix4().makeTranslation(x, y, z).toArray();

  T.test('кнопка AR появляется только там, где браузер умеет immersive-ar', async () => {
    const b = document.getElementById('b-ar');
    T.ok(await AR().check(fakeXR(true)), 'поддержка не распознана'); T.ok(!b.hidden, 'кнопки нет');
    T.ok(!(await AR().check(fakeXR(false)))); T.ok(b.hidden, 'кнопка без поддержки');
    T.ok(!(await AR().check(null))); T.ok(b.hidden);
  });

  T.test('сцена AR: голостол с картой сонара спрятан до установки', () => {
    T.ok(AR().scene && AR().holo && AR().reticle);
    T.ok(!AR().holo.visible); T.ok(!AR().reticle.visible);
    const disc = AR().holo.children.find(m => m.material && m.material.map === G.Sonar.tex);
    T.ok(disc, 'на голостоле нет карты сонара');
    T.ok(!AR().camera.parent, 'у камеры AR есть родитель — XR поставит её не туда');
  });

  T.test('hit-test двигает прицел, касание ставит голостол на стол', () => {
    AR().placed = false;
    AR().onHit(tableAt(0, -0.7, -1));
    T.ok(AR().reticle.visible, 'прицела нет');
    T.ok(AR().onSelect(), 'касание не поставило стол');
    T.ok(AR().holo.visible && AR().placed);
    T.near(AR().holo.position.y, -0.7, 1e-6); T.near(AR().holo.position.z, -1, 1e-6);
    T.ok(!AR().reticle.visible, 'прицел остался после установки');
    AR().onHit(tableAt(2, 0, 0)); T.near(AR().holo.position.x, 0, 1e-6, 'стол уехал за новой позой');
    AR().onEnd(); T.ok(!AR().holo.visible && !AR().placed);
  });

  T.test('без поверхности касание ничего не ставит (контроль)', () => {
    AR().onEnd(); AR().onHit(null);
    T.ok(!AR().onSelect()); T.ok(!AR().holo.visible);
  });

  T.test('кадр XR берёт позу из hit-test', () => {
    AR().onEnd();
    AR().hitSource = {};
    const frame = { getHitTestResults: () => [{ getPose: () => ({ transform: { matrix: tableAt(0.3, -0.6, -0.8) } }) }] };
    AR().frame(frame, {});
    T.ok(AR().reticle.visible);
    T.near(new THREE.Vector3().setFromMatrixPosition(AR().reticle.matrix).x, 0.3, 1e-6);
    AR().frame({ getHitTestResults: () => [] }, {}); T.ok(!AR().reticle.visible, 'прицел без поверхности');
    AR().hitSource = null;
  });

  /* поза стены: нормаль (ось Y позы) смотрит в комнату по +X */
  const wallAt = (x, y, z) => new THREE.Matrix4().makeRotationZ(-Math.PI / 2).setPosition(x, y, z).toArray();
  const place = () => { AR().onEnd(); AR().onHit(tableAt(0, -0.7, -1)); AR().onSelect(); };

  T.test('после стола касание по стене вешает иллюминатор, по полу — нет', () => {
    place();
    AR().onHit(tableAt(1, -1.4, 0)); T.ok(!AR().reticle.visible, 'прицел на полу после стола');
    T.ok(!AR().onSelect()); T.eq(AR().windows.length, 0);
    AR().onHit(wallAt(-1.5, 0.2, -1)); T.ok(AR().reticle.visible, 'прицел не видит стену');
    T.ok(AR().onSelect(), 'иллюминатор не повесился');
    T.eq(AR().windows.length, 1);
    const w = AR().windows[0]; T.near(w.n.x, 1, 1e-6, 'иллюминатор смотрит не в комнату');
    T.ok(w.g.children[0].material.map === w.rt.texture, 'в иллюминаторе не океан');
    AR().onEnd(); T.eq(AR().windows.length, 0, 'иллюминаторы остались после выхода из AR');
  });

  T.test('если стен не нашлось, иллюминаторы встают вокруг стола сами', () => {
    place();
    AR().frame(null, null, 5); T.eq(AR().windows.length, 0);
    AR().frame(null, null, 4); T.eq(AR().windows.length, 3, 'нет иллюминаторов вокруг стола');
    AR().windows.forEach(w => T.near(w.pos.distanceTo(AR().holo.position), Math.hypot(1.8, 0.6), 0.02));
    AR().onEnd();
  });

  T.test('иллюминатор слева от стола показывает океан слева от корабля', () => {
    place(); G.Ship.yaw = 0; G.Ship.applyTransform();
    const w = AR().addWindow(new THREE.Vector3(-1.8, -0.1, -1), new THREE.Vector3(1, 0, 0));
    const d = AR().windowDir(w, new THREE.Vector3(0, -0.1, -1), new THREE.Vector3());
    T.lt(d.x, -0.99, 'смотрит не влево');
    G.Ship.yaw = Math.PI / 2; G.Ship.applyTransform(); // корабль повернул налево — вид тоже
    AR().windowDir(w, new THREE.Vector3(0, -0.1, -1), d);
    T.gt(d.z, 0.99);
    /* отрисовка в текстуру: XR на время выключен и включён обратно */
    const calls = []; const fake = { xr: { enabled: true }, getRenderTarget: () => null, setRenderTarget: rt => calls.push(['rt', !!rt, fake.xr.enabled]), render: () => calls.push(['render', fake.xr.enabled]) };
    T.eq(AR().renderWindows(fake, new THREE.Scene()), 1);
    T.eq(JSON.stringify(calls), JSON.stringify([['rt', true, false], ['render', false], ['rt', false, false]]));
    T.ok(fake.xr.enabled, 'XR не включился обратно');
    G.Ship.yaw = 0; G.Ship.applyTransform(); AR().onEnd();
  });
});
