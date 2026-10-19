'use strict';
/* Игрок, кнопка действия, сканирование, открытия, журнал */
T.describe('Кнопка действия', () => {
  const D = () => G.Game.debug;
  T.test('у штурвала садимся за штурвал и встаём', () => {
    const P = G.Game.player; P.x = 0; P.z = -3.4; P.yaw = 0; P.pitch = -0.4;
    D().frame(1);
    T.eq(D().actionLabel(), 'Сесть за штурвал');
    G.Ctl.actionPressed = true; D().frame(1);
    T.ok(G.Game.piloting, 'не сели');
    G.Ctl.standPressed = true; D().frame(1);
    T.ok(!G.Game.piloting, 'не встали');
  });
  T.test('люк открывается кнопкой и пускает в лабораторию', () => {
    const P = G.Game.player; P.x = 0; P.z = 1.2; P.yaw = Math.PI; P.pitch = 0;
    D().frame(1);
    T.eq(D().actionLabel(), 'Открыть люк');
    G.Ctl.actionPressed = true; D().frame(30);
    T.gt(G.Ship.doors[0].t, 0.85);
    G.Ship.doors[1].open = true; D().frame(30);
    G.Ctl.padMove.y = 1; D().frame(160); G.Ctl.padMove.y = 0;
    T.eq(G.Game.room, 'lab'); T.gt(P.z, 8.3);
  });
  T.test('пульт инженера даёт разряд', () => {
    const P = G.Game.player; P.x = -3.8; P.z = -0.6; P.yaw = Math.PI / 2; P.pitch = 0;
    G.Ship.energy = 80; D().frame(1);
    T.eq(D().actionLabel(), 'Разряд по корпусу');
    G.Ctl.actionPressed = true; D().frame(1);
    T.lt(G.Ship.energy, 66);
  });
});

T.describe('Сканирование', () => {
  const D = () => G.Game.debug;
  T.test('удержание кнопки заносит вид в журнал', () => {
    const vl = G.Eco.veils[0];
    vl.p.copy(G.Ship.front).add(T.V(0, 2, -30)); vl.home.copy(vl.p);
    G.Game.toggleHelm(); D().frame(1);
    D().lookAt(vl.scanP); D().frame(1);
    T.eq(D().actionLabel(), 'Сканировать (держать)');
    G.Ctl.actionDown = true;
    for (let i = 0; i < 40 && !G.SPECIES.veil.scanned; i++) { D().lookAt(vl.scanP); D().frame(1); }
    G.Ctl.actionDown = false;
    T.ok(G.SPECIES.veil.scanned, 'вуаль не отсканирована');
    T.ok(document.getElementById('j-count').textContent.startsWith('1/26'));
    D().lookAt(vl.scanP); D().frame(1);
    T.eq(D().actionLabel(), 'Сведения: Фонарная вуаль');
  });
  T.test('сканирование сбрасывается, если отпустить кнопку', () => {
    const vl = G.Eco.veils[0];
    vl.p.copy(G.Ship.front).add(T.V(0, 2, -30)); vl.home.copy(vl.p);
    G.Game.toggleHelm(); D().lookAt(vl.scanP); D().frame(1);
    G.Ctl.actionDown = true; for (let i = 0; i < 15; i++) { D().lookAt(vl.scanP); D().frame(1); }
    G.Ctl.actionDown = false; for (let i = 0; i < 15; i++) { D().lookAt(vl.scanP); D().frame(1); }
    G.Ctl.actionDown = true; for (let i = 0; i < 15; i++) { D().lookAt(vl.scanP); D().frame(1); }
    G.Ctl.actionDown = false;
    T.ok(!G.SPECIES.veil.scanned, 'отсканировалось по кусочкам');
  });
  T.test('сквозь стену не сканируется, через окно — да', () => {
    const vl = G.Eco.veils[0], P = G.Game.player;
    vl.p.copy(G.Ship.front).add(T.V(0, 2, -30)); vl.home.copy(vl.p);
    P.x = 0; P.z = 5; D().frame(1); D().lookAt(vl.scanP); D().frame(1);
    T.ok(!D().actionLabel().startsWith('Сканировать'), 'из коридора сквозь переборку');
    P.x = 0; P.z = -3; D().lookAt(vl.scanP); D().frame(1);
    T.ok(D().actionLabel().startsWith('Сканировать'), 'с мостика через носовое окно');
  });
});

T.describe('Открытия и журнал', () => {
  const D = () => G.Game.debug;
  T.test('место открывается, когда корабль рядом', () => {
    const p = G.World.pois.find(x => x.key === 'geyser');
    G.Ship.pos.set(p.pos.x + 12, -20, p.pos.z + 12);
    D().frame(1);
    T.ok(p.found);
    T.ok(document.getElementById('j-count').textContent.endsWith('1/6'));
  });
  T.test('наблюдение рядом попадает в журнал, далёкое — нет', () => {
    G.Eco.emit('grazer', 'graze', G.Ship.center, () => 'тестовое наблюдение');
    G.Eco.emit('ray', 'follow', G.Ship.center.clone().add(T.V(500, 0, 0)), () => 'далеко');
    D().frame(1);
    T.ok(G.SPECIES.grazer.seen.has('graze'));
    T.ok(!G.SPECIES.ray.seen.has('follow'));
    T.ok(D().feed().some(t => t.includes('тестовое наблюдение')));
  });
  T.test('журнал открывается и закрывается', () => {
    G.Game.openJournal();
    T.eq(G.Game.state, 'journal');
    T.eq(document.querySelectorAll('#journal-body .j-card').length, G.SPECIES_ORDER.length + G.World.pois.length);
    G.Ctl.journalPressed = true; D().frame(1);
    T.eq(G.Game.state, 'play');
  });
});
