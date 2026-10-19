'use strict';
/* Скальник крадёт образец с манипулятора и уносит к себе в нору */
T.describe('Скальник-вор', () => {
  const D = () => G.Game.debug, S = () => G.Ship, M = () => G.Manip, C = () => G.Ctl, E = () => G.Eco;
  const quiet = () => { E().preds.forEach(p => { p.state = 'eat'; p.timer = 999; p.cd = 999; p.p.set(250, -20, 250); }); E().eels.forEach(el => { el.cd = 999; }); };
  const over = (s) => {
    S().yaw = 0; S().pitch = S().roll = 0; S().speed = S().vy = 0;
    S().pos.set(s.pos.x, s.pos.y + 7, s.pos.z - 11.5); S().applyTransform();
    const pl = G.Game.player; pl.x = 0; pl.z = 11; D().frame(1); D().lookAt(s.pos); D().frame(1);
  };
  const grab = (s, n) => { C().actionDown = true; for (let i = 0; i < n && !s.taken; i++) { D().lookAt(s.pos); D().frame(1); } C().actionDown = false; };
  const spine = () => M().samples.find(x => x.kind === 'spine');

  T.test('образец у норы скальник выхватывает из клешни и уносит к себе', () => {
    const ev = T.captureEvents();
    quiet(); E().skalnik.curCd = 999;
    const s = spine(), sk = E().skalnik; T.lt(s.pos.distanceTo(sk.home), 12);
    over(s); grab(s, 60);
    T.ok(s.taken, 'рука не взяла образец');
    for (let i = 0; i < 200 && !sk.loot; i++) D().frame(1);
    T.ok(sk.loot === s, 'скальник не стащил образец');
    T.eq(M().state, 'idle'); T.ok(!M().arm.carry.visible);
    T.ok(ev.some(e => e.sp === 'skalnik' && e.note === 'thief'), 'нет наблюдения «крадёт»');
    for (let i = 0; i < 400 && sk.state !== 'rock'; i++) D().frame(1);
    T.eq(sk.state, 'rock', 'скальник не вернулся в нору');
    T.ok(!s.taken, 'образец не лежит у норы');
    T.lt(s.pos.distanceTo(sk.home), 2, 'образец не у норы');
    T.eq(S().cargo.length, 0, 'украденный образец всё равно попал в колбу');
  });

  T.test('образец вдали от норы скальник не трогает (контроль)', () => {
    quiet();
    const s = M().samples.find(x => x.kind === 'moss' && x.pos.distanceTo(E().skalnik.home) > 30);
    over(s); grab(s, 60);
    for (let i = 0; i < 60 && M().state !== 'idle'; i++) D().frame(1);
    T.eq(S().cargo.length, 1); T.eq(E().skalnik.state, 'rock'); T.eq(E().skalnik.loot, null);
  });

  T.test('разряд по корпусу заставляет бросить добычу', () => {
    const ev = T.captureEvents();
    quiet(); E().skalnik.curCd = 999;
    const s = spine(), sk = E().skalnik;
    over(s); grab(s, 60);
    for (let i = 0; i < 200 && !sk.loot; i++) D().frame(1);
    T.ok(sk.loot, 'кражи не было');
    S().energy = 100; G.Game.zap();
    T.eq(sk.loot, null);
    T.ok(!s.taken, 'образец не упал на дно');
    T.near(s.pos.y, G.World.height(s.pos.x, s.pos.z) + 0.15, 0.01);
    T.ok(ev.some(e => e.sp === 'skalnik' && e.note === 'drop'), 'нет наблюдения «бросает»');
  });
});
