'use strict';
/* Посты ролей в экипаже. У каждого в комнате своя роль: пилот, сонарщик, инженер или биолог.
   Пост, чья роль занята другим человеком, закрыт: за штурвал садится только пилот, импульс даёт сонарщик,
   пульт энергии у инженера, манипулятор и трюм у биолога. Роль без хозяина свободна — её пост доступен всем,
   поэтому вдвоём или в одиночку можно делать всё. Сменить роль — касание строки экипажа на приборах. */
(function (G) {
  const ROLES = [
    { id: 'pilot', name: 'Пилот', gen: 'пилота', job: 'штурвал и разряд по корпусу' },
    { id: 'sonar', name: 'Сонарщик', gen: 'сонарщика', job: 'импульс сонара' },
    { id: 'eng', name: 'Инженер', gen: 'инженера', job: 'пульт энергии' },
    { id: 'bio', name: 'Биолог', gen: 'биолога', job: 'манипулятор и терминал трюма' }
  ];
  const POST = { helm: 'pilot', zap: 'pilot', sonar: 'sonar', power: 'eng', manip: 'bio', cargo: 'bio' };
  const POSTNAME = { helm: 'Штурвал', zap: 'Разряд', sonar: 'Сонар', power: 'Пульт энергии', manip: 'Манипулятор', cargo: 'Терминал трюма' };
  const Ro = G.Roles = { ROLES, POST, mine: '' };
  const N = () => G.Net;
  Ro.get = id => ROLES.find(r => r.id === id) || null;
  /* кто из других держит роль (только в сетевом экипаже) */
  Ro.holder = role => (N().on ? N().peers.find(p => p.role === role) || null : null);
  /* пост закрыт, если его роль у другого человека; возвращает этого человека */
  Ro.lock = function (post) {
    const r = POST[post]; if (!r || !N().on || Ro.mine === r) return null;
    return Ro.holder(r);
  };
  Ro.lockLabel = function (post) {
    const h = Ro.lock(post); if (!h) return null;
    return `${POSTNAME[post]} — пост ${Ro.get(POST[post]).gen} (${h.name})`;
  };
  Ro.free = () => ROLES.filter(r => !Ro.holder(r.id));
  /* попросить роль у сервера; роль станет нашей, когда сервер подтвердит */
  Ro.request = function (id) { Ro.asked = id; N().send({ t: 'role', role: id }); };
  Ro.pick = function (ex) { const f = Ro.free().find(r => r.id !== Ro.mine && r.id !== ex); if (f) Ro.request(f.id); return f ? f.id : null; };
  /* следующая свободная роль по кругу */
  Ro.cycle = function () {
    if (!N().on) return null;
    const i = ROLES.findIndex(r => r.id === Ro.mine);
    for (let k = 1; k <= ROLES.length; k++) {
      const r = ROLES[(i + k + ROLES.length) % ROLES.length];
      if (r.id !== Ro.mine && !Ro.holder(r.id)) { Ro.request(r.id); return r.id; }
    }
    G.Game.toast('Все посты заняты', 'Свободных ролей нет.'); return null;
  };
  /* сообщения сервера о ролях */
  Ro.onPeer = function (m) {
    if (m.id === N().id) {
      const was = Ro.mine; Ro.mine = m.role || '';
      const r = Ro.get(Ro.mine);
      if (r && r.id !== was) {
        G.Game.toast('Ваш пост: ' + r.name, `Вам доступны ${r.job}. Посты других ролей открыты, пока их никто не занял.`, 4500);
        if (G.Game.piloting && r.id !== 'pilot' && Ro.holder('pilot')) G.Game.toggleHelm();
      }
    } else {
      const p = N().peers.find(x => x.id === m.id); if (p) p.role = m.role || '';
      const r = Ro.get(m.role);
      if (r) G.Game.feedMsg && G.Game.feedMsg(`${m.name} — ${r.name.toLowerCase()}`);
      if (r && r.id === 'pilot' && G.Game.piloting && Ro.mine !== 'pilot') G.Game.toggleHelm(); // штурвал занял пилот
    }
  };
  Ro.onError = function (m) {
    if (!m.role) return;
    G.Game.toast('Пост занят', `Роль «${Ro.get(m.role) ? Ro.get(m.role).name : m.role}» уже у другого.`);
    if (!Ro.mine) Ro.pick(m.role);
  };
  Ro.reset = function () { Ro.mine = ''; Ro.asked = ''; };
})(window.G);
