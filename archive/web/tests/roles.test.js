'use strict';
/* Посты ролей в сетевом экипаже (сокет — заглушка) */
T.describe('Посты ролей', () => {
  const N = () => G.Net, Ro = () => G.Roles, D = () => G.Game.debug, C = () => G.Ctl;
  class FakeWS {
    constructor(url) { this.url = url; this.sent = []; this.readyState = 1; FakeWS.last = this; }
    send(s) { this.sent.push(JSON.parse(s)); }
    close() { this.readyState = 3; this.onclose && this.onclose(); }
    msg(o) { this.onmessage({ data: JSON.stringify(o) }); }
  }
  /* вход в комнату: id 2, остальные — из peers */
  const join = (peers, host) => {
    N().connect('ws://test/ws', 'ковчег', 'Я', FakeWS); const ws = FakeWS.last; ws.onopen();
    ws.msg({ t: 'joined', id: 2, room: 'КОВЧЕГ', host: !!host, hostId: host ? 2 : 1, peers });
    return ws;
  };
  const leave = () => { if (N().ws) N().ws.onclose = null; Object.assign(N(), { ws: null, on: false, host: false, status: 'off', target: null, remote: null, peers: [] }); Ro().reset(); N().hud(); };
  const label = () => document.getElementById('act-label').textContent;
  const stand = (x, z, yaw) => { const pl = G.Game.player; pl.x = x; pl.z = z; pl.yaw = yaw; pl.pitch = -1.1; D().frame(1); }; // взгляд в пол: рыба за окном не перехватит кнопку
  const roleMsgs = ws => ws.sent.filter(m => m.t === 'role');

  T.test('при входе берётся первая свободная роль: хосту — пилот, гостю — следующая', () => {
    let ws = join([], true);
    T.eq(roleMsgs(ws)[0].role, 'pilot');
    ws.msg({ t: 'peer', ev: 'role', id: 2, name: 'Я', role: 'pilot' });
    T.eq(Ro().mine, 'pilot'); T.ok(document.getElementById('s-net').textContent.includes('Пилот'));
    leave();
    ws = join([{ id: 1, name: 'Маша', role: 'pilot' }, { id: 3, name: 'Лёва', role: 'sonar' }]);
    T.eq(roleMsgs(ws)[0].role, 'eng');
    leave();
  });

  T.test('за штурвал садится только пилот, если пилот в экипаже', () => {
    const ws = join([{ id: 1, name: 'Маша', role: 'pilot' }]);
    ws.msg({ t: 'peer', ev: 'role', id: 2, name: 'Я', role: 'sonar' });
    stand(0, -3.4, 0);
    T.ok(label().includes('пост пилота') && label().includes('Маша'), 'подпись: ' + label());
    C().actionPressed = true; D().frame(1);
    T.ok(!G.Game.piloting, 'сел за чужой штурвал');
    /* пилот ушёл — штурвал свободен */
    ws.msg({ t: 'peer', ev: 'leave', id: 1, name: 'Маша' }); D().frame(1);
    T.eq(label(), 'Сесть за штурвал');
    C().actionPressed = true; D().frame(1);
    T.ok(G.Game.piloting, 'свободный штурвал не открылся');
    G.Game.toggleHelm(); leave();
  });

  T.test('сонар у сонарщика: кнопка импульса не тратит энергию чужого поста', () => {
    const ws = join([{ id: 1, name: 'Лёва', role: 'sonar' }]);
    ws.msg({ t: 'peer', ev: 'role', id: 2, name: 'Я', role: 'pilot' });
    const en = G.Ship.energy, pt = G.Sonar.pingT;
    C().pingPressed = true; D().frame(1);
    T.eq(G.Sonar.pingT, pt, 'импульс прошёл с чужого поста'); T.near(G.Ship.energy, en, 0.5);
    stand(0, -0.4, 0);
    T.ok(label().includes('пост сонарщика'), 'подпись: ' + label());
    leave();
  });

  T.test('свой пост открыт: инженер у пульта, биолог у манипулятора', () => {
    const ws = join([{ id: 1, name: 'Маша', role: 'eng' }, { id: 3, name: 'Лёва', role: 'bio' }]);
    ws.msg({ t: 'peer', ev: 'role', id: 2, name: 'Я', role: 'eng' }); // сервер бы отказал, но проверяем свою роль
    ws.msg({ t: 'peer', ev: 'role', id: 1, name: 'Маша', role: 'pilot' });
    stand(1.6, 15.6, -Math.PI / 2);
    T.ok(label().includes('энерги'), 'пульт энергии закрыт для инженера: ' + label());
    T.ok(Ro().lock('manip'), 'манипулятор биолога открыт другому');
    T.ok(!Ro().lock('power'));
    leave();
  });

  T.test('смена роли касанием: следующая свободная по кругу', () => {
    const ws = join([{ id: 1, name: 'Маша', role: 'sonar' }]);
    ws.msg({ t: 'peer', ev: 'role', id: 2, name: 'Я', role: 'pilot' }); ws.sent.length = 0;
    document.getElementById('s-net').click();
    T.eq(roleMsgs(ws)[0].role, 'eng', 'сонар занят — следующая инженер');
    ws.msg({ t: 'peer', ev: 'role', id: 2, name: 'Я', role: 'eng' });
    T.eq(Ro().mine, 'eng');
    /* сервер отказал: пост занят — выбирается другой */
    ws.sent.length = 0; Ro().reset();
    ws.msg({ t: 'error', msg: 'этот пост уже занят', role: 'pilot' });
    T.ok(roleMsgs(ws).length === 1 && roleMsgs(ws)[0].role !== 'pilot', 'после отказа роль не перевыбрана');
    leave();
  });

  T.test('пилот встаёт из-за штурвала, если пилотом стал другой', () => {
    const ws = join([{ id: 1, name: 'Маша', role: '' }]);
    stand(0, -3.4, 0); C().actionPressed = true; D().frame(1);
    T.ok(G.Game.piloting);
    ws.msg({ t: 'peer', ev: 'role', id: 1, name: 'Маша', role: 'pilot' });
    T.ok(!G.Game.piloting, 'остался за чужим штурвалом');
    leave();
  });

  T.test('в одиночной игре все посты открыты (контроль)', () => {
    T.ok(!N().on);
    ['helm', 'zap', 'sonar', 'power', 'manip', 'cargo'].forEach(p => T.ok(!Ro().lock(p), p));
    stand(0, -3.4, 0); T.eq(label(), 'Сесть за штурвал');
  });
});
