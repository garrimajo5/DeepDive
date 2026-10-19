'use strict';
/* Лента событий: кнопка «свернуть», одна строка и счётчик новых, состояние сохраняется */
T.describe('Лента событий', () => {
  const St = G.Settings, $ = id => document.getElementById(id);
  const visible = () => [...document.querySelectorAll('#feed-list > div')].filter(d => getComputedStyle(d).display !== 'none');
  const say = n => { for (let i = 0; i < n; i++) G.Game.feedMsg('Событие ' + i); };
  const rect = id => $(id).getBoundingClientRect();
  const cross = (a, b) => a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom;

  T.test('по умолчанию развёрнута: видно несколько строк, кнопка «Лог ▾»', () => {
    say(5);
    T.gt(visible().length, 1, 'развёрнутая лента показывает одну строку');
    T.eq(visible()[0].textContent, 'Событие 4', 'не видна самая новая строка');
    T.eq(G.Game.debug.feed().length, 4, 'строки, которые не влезли, должны оставаться в ленте');
    T.ok(!St.v.feedMin);
    T.ok($('b-feed').textContent.startsWith('Лог ▾'));
    T.ok($('feed-new').hidden, 'счётчик виден в развёрнутой ленте');
  });
  T.test('кнопка сворачивает до одной последней строки и разворачивает обратно', () => {
    say(4);
    $('b-feed').click();
    T.ok(St.v.feedMin); T.ok($('feed').classList.contains('min'));
    const v = visible();
    T.eq(v.length, 1); T.eq(v[0].textContent, 'Событие 3', 'видна не последняя строка');
    T.eq(getComputedStyle(v[0]).whiteSpace, 'nowrap');
    T.ok($('b-feed').textContent.startsWith('Лог ▸'));
    $('b-feed').click();
    T.ok(!St.v.feedMin); T.gt(visible().length, 1);
  });
  T.test('свёрнутая лента занимает не больше двух строк по высоте', () => {
    say(4); const full = rect('feed').height;
    G.Game.toggleFeed(true);
    const h = rect('feed').height;
    T.lt(h, 70, 'высота свёрнутой ленты'); T.lt(h, full, 'свёрнутая не ниже развёрнутой');
  });
  T.test('в свёрнутой ленте кнопка считает новые события, разворот обнуляет', () => {
    say(2); G.Game.toggleFeed(true);
    T.ok($('feed-new').hidden, 'счётчик до новых событий');
    say(3);
    T.eq(G.Game.feedUnread, 3); T.ok(!$('feed-new').hidden); T.eq($('feed-new').textContent, '+3');
    T.eq(G.Game.debug.feed().length, 4, 'события перестали попадать в ленту');
    G.Game.toggleFeed();
    T.eq(G.Game.feedUnread, 0); T.ok($('feed-new').hidden);
    say(1); T.eq(G.Game.feedUnread, 0, 'в развёрнутой ленте счётчик растёт');
  });
  T.test('события игры идут в свёрнутую ленту и считаются', () => {
    G.Game.toggleFeed(true);
    G.Game.hullHit(4);
    T.eq(G.Game.feedUnread, 1);
    T.eq(visible()[0].textContent, 'Удар по корпусу: −4%');
  });
  T.test('состояние сохраняется на устройстве и переживает перезапуск и сброс журнала', () => {
    $('b-feed').click();
    const raw = JSON.parse(localStorage.getItem(St.KEY));
    T.eq(raw.feedMin, true, 'не записано в настройки');
    G.Game.resetProgress();
    St.v = St.defaults(); $('feed').classList.remove('min');
    T.ok(St.load());
    T.ok(St.v.feedMin); T.ok($('feed').classList.contains('min'), 'после загрузки лента не свёрнута');
    localStorage.setItem(St.KEY, JSON.stringify({ feedMin: 'да' }));
    St.load(); T.eq(St.v.feedMin, false, 'битое значение');
  });
  T.test('кнопка на телефоне не перекрывает крестовину, приборы и кнопку действия', () => {
    const long = ['Вид занесён в журнал: Серпохвост', 'Удар по корпусу: −12%', 'Связь · Сонарщик: «КОРАЛЛ, дайте импульс, он рядом»', 'Место отмечено на сонаре: Кости левиафана'];
    long.forEach(t => G.Game.feedMsg(t, true));
    T.eq(G.Game.debug.feed()[0], long[3], 'самая новая строка пропала');
    [false, true].forEach(min => {
      G.Game.toggleFeed(min);
      const b = rect('b-feed'), f = rect('feed');
      T.gt(b.width, 0); T.gt(b.height, 27, 'кнопка мала для пальца');
      ['dpad', 'stats', 'b-action', 'topbtns'].forEach(id => {
        T.ok(!cross(b, rect(id)), `кнопка перекрывает #${id} (свёрнута: ${min})`);
        T.ok(!cross(f, rect(id)), `лента перекрывает #${id} (свёрнута: ${min})`);
      });
      T.ok(b.bottom <= innerHeight && b.left >= 0, 'кнопка за краем экрана');
    });
  });
});
