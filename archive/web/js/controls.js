'use strict';
/* Управление: экранная крестовина, кнопка действия, обзор свайпом, гироскоп, клавиатура */
(function (G) {
  const C = G.Ctl = {
    move: { x: 0, y: 0 }, padMove: { x: 0, y: 0 }, vert: 0, btnVert: 0,
    actionDown: false, actionPressed: false, pingPressed: false, lightPressed: false, journalPressed: false, standPressed: false,
    lookDX: 0, lookDY: 0, keys: {},
    gyro: false, gyroOK: false, needCalib: false, yawOffset: 0, gyroQ: new THREE.Quaternion()
  };

  C.init = function () {
    /* крестовина: палец можно вести по кнопкам, 8 направлений */
    const pad = document.getElementById('dpad'), btns = {};
    pad.querySelectorAll('button').forEach(b => { btns[b.dataset.d] = b; });
    let padId = null;
    function padSet(e) {
      const r = pad.getBoundingClientRect();
      const dx = e.clientX - (r.left + r.width / 2), dy = e.clientY - (r.top + r.height / 2);
      let x = 0, y = 0;
      if (Math.hypot(dx, dy) > r.width * 0.1) {
        const ang = Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) * Math.PI / 4;
        x = Math.round(Math.cos(ang)); y = -Math.round(Math.sin(ang));
      }
      C.padMove.x = x; C.padMove.y = y;
      btns.up.classList.toggle('on', y > 0); btns.down.classList.toggle('on', y < 0);
      btns.left.classList.toggle('on', x < 0); btns.right.classList.toggle('on', x > 0);
    }
    pad.addEventListener('pointerdown', e => { e.preventDefault(); padId = e.pointerId; try { pad.setPointerCapture(e.pointerId); } catch (_) {} padSet(e); });
    pad.addEventListener('pointermove', e => { if (e.pointerId === padId) padSet(e); });
    const padEnd = e => { if (e.pointerId !== padId) return; padId = null; C.padMove.x = C.padMove.y = 0; Object.values(btns).forEach(b => b.classList.remove('on')); };
    pad.addEventListener('pointerup', padEnd); pad.addEventListener('pointercancel', padEnd);

    function hold(id, on, off) {
      const el = document.getElementById(id);
      el.addEventListener('pointerdown', e => { e.preventDefault(); e.stopPropagation(); try { el.setPointerCapture(e.pointerId); } catch (_) {} el.classList.add('on'); on(); });
      const end = () => { el.classList.remove('on'); off(); };
      el.addEventListener('pointerup', end); el.addEventListener('pointercancel', end);
    }
    hold('b-action', () => { C.actionDown = true; C.actionPressed = true; G.Audio.init(); }, () => { C.actionDown = false; });
    hold('b-up', () => { C.btnVert = 1; }, () => { C.btnVert = 0; });
    hold('b-down', () => { C.btnVert = -1; }, () => { C.btnVert = 0; });
    hold('b-light', () => { C.lightPressed = true; }, () => {});
    hold('b-ping', () => { C.pingPressed = true; }, () => {});
    hold('b-talk', () => { C.talkDown = true; }, () => { C.talkDown = false; }); // говорить, пока держишь

    /* обзор: перетаскивание по экрану (несколько пальцев независимо) */
    const view = document.getElementById('view'), looks = new Map();
    view.addEventListener('pointerdown', e => { looks.set(e.pointerId, { x: e.clientX, y: e.clientY }); try { view.setPointerCapture(e.pointerId); } catch (_) {} });
    view.addEventListener('pointermove', e => { const l = looks.get(e.pointerId); if (!l) return; C.lookDX += e.clientX - l.x; C.lookDY += e.clientY - l.y; l.x = e.clientX; l.y = e.clientY; });
    const le = e => looks.delete(e.pointerId);
    view.addEventListener('pointerup', le); view.addEventListener('pointercancel', le);

    addEventListener('keydown', e => {
      if (e.repeat) return;
      C.keys[e.code] = true;
      if (e.code === 'KeyE' || e.code === 'Enter') { C.actionDown = true; C.actionPressed = true; }
      if (e.code === 'KeyF') C.lightPressed = true;
      if (e.code === 'KeyX') C.standPressed = true;
      if (e.code === 'KeyQ') C.pingPressed = true;
      if (e.code === 'KeyV') C.talkDown = true;
      if (e.code === 'KeyJ' || e.code === 'Tab' || e.code === 'Escape') { C.journalPressed = true; e.preventDefault(); }
      if (e.code === 'Space') e.preventDefault();
    });
    addEventListener('keyup', e => { C.keys[e.code] = false; if (e.code === 'KeyE' || e.code === 'Enter') C.actionDown = false; if (e.code === 'KeyV') C.talkDown = false; });
    addEventListener('blur', () => { C.keys = {}; C.actionDown = false; });
  };

  C.read = function () {
    const k = C.keys;
    let x = C.padMove.x, y = C.padMove.y;
    if (k.KeyW || k.ArrowUp) y = 1; if (k.KeyS || k.ArrowDown) y = -1;
    if (k.KeyA || k.ArrowLeft) x = -1; if (k.KeyD || k.ArrowRight) x = 1;
    C.move.x = x; C.move.y = y;
    let v = C.btnVert; if (k.Space || k.KeyR) v = 1; if (k.ShiftLeft || k.ShiftRight || k.KeyC) v = -1;
    C.vert = v;
  };

  /* гироскоп: ориентация телефона -> поворот камеры (как DeviceOrientationControls) */
  const zee = new THREE.Vector3(0, 0, 1), eu = new THREE.Euler(), q0 = new THREE.Quaternion(), q1 = new THREE.Quaternion(-Math.sqrt(0.5), 0, 0, Math.sqrt(0.5));
  function onOri(e) {
    if (e.alpha == null) return;
    C.gyroOK = true;
    const D = THREE.MathUtils.degToRad;
    const or = D((screen.orientation && screen.orientation.angle) || window.orientation || 0);
    eu.set(D(e.beta), D(e.alpha), -D(e.gamma), 'YXZ');
    C.gyroQ.setFromEuler(eu); C.gyroQ.multiply(q1); C.gyroQ.multiply(q0.setFromAxisAngle(zee, -or));
  }
  C.gyroAvailable = () => typeof window.DeviceOrientationEvent !== 'undefined' && ('ontouchstart' in window || navigator.maxTouchPoints > 0);
  C.toggleGyro = async function () {
    if (C.gyro) { removeEventListener('deviceorientation', onOri); C.gyro = false; C.gyroOK = false; return false; }
    if (typeof DeviceOrientationEvent.requestPermission === 'function') {
      try { if (await DeviceOrientationEvent.requestPermission() !== 'granted') return false; } catch (_) { return false; }
    }
    addEventListener('deviceorientation', onOri);
    C.gyro = true; C.gyroOK = false; C.needCalib = true;
    return true;
  };
})(window.G);
