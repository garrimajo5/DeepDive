'use strict';
/* Сохранение трюма: груз, поднятые со дна образцы и улучшения переживают перезапуск игры */
T.describe('Сохранение трюма', () => {
  const D = () => G.Game.debug, S = () => G.Ship, M = () => G.Manip, Cg = () => G.Cargo;
  const stored = () => { const r = localStorage.getItem(G.Save.KEY); return r ? JSON.parse(r) : null; };
  /* рука донесла образец до шлюза — так же, как в конце удержания кнопки манипулятора */
  const grab = i => { const s = M().samples[i]; s.taken = true; M().place(); M().stow(s); return s; };
  /* «перезапуск игры»: свежий мир без груза и улучшений, потом загрузка сохранения */
  const reboot = () => { S().cargo.length = 0; M().reset(); Cg().reset(); S().showTubes(); return G.Save.load(); };
  const moss = () => M().samples.filter(s => s.kind === 'moss').map(s => s.i);

  T.test('груз сохраняется сам, после перезапуска он в трюме, а поднятых образцов на дне нет', () => {
    grab(2); grab(9);
    D().frame(25);
    const s = stored();
    T.ok(s && Array.isArray(s.cargo), 'груза нет в сохранении');
    T.eq(s.cargo.length, 2); T.eq(s.cargo[1].i, 9);
    T.ok(reboot(), 'не загрузилось');
    T.eq(S().cargo.length, 2); T.eq(S().cargo[0].kind, M().samples[2].kind);
    T.ok(M().samples[2].taken && M().samples[9].taken, 'поднятые образцы снова лежат на дне');
    T.ok(!M().samples[0].taken, 'лишний образец пропал со дна');
    T.ok(S().tubeOrbs[1].visible, 'колбы лаборатории пусты после загрузки');
    T.ok(G.Save.hasProgress(), 'груз не считается прогрессом');
  });

  T.test('улучшение сохраняется, потраченные образцы на дно не возвращаются', () => {
    const ids = moss().slice(0, 3); ids.forEach(grab);
    T.ok(Cg().install('batt'), 'не поставили');
    T.eq(S().cargo.length, 0);
    D().frame(25);
    T.ok(stored().ups.includes('batt'), 'улучшения нет в сохранении');
    T.ok(reboot());
    T.ok(Cg().has('batt'), 'улучшение пропало после перезапуска');
    T.eq(S().cargo.length, 0, 'потраченные образцы вернулись в трюм');
    ids.forEach(i => T.ok(M().samples[i].taken, 'потраченный образец снова на дне: ' + i));
  });

  T.test('без сохранения после перезапуска трюм пуст (контроль)', () => {
    grab(1);
    G.Save.wipe();
    T.eq(reboot(), false);
    T.eq(S().cargo.length, 0); T.ok(!M().samples[1].taken);
  });

  T.test('битые данные трюма в сохранении не ломают игру', () => {
    localStorage.setItem(G.Save.KEY, JSON.stringify({ v: 1, species: {}, pois: [], got: [0, 'x', 999, -1], ups: ['batt', 'нет-такого', 5],
      cargo: [{ kind: 'moss', i: 0 }, { kind: 'moss', i: 0 }, { kind: 'shell', i: 0 }, { kind: 'нет-такого', i: 3 }, { kind: 'coral', i: 999 }, null, { kind: 'spine' }] }));
    T.ok(reboot());
    T.eq(S().cargo.length, 2, 'должны остаться мох с индексом 0 и игла без индекса');
    T.eq(S().cargo[0].kind, 'moss'); T.eq(S().cargo[1].kind, 'spine');
    T.ok(M().samples[0].taken);
    T.eq(M().samples.filter(s => s.taken).length, 1, 'со дна пропали лишние образцы');
    T.eq([...Cg().owned].join(), 'batt');
    // старое сохранение без трюма — трюм пуст
    localStorage.setItem(G.Save.KEY, JSON.stringify({ v: 1, species: {}, pois: [] }));
    T.ok(reboot()); T.eq(S().cargo.length, 0); T.eq(Cg().owned.size, 0);
  });

  T.test('сброс прогресса очищает трюм и улучшения, образцы снова на дне', () => {
    moss().slice(0, 3).forEach(grab); Cg().install('batt'); grab(8);
    G.Game.resetProgress();
    T.eq(S().cargo.length, 0); T.eq(Cg().owned.size, 0);
    T.eq(M().samples.filter(s => s.taken).length, 0, 'образцы не вернулись на дно');
    T.ok(!S().tubeOrbs[0].visible, 'колба не опустела');
    T.eq(stored(), null, 'сохранение не стёрто');
    T.ok(!G.Save.hasProgress());
  });

  T.test('после гибели корабля сохранение тоже без груза', () => {
    grab(3); D().frame(25);
    T.eq(stored().cargo.length, 1);
    S().hull = 1; G.Game.hullHit(50, 'bite');
    T.eq(G.Game.state, 'lost');
    document.getElementById('b-restart').click();
    T.eq(S().cargo.length, 0);
    D().frame(25);
    T.eq(stored().cargo.length, 0, 'в сохранении остался груз погибшего корабля');
    T.ok(stored().got.includes(3), 'поднятый образец вернулся бы на дно');
  });
});
