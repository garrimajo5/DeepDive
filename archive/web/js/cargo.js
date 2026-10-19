'use strict';
/* Грузовой отсек (трюм) за машинным отделением. Образцы, которые достал манипулятор, лежат на полках.
   У терминала их можно потратить на улучшения корабля. Терминал: крестовина вверх/вниз выбирает
   улучшение, вправо — установить, круглая кнопка закрывает. На телефоне есть и кнопки. */
(function (G) {
  const UP = [
    { id: 'hull', name: 'Броня корпуса', hint: 'удары на 30% слабее', cost: { coral: 2, spine: 1 } },
    { id: 'batt', name: 'Живые аккумуляторы', hint: 'энергия копится на 40% быстрее', cost: { moss: 3 } },
    { id: 'sonar', name: 'Фильтр сонара', hint: 'импульс стоит 4 вместо 6', cost: { shell: 2 } },
    { id: 'quiet', name: 'Глушитель двигателей', hint: 'серпохвост слышит ход вдвое ближе', cost: { coral: 1, moss: 2 } }
  ];
  const Cg = G.Cargo = { UP, owned: new Set(), sel: 0, open: false, el: null, slots: [] };
  const KINDS = () => G.Manip.KIND;
  const m4 = new THREE.Matrix4(), zero = new THREE.Matrix4().makeScale(0, 0, 0), col = new THREE.Color();
  Cg.has = id => Cg.owned.has(id);
  Cg.count = kind => G.Ship.cargo.filter(c => c.kind === kind).length;
  Cg.can = u => !Cg.owned.has(u.id) && Object.entries(u.cost).every(([k, n]) => Cg.count(k) >= n);
  Cg.costText = u => Object.entries(u.cost).map(([k, n]) => `${KINDS()[k].name.toLowerCase()} ×${n}`).join(', ');
  Cg.install = function (id) {
    const u = UP.find(x => x.id === id);
    if (!u || !Cg.can(u)) { G.Audio.beep(220); return false; }
    Object.entries(u.cost).forEach(([k, n]) => { for (let i = 0; i < n; i++) { const j = G.Ship.cargo.findIndex(c => c.kind === k); G.Ship.cargo.splice(j, 1); } });
    Cg.owned.add(id); G.Save.mark();
    G.Ship.showTubes(); Cg.shelves(); Cg.render();
    G.Game.toast('Улучшение установлено', `${u.name}: ${u.hint}.`);
    G.Game.feedMsg && G.Game.feedMsg(`Установлено: ${u.name.toLowerCase()}`, true);
    G.Audio.scanDone();
    return true;
  };
  Cg.restore = function (ids) { Cg.owned = new Set(ids.filter(id => UP.some(u => u.id === id))); Cg.shelves(); Cg.render(); };
  Cg.reset = function () { Cg.owned.clear(); Cg.sel = 0; if (Cg.open) Cg.close(); Cg.shelves(); Cg.render(); };

  /* ---------- полки ---------- */
  Cg.build = function (group, slots) {
    Cg.slots = slots;
    Cg.im = new THREE.InstancedMesh(new THREE.OctahedronGeometry(0.16, 0), new THREE.MeshBasicMaterial(), slots.length);
    Cg.im.frustumCulled = false; Cg.im.userData.dynamic = true; group.add(Cg.im);
    slots.forEach((_, i) => Cg.im.setColorAt(i, col.set(0xffffff))); // цвета экземпляров — до первой отрисовки, иначе шейдер их не увидит
    Cg.shelves();
  };
  Cg.shelves = function () {
    if (!Cg.im) return;
    const cargo = G.Ship.cargo;
    Cg.slots.forEach((p, i) => {
      const c = cargo[i];
      if (c) { Cg.im.setMatrixAt(i, m4.makeTranslation(p.x, p.y, p.z)); Cg.im.setColorAt(i, col.set(KINDS()[c.kind].color)); }
      else Cg.im.setMatrixAt(i, zero);
    });
    Cg.im.instanceMatrix.needsUpdate = true; if (Cg.im.instanceColor) Cg.im.instanceColor.needsUpdate = true;
  };

  /* ---------- терминал ---------- */
  Cg.isOpen = () => Cg.open;
  Cg.toggle = () => (Cg.open ? Cg.close() : Cg.openPanel());
  Cg.openPanel = function () { if (!Cg.el) return; Cg.open = true; Cg.el.hidden = false; Cg.held = null; Cg.render(); G.Audio.beep(560); };
  Cg.close = function () { if (!Cg.el) return; Cg.open = false; Cg.el.hidden = true; G.Audio.beep(420); };
  Cg.nav = function (mx, my) {
    const dir = Math.abs(my) > 0.5 ? (my > 0 ? 'up' : 'down') : mx > 0.5 ? 'right' : null;
    if (!dir) { Cg.held = null; return; }
    if (dir === Cg.held) return; Cg.held = dir; // по одному шагу на нажатие
    if (dir === 'up') Cg.sel = (Cg.sel + UP.length - 1) % UP.length;
    else if (dir === 'down') Cg.sel = (Cg.sel + 1) % UP.length;
    else Cg.install(UP[Cg.sel].id);
    Cg.render();
  };
  Cg.render = function () {
    if (!Cg.el) return;
    Cg.el.querySelectorAll('.cg-row').forEach((row, i) => {
      const u = UP[i];
      row.classList.toggle('sel', i === Cg.sel);
      row.classList.toggle('own', Cg.has(u.id));
      const b = row.querySelector('button');
      b.disabled = !Cg.can(u); b.textContent = Cg.has(u.id) ? 'Есть' : 'Установить';
    });
    const kinds = Object.keys(KINDS()).map(k => `${KINDS()[k].name.toLowerCase()}: ${Cg.count(k)}`).join(' · ');
    Cg.el.querySelector('#cg-have').textContent = G.Ship.cargo.length ? `В трюме — ${kinds}` : 'Трюм пуст: достаньте образцы манипулятором из лаборатории';
  };
  Cg.init = function () {
    const el = Cg.el = document.getElementById('cargo'); if (!el) return;
    el.querySelector('.cg-rows').innerHTML = UP.map(u => `<div class="cg-row" data-u="${u.id}"><div class="pw-name"><b>${u.name}</b><small>${u.hint} · ${Cg.costText(u)}</small></div><button class="chip" type="button">Установить</button></div>`).join('');
    el.addEventListener('pointerdown', e => e.stopPropagation());
    el.addEventListener('click', e => {
      const b = e.target.closest('button'); if (!b) return;
      if (b.dataset.a === 'close') { Cg.close(); return; }
      const row = b.closest('.cg-row'); if (!row) return;
      Cg.sel = UP.findIndex(u => u.id === row.dataset.u); Cg.install(row.dataset.u);
    });
    Cg.render();
  };
})(window.G);
