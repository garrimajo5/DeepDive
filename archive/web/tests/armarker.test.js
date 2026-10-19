'use strict';
/* Общий маркер стола: два телефона ставят голостол в одно место и одинаково поворачивают нос */
T.describe('Общий маркер стола', () => {
  const AR = () => G.AR, V3 = THREE.Vector3;
  const flat = p => new THREE.Matrix4().makeTranslation(p.x, p.y, p.z).toArray();
  /* комната: маркер на столе, стрелка «НОС» смотрит по +X комнаты */
  const C = new V3(0.2, -0.7, -1), NOSE = new V3(0.5, -0.7, -1), WIN = new V3(-1.2, 0, -2.4), EYE = new V3(0.6, -0.1, 0.3);
  /* у каждого телефона свои оси: поворот и сдвиг относительно комнаты */
  const phone = (a, t) => p => p.clone().applyAxisAngle(new V3(0, 1, 0), a).add(t);
  const shipDir = (to, nose) => {
    AR().onEnd(); G.Ship.yaw = 0; G.Ship.applyTransform();
    AR().onHit(flat(to(C))); AR().onSelect();
    if (nose) { AR().onHit(flat(to(NOSE))); T.ok(AR().reticle.visible, 'прицел не видит стрелку на столе'); T.ok(AR().onSelect(), 'касание по стрелке не принято'); }
    const n = new V3(1, 0, 0).applyAxisAngle(new V3(0, 1, 0), 0); // нормаль не важна для направления
    const w = AR().addWindow(to(WIN), n);
    return AR().windowDir(w, to(EYE), new V3());
  };

  T.test('касание по стрелке «НОС» поворачивает стол носом туда', () => {
    AR().onEnd(); AR().onHit(flat(C)); AR().onSelect();
    T.eq(AR().yaw, 0); T.ok(!AR().nosed);
    AR().onHit(flat(NOSE)); T.ok(AR().onSelect());
    T.near(AR().yaw, -Math.PI / 2, 1e-6, 'нос не по +X'); T.ok(AR().nosed);
    T.near(AR().holo.rotation.y, -Math.PI / 2, 1e-6, 'голостол не повернулся');
    T.near(AR().holo.position.x, C.x, 1e-6, 'стол сдвинулся от касания по стрелке');
    AR().onEnd(); T.eq(AR().yaw, 0); T.ok(!AR().nosed);
  });

  T.test('два телефона с разными осями видят океан в иллюминаторе одинаково', () => {
    const A = phone(0, new V3()), B = phone(1.1, new V3(2.5, 0.3, -1.7));
    const da = shipDir(A, true), db = shipDir(B, true);
    T.gt(da.dot(db), 0.9999, `направления разные: ${da.toArray().map(v => v.toFixed(3))} / ${db.toArray().map(v => v.toFixed(3))}`);
    /* нос по +X комнаты: иллюминатор слева от стрелки по ходу смотрит на левый борт (−X корабля) */
    T.lt(da.x, -0.3, 'иллюминатор слева от носа показывает не левый борт');
    AR().onEnd();
  });

  T.test('без касания по стрелке телефоны расходятся (контроль)', () => {
    const A = phone(0, new V3()), B = phone(1.1, new V3(2.5, 0.3, -1.7));
    const da = shipDir(A, false), db = shipDir(B, false);
    T.lt(da.dot(db), 0.9, 'и без маркера совпало — тест ничего не проверяет');
    AR().onEnd();
  });

  T.test('касания вдали от стола и на полу нос не трогают', () => {
    AR().onEnd(); AR().onHit(flat(C)); AR().onSelect();
    AR().onHit(flat(new V3(C.x + 2, C.y, C.z))); T.ok(!AR().reticle.visible); T.ok(!AR().onSelect());
    AR().onHit(flat(new V3(C.x + 0.4, C.y - 0.7, C.z))); T.ok(!AR().onSelect());
    T.eq(AR().yaw, 0); AR().onEnd();
  });

  T.test('телефон узнал маркер камерой: стол встаёт на маркер носом по стрелке', () => {
    AR().onEnd(); AR().hitSource = {};
    const pose = new THREE.Matrix4().makeRotationY(-Math.PI / 2).setPosition(C.x, C.y, C.z).toArray();
    let state = 'emulated';
    const frame = { getHitTestResults: () => [], getImageTrackingResults: () => [{ trackingState: state, imageSpace: 'img' }], getPose: sp => (sp === 'img' ? { transform: { matrix: pose } } : null) };
    AR().frame(frame, {}); T.ok(!AR().placed, 'стол встал по угаданной позе маркера');
    state = 'tracked'; AR().frame(frame, {});
    T.ok(AR().placed && AR().holo.visible && AR().nosed); T.eq(AR().anchor, 'image');
    T.near(AR().holo.position.z, C.z, 1e-6); T.near(AR().yaw, -Math.PI / 2, 1e-6, 'нос не по стрелке маркера');
    AR().hitSource = null; AR().onEnd();
  });

  T.test('иллюминаторы вокруг стола встают по носу стола', () => {
    AR().onEnd(); AR().onHit(flat(C)); AR().onSelect(); AR().onHit(flat(NOSE)); AR().onSelect();
    AR().autoWindows(); T.eq(AR().windows.length, 3);
    const ahead = AR().windows.find(w => w.pos.x - C.x > 1.7);
    T.ok(ahead, 'нет иллюминатора по носу (+X комнаты)'); T.near(ahead.n.x, -1, 1e-6, 'смотрит не к столу');
    AR().onEnd();
  });

  T.test('сессия просит отслеживание маркера 15 см, если есть картинка', () => {
    const o = AR().sessionInit({ fake: 1 });
    T.ok(o.requiredFeatures.includes('hit-test')); T.ok(o.optionalFeatures.includes('image-tracking'));
    T.eq(o.trackedImages[0].widthInMeters, 0.15);
    const o2 = AR().sessionInit(null); T.ok(!o2.optionalFeatures.includes('image-tracking')); T.ok(!o2.trackedImages);
  });

  T.test('маркер одинаковый на всех устройствах и различим по повороту', () => {
    const a = G.Marker.canvas(128).getContext('2d').getImageData(0, 0, 128, 128).data;
    const b = G.Marker.canvas(128).getContext('2d').getImageData(0, 0, 128, 128).data;
    let same = true; for (let i = 0; i < a.length; i += 4) if (a[i] !== b[i]) { same = false; break; }
    T.ok(same, 'рисунок маркера случайный');
    let diff = 0; // сравнить с повёрнутым на 180°
    for (let y = 0; y < 128; y++) for (let x = 0; x < 128; x++) if ((a[(y * 128 + x) * 4] > 127) !== (a[((127 - y) * 128 + (127 - x)) * 4] > 127)) diff++;
    T.gt(diff, 128 * 128 * 0.15, 'маркер симметричен — нос не определить');
    T.ok(document.getElementById('set-marker').getAttribute('href') === 'marker.html', 'в настройках нет ссылки на маркер');
  });
});
