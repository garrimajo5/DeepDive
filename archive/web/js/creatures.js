'use strict';
/* Живая экосистема отмели.
   Пищевые связи: серпохвосты охотятся на светляков; вуали жалят рыб, хищники их обходят;
   скребуны пасутся на мху; стеклоусты подстерегают скребунов и рыб; за ледокрылами ходят стаи;
   огнёвки держат станции чистки на огнецвете: там серпохвосты не охотятся и избавляются от пиявников;
   хватни ловят светляков в темноте, пестрянки подманивают к ним стаи и доедают остатки;
   светляки прячутся в ленточнике, шипоежи объедают его до стеблей, кольчужники раскалывают ежей;
   радужники вспыхивают в луче прожектора, и серпохвосты замечают корабль издалека;
   мерцающий планктон вспыхивает от быстрого движения: светящийся след выдаёт и корабль, и бросок хищника;
   монетники пасутся на мху и рассыпаются от сонара прочь от угрозы, песчаные глазуны подстерегают их в песке;
   гротовик носит на спине риф, где живёт и прячется одна из стай светляков;
   скальник прикидывается камнем у норы кольчужника и выгоняет краба с бедным панцирем обратно в нору;
   присоски катаются на ледокрылах и перебираются на корпус, а там отпугивают стеклоуста;
   каменщики прячут венчики, когда рядом крупный, а гул трубного органа заглушает двигатели корабля;
   подушечник от касания выпускает чернила, в которых прячутся стая и корабль; споры пузырчатки собирают рыб на кормёжку;
   веерники стоят поперёк течения, волнолист раскрывается в луче и открывает моллюсков для рыб. */
(function (G) {
  const V3 = THREE.Vector3;
  const E = G.Eco = { fish: [], shoals: [], preds: [], stations: [], anemones: [], groves: [], urchins: [], crab: null, swarms: [], flare: 0, flareSw: null, clouds: [], shipWake: 0, coins: [], schools: [], glazuns: [], grot: null, skalnik: null, masons: [], organs: [], shipMasked: null, cushions: [], shipInk: null, bladders: [], fans: [], ferns: [], current: new THREE.Vector3(), curAng: 0, curTarget: 0, curIdx: 0, curT: 0, fanCd: 0, fanReadCd: 0, remoras: [], hullRemoras: 0, rmHopCd: 0, rmEelCd: 0, rmRideCd: 0, shipSheltered: null, veils: [], grazers: [], eels: [], rays: [], events: [], shipHidden: false, latched: null, lastPing: -99 };
  const tv = new V3(), tv2 = new V3(), tv3 = new V3(), dummy = new THREE.Object3D();
  const H = (x, z) => G.World.height(x, z);
  const cap = G.cap;

  const SP = G.SPECIES = {
    fish: { name: 'Светляк-полосник', acc: 'светляка-полосника', unom: 'мелкая рыба', uacc: 'мелкую рыбу',
      desc: 'Мелкая рыба с полосами живого света. Держится стаями у кораллов и светится ярче, когда стая напугана.',
      notes: { flee: 'Завидев хищника, стая ныряет в заросли кораллов.', kelp: 'В густом ленточнике хищник теряет напуганную стаю из виду.', follow: 'Стаи сопровождают ледокрылов и подбирают всё, что те взбаламутили.' } },
    pred: { name: 'Серпохвост', acc: 'серпохвоста', unom: 'крупный хищник', uacc: 'крупного хищника',
      desc: 'Хищник рифа длиной около шести метров. Глаза светятся красным, по бокам тянется цепочка огней. Хвост-серп глушит добычу.',
      notes: { catch: 'Охотится на светляков, вырывая рыб из стаи.', avoid: 'Обходит фонарные вуали стороной.', ping: 'Слышит сонар и плывёт проверить источник звука.', ship: 'Идёт на таран, если у корабля горит прожектор.', hear: 'Слышит быстрый ход двигателей поблизости.', zap: 'Разряд по корпусу отпугивает его.' } },
    veil: { name: 'Фонарная вуаль', acc: 'фонарную вуаль', unom: 'колония медуз', uacc: 'колонию медуз',
      desc: 'Колония медуз размером с автобус. Дрейфует по течению, свет мерцает в общем ритме.',
      notes: { sting: 'Жалит рыб, которые подплывают к щупальцам.', hide: 'Под её куполом хищники теряют корабль из виду.' } },
    grazer: { name: 'Скребун', acc: 'скребуна', unom: 'донный панцирник', uacc: 'донного панцирника',
      desc: 'Медлительный донный панцирник на шести лапах. Пасётся на пятнах светящегося мха.',
      notes: { graze: 'Объедает светящийся мох. Съеденные пятна гаснут и потом отрастают.' } },
    eel: { name: 'Стеклоуст', acc: 'стеклоуста', unom: 'прозрачный угорь', uacc: 'прозрачного угря',
      desc: 'Прозрачный угорь-засадчик. Прячется в каменных расщелинах, снаружи виден только красный глаз.',
      notes: { eelcatch: 'Бросается из укрытия на скребунов и рыб.', latch: 'Присасывается к корпусу и пьёт энергию.', zap: 'Разряд по корпусу сбрасывает его.' } },
    ray: { name: 'Ледокрыл', acc: 'ледокрыла', unom: 'гигантский скат', uacc: 'гигантского ската',
      desc: 'Огромный скат с размахом крыльев около 14 метров. Скользит под самым льдом и поёт низким голосом.',
      notes: { follow: 'За ним держатся стаи светляков.', song: 'Поёт низким голосом — песню слышно за сотню метров, по ней понятно, с какой он стороны.' } },
    ognevka: { name: 'Огнёвка', acc: 'огнёвку', unom: 'рачки-чистильщики', uacc: 'рачков-чистильщиков',
      desc: 'Светящиеся креветки длиной около 8 см. Держат «станции чистки» на вершинах огнецвета и снимают паразитов с крупных рыб.',
      notes: { clean: 'Снимают пиявников с серпохвостов, которые приплывают на станцию.', truce: 'У станции чистки серпохвост не охотится.', shelter: 'Корабль может переждать у станции: хищник отворачивает.' } },
    leech: { name: 'Пиявник', acc: 'пиявника', unom: 'паразит', uacc: 'паразита',
      desc: 'Плоский червь около 20 см. Присасывается к жабрам серпохвостов.',
      notes: { infest: 'Присасывается к жабрам серпохвоста.', angry: 'Заражённый хищник медленнее, но злее: замечает корабль издалека.', cleaned: 'Огнёвки снимают пиявников на станциях чистки.' } },
    hvaten: { name: 'Хватень', acc: 'хватня', gen: 'хватня', unom: 'донный анемон', uacc: 'донный анемон', ugen: 'донного анемона',
      desc: 'Анемон-хищник высотой около метра с сотней стрекающих щупалец. Сидит на дне рядом со стаями светляков.',
      notes: { catch: 'Ловит светляков, подплывших к щупальцам в темноте.', hide: 'Прячет щупальца от луча прожектора и раскрывает их снова только в темноте.' } },
    pestr: { name: 'Пестрянка', acc: 'пестрянку', unom: 'пёстрая рыбка', uacc: 'пёструю рыбку',
      desc: 'Рыбка длиной около 12 см в оранжево-белую полоску. Живёт среди щупалец хватня и не боится его стрекал.',
      notes: { lure: 'Выплывает к стае светляков и заманивает рыб в щупальца хозяина.', leftovers: 'Доедает остатки добычи хватня.', immune: 'Прячется в сжатых щупальцах: стрекала её не трогают.' } },
    ezh: { name: 'Шипоёж', acc: 'шипоежа', gen: 'шипоежа', unom: 'морской ёж', uacc: 'морского ежа', ugen: 'морского ежа',
      desc: 'Морской ёж размером около 50 см. Длинные иглы светятся на концах. Ползает по дну стадами и пасётся на ленточнике.',
      notes: { graze: 'Объедает ленточник до голых стеблей.', bare: 'Где ленточник объеден, стае негде спрятаться от хищника.' } },
    krab: { name: 'Кольчужник', acc: 'кольчужника', gen: 'кольчужника', unom: 'донный краб', uacc: 'донного краба', ugen: 'донного краба',
      desc: 'Краб шириной около метра. Раскалывает морских ежей и носит их иглы на панцире как броню. Живёт в каменной норе.',
      notes: { hunt: 'Выходит из норы и раскалывает шипоежей. Возле его норы ленточник остаётся густым.', armor: 'Вплетает иглы съеденных ежей в панцирь.', guard: 'Охраняет нору: корабль у самого дна хватает клешнёй.' } },
    raduzh: { name: 'Радужник', acc: 'радужника', gen: 'радужников', unom: 'гребневики', uacc: 'гребневиков', ugen: 'гребневиков',
      desc: 'Прозрачный гребневик около 30 см. Своего света нет: ряды ресничек раскладывают чужой свет в радугу. Дрейфует стаями в толще воды.',
      notes: { flare: 'В луче прожектора стая вспыхивает радугой, и корабль видно издалека.', betray: 'Серпохвосты замечают вспышку и плывут к кораблю.', fade: 'Если погасить прожектор, стая гаснет за пару секунд.' } },
    plankton: { name: 'Мерцающий планктон', acc: 'мерцающий планктон', gen: 'мерцающего планктона', unom: 'светящееся облако', uacc: 'светящееся облако', ugen: 'светящегося облака',
      desc: 'Облака светящихся одноклеточных размером около миллиметра. Основа питания рифа. Вспыхивают, когда их задевает что-то быстрое.',
      notes: { wake: 'За быстрым кораблём в облаке тянется светящийся след.', slow: 'Если идти медленно, планктон не вспыхивает.', betray: 'Светящийся след выдаёт корабль хищнику даже с погашенным прожектором.', pred: 'Бросок хищника сквозь облако видно издалека.' } },
    monet: { name: 'Монетник', acc: 'монетника', gen: 'монетников', unom: 'круглые рыбки', uacc: 'круглую рыбку', ugen: 'круглых рыбок',
      desc: 'Круглая плоская рыбка около 30 см с серебристо-золотой чешуёй. Пасётся стайками на светящемся мху рядом со скребунами.',
      notes: { graze: 'Стайкой пасутся на светящемся мху.', scatter: 'От импульса сонара рассыпаются прочь от угрозы — по бегству видно, откуда она.' } },
    glazun: { name: 'Песчаный глазун', acc: 'песчаного глазуна', gen: 'песчаного глазуна', unom: 'глаза в песке', uacc: 'глаза в песке', ugen: 'глаз в песке',
      desc: 'Плоская рыба около 80 см. Зарывается в песок у пятен мха, наружу торчат только глаза на стебельках.',
      notes: { ambush: 'Хватает монетников, которые проплывают над ним.', sonar: 'На сонаре не виден, но монетники шарахаются от него.', eyes: 'В луче прожектора глаза вспыхивают отражённым светом.' } },
    grot: { name: 'Гротовик', acc: 'гротовика', gen: 'гротовика', unom: 'ходячий риф', uacc: 'ходячий риф', ugen: 'ходячего рифа',
      desc: 'Медлительное панцирное существо длиной около 6 метров. На спине растёт настоящий риф с огнецветом и мхом, в нём живёт стая светляков.',
      notes: { drift: 'Неспешно бредёт по отмели, на спине растёт риф.', hide: 'Напуганная стая прячется в рифе на его спине — хищник её теряет.', shy: 'Если задеть его корпусом, прячет ноги под панцирь и замирает.' } },
    skalnik: { name: 'Скальник', acc: 'скальника', gen: 'скальника', unom: 'живой камень', uacc: 'живой камень', ugen: 'живого камня',
      desc: 'Рогатый спрут около 2 метров. Меняет цвет и рисунок кожи под окружающие камни и часами сидит неподвижно у нор.',
      notes: { mimic: 'Неподвижный неотличим от камня, но в луче прожектора меняет цвет.', hunt: 'Подстерегает кольчужника и загоняет его обратно в нору.', armor: 'Не трогает кольчужника, если панцирь того весь в иглах.', curious: 'Любопытен: к тихому тёмному кораблю подплывает к самому стеклу.', thief: 'Крадёт образцы с манипулятора и уносит к себе в нору.', drop: 'От разряда по корпусу бросает украденное.' } },
    prisoska: { name: 'Присоска', acc: 'присосок', gen: 'присосок', unom: 'рыба-прилипала', uacc: 'рыб-прилипал', ugen: 'рыб-прилипал',
      desc: 'Рыба-прилипала около 35 см. Держится присоской на темени за крупных существ — и за корпус «Ковчега».',
      notes: { ride: 'Катается на ледокрылах.', hop: 'Перебирается на корпус корабля, если подойти к ледокрылу.', eel: 'Стеклоуст не садится на корпус, где уже есть прилипалы.', drag: 'Каждая прилипала немного тормозит корабль.', zap: 'Разряд по корпусу их сбрасывает.' } },
    kamen: { name: 'Каменщик', acc: 'каменщиков', gen: 'каменщиков', unom: 'трубчатые черви', uacc: 'трубчатых червей', ugen: 'трубчатых червей',
      desc: 'Трубчатые черви около 30 см. Строят известковые трубки у огнецвета; за десятилетия их арки срастаются в рифы. Наружу выставляют яркие венчики.',
      notes: { hide: 'Прячут венчики в трубки от вибрации, когда рядом проходит кто-то крупный.', warn: 'По спрятавшимся рядам видно, где идёт хищник.' } },
    organ: { name: 'Трубный орган', acc: 'трубный орган', gen: 'трубного органа', unom: 'гудящая губка', uacc: 'гудящую губку', ugen: 'гудящей губки',
      desc: 'Губка высотой около 2,5 метра из толстых труб. Течение проходит сквозь трубы, и губка гудит, как орган.',
      notes: { hum: 'Гудит в течении низким голосом.', mask: 'Гул заглушает двигатели: рядом можно проскользнуть мимо серпохвоста.' } },
    cushion: { name: 'Подушечник', acc: 'подушечник', gen: 'подушечника', unom: 'мягкая подушка', uacc: 'мягкую подушку', ugen: 'мягкой подушки',
      desc: 'Мягкий коралл-подушка около 2 метров, весь в бархатных полипах. Растёт рядом со стаями светляков.',
      notes: { touch: 'От касания сжимается и выпускает облако чернил.', hide: 'В облаке чернил стая прячется от хищника.', ship: 'Корабль, задевший подушечник, может переждать в чернилах.' } },
    bladder: { name: 'Пузырчатка-фонарь', acc: 'пузырчатку-фонарь', gen: 'пузырчатки', unom: 'светящиеся луковицы', uacc: 'светящиеся луковицы', ugen: 'светящихся луковиц',
      desc: 'Тонкие стебли около метра с прозрачными луковицами, полными светящегося сока. Растёт у пятен мха.',
      notes: { pop: 'Спелые луковицы лопаются облаком светящихся спор.', feed: 'На споры слетаются светляки и монетники.' } },
    fan: { name: 'Веерник', acc: 'веерник', gen: 'веерника', unom: 'кружевной веер', uacc: 'кружевной веер', ugen: 'кружевного веера',
      desc: 'Веерный коралл около 3 метров с кружевной сеткой ветвей. Растёт рядом со станциями огнёвок и всегда разворачивается поперёк течения.',
      notes: { across: 'Стоит поперёк течения — по нему видно, куда сносит корабль.', turn: 'Когда течение меняется, веерники разворачиваются следом.', ognevka: 'Огнёвки кормятся на веернике, пока их станция пустует.' } },
    fern: { name: 'Волнолист', acc: 'волнолист', gen: 'волнолиста', unom: 'папоротник-спираль', uacc: 'папоротник-спираль', ugen: 'папоротника-спирали',
      desc: 'Спиральный папоротник около 1,5 метра. Разворачивает листья к свету и сворачивает их в темноте.',
      notes: { open: 'Раскрывается в луче прожектора, в темноте сворачивается.', mollusk: 'Под раскрытыми листьями — съедобные моллюски, к ним приплывают светляки.' } },
    echo: { name: 'Эхоловец', acc: 'эхоловца', gen: 'эхоловца', unom: 'засадчик с ушами-воронками', uacc: 'засадчика с ушами-воронками', ugen: 'засадчика с ушами-воронками',
      desc: 'Засадчик около 3 метров с двумя ушами-воронками. Лежит у Костей левиафана, слушает корабль и повторяет голоса экипажа по внутренней связи. От него спасает только кодовое слово погружения.',
      notes: { fake: 'Подделывает голоса экипажа по связи — без кодового слова или со старым, с прошлого спуска.', strike: 'Просит импульс сонара и бьёт по корпусу на его звук.', lure: 'Просит включить прожектор — на свет приходит серпохвост.', reveal: 'Импульс, о котором он не просил, выдаёт его: ложные вызовы на время прекращаются.' } }
  };
  G.SPECIES_ORDER = ['fish', 'pred', 'veil', 'grazer', 'eel', 'ray', 'ognevka', 'leech', 'hvaten', 'pestr', 'ezh', 'krab', 'raduzh', 'plankton', 'monet', 'glazun', 'grot', 'skalnik', 'prisoska', 'kamen', 'organ', 'cushion', 'bladder', 'fan', 'fern', 'echo'];
  Object.values(SP).forEach(s => { s.scanned = false; s.seen = new Set(); });
  G.nm = (sp, cs) => { const s = SP[sp]; return s.scanned ? (cs === 'gen' ? s.gen || s.acc : cs === 'acc' ? s.acc : s.name.toLowerCase()) : (cs === 'gen' ? s.ugen || s.uacc : cs === 'acc' ? s.uacc : s.unom); };

  /* Повторяющиеся детали существ одним InstancedMesh на деталь: экономия вызовов отрисовки.
     parts: [{ g, mat, m: локальная матрица, per: сколько штук на существо }] */
  const MZ = new THREE.Matrix4().makeScale(0, 0, 0), tm = new THREE.Matrix4();
  function partsIM(scene, parts, N) {
    return parts.map(pt => { const im = new THREE.InstancedMesh(pt.g, pt.mat, Math.max(1, N * (pt.per || 1))); im.frustumCulled = false; scene.add(im); return { im, m: pt.m, per: pt.per || 1 }; });
  }
  /* поставить детали существа i по его базовой матрице; locals — свои локальные матрицы для подвижных деталей */
  function placeParts(set, i, base, hide, locals) {
    set.forEach((pt, j) => {
      const L = (locals && locals[j]) || pt.m;
      for (let k = 0; k < pt.per; k++) {
        if (hide) pt.im.setMatrixAt(i * pt.per + k, MZ);
        else pt.im.setMatrixAt(i * pt.per + k, tm.multiplyMatrices(base, Array.isArray(L) ? L[k] : L));
      }
      pt.im.instanceMatrix.needsUpdate = true;
    });
  }
  const mT = (x, y, z) => new THREE.Matrix4().makeTranslation(x, y, z);
  const mTRS = (x, y, z, rx, ry, rz, sx, sy, sz) => new THREE.Matrix4().compose(new V3(x, y, z), new THREE.Quaternion().setFromEuler(new THREE.Euler(rx, ry, rz)), new V3(sx, sy, sz));

  E.emit = (sp, note, pos, msg) => { E.events.push({ sp, note, pos: pos.clone(), msg }); };
  function killFish(f) { f.alive = false; f.t = G.rr(25, 40); }
  function clampArea(p) { p.x = G.clamp(p.x, -290, 290); p.z = G.clamp(p.z, -290, 290); }

  /* ======================= СВЕТЛЯКИ ======================= */
  function fishGeo() {
    const body = new THREE.SphereGeometry(1, 8, 6); body.scale(0.07, 0.1, 0.28);
    const tail = new THREE.BufferGeometry();
    tail.setAttribute('position', new THREE.Float32BufferAttribute([0, 0, -0.22, 0, 0.12, -0.42, 0, -0.12, -0.42], 3));
    tail.computeVertexNormals();
    return G.merge([{ g: body }, { g: tail, c: new THREE.Color(0.7, 0.7, 0.7) }]);
  }
  function initFish(scene) {
    const spots = G.World.coralSpots.slice().sort((a, b) => Math.hypot(a.x, a.z - 55) - Math.hypot(b.x, b.z - 55));
    const homes = [];
    for (const s of spots) { if (homes.every(h => Math.hypot(h.x - s.x, h.z - s.z) > 35)) homes.push(s); if (homes.length >= 6) break; }
    const PER = 22, N = homes.length * PER;
    const im = E.fishIM = new THREE.InstancedMesh(fishGeo(), new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.DoubleSide }), Math.max(1, N));
    im.frustumCulled = false; scene.add(im);
    const cols = [0x5ef2d6, 0xffd36b, 0x8fd0ff, 0xff8fd8, 0xb6ff7a, 0x7fe7ff];
    homes.forEach((h, si) => {
      const sh = { i: si, home: h.clone().add(new V3(0, 1.5, 0)), goal: h.clone(), c: h.clone(), v: new V3(), alarm: 0, follow: null, followT: 0, gt: 0, fleeCd: 0, n: 0, threat: null, members: [] };
      E.shoals.push(sh);
      const col = new THREE.Color(cols[si % cols.length]);
      for (let k = 0; k < PER; k++) {
        const f = { s: sh, p: sh.home.clone().add(new V3(G.rr(-3, 3), G.rr(0, 3), G.rr(-3, 3))), v: new V3(G.rr(-1, 1), 0, G.rr(-1, 1)), alive: true, t: 0, i: E.fish.length, ph: G.rr(0, 6) };
        f.o = f.p.clone().sub(sh.home); f.v0 = f.v.clone(); // для сброса мира
        E.fish.push(f); sh.members.push(f);
        im.setColorAt(f.i, col.clone().multiplyScalar(G.rr(0.75, 1.15)));
      }
    });
    if (im.instanceColor) im.instanceColor.needsUpdate = true;
  }
  function nearestFish(p, R) {
    let best = null, bd = R;
    for (const f of E.fish) { if (!f.alive || nearStation(f.p) || kelpShelter(f) || grotShelter(f) || inkAt(f.p)) continue; const d = f.p.distanceTo(p); if (d < bd) { bd = d; best = f; } }
    return best;
  }
  function updateFish(dt, t) {
    const S = G.Ship;
    for (const sh of E.shoals) {
      sh.c.set(0, 0, 0); sh.v.set(0, 0, 0); sh.n = 0;
      for (const f of sh.members) if (f.alive) { sh.c.add(f.p); sh.v.add(f.v); sh.n++; }
      if (sh.n) { sh.c.divideScalar(sh.n); sh.v.divideScalar(sh.n); } else sh.c.copy(sh.home);
      sh.alarm = Math.max(0, sh.alarm - dt); sh.fleeCd -= dt; sh.gt -= dt; sh.followT -= dt;
      if (sh.followT <= 0) sh.follow = null;
      if (sh.follow) { sh.goal.copy(sh.follow.p).addScaledVector(sh.follow.dir, -12); sh.goal.y -= 3; }
      else if (sh.gt <= 0) {
        sh.gt = G.rr(6, 12);
        const R = sh.range || 14; sh.goal.set(sh.home.x + G.rr(-R, R), 0, sh.home.z + G.rr(-R, R));
        sh.goal.y = Math.min(H(sh.goal.x, sh.goal.z) + G.rr(2, 7), -4);
      }
      sh.threat = null; let best = 16;
      for (const p of E.preds) { const d = p.p.distanceTo(sh.c); if (d < best) { best = d; sh.threat = p.p; } }
      if (sh.threat) {
        if (sh.alarm <= 0 && sh.fleeCd <= 0) { sh.fleeCd = 30; E.emit('fish', 'flee', sh.c, () => `${cap(G.nm('fish'))}: стая уходит в кораллы — рядом хищник`); }
        sh.alarm = 3;
      } else if (S.center.distanceTo(sh.c) < 11 && Math.abs(S.speed) > 1.2) { sh.threat = S.center; sh.alarm = Math.max(sh.alarm, 1.5); }
    }

    const im = E.fishIM;
    for (const f of E.fish) {
      if (!f.alive) {
        f.t -= dt;
        if (f.t > 0) { dummy.position.set(0, -999, 0); dummy.scale.setScalar(0.001); dummy.updateMatrix(); im.setMatrixAt(f.i, dummy.matrix); continue; }
        f.alive = true; f.p.copy(f.s.home).add(tv.set(G.rr(-2, 2), G.rr(0, 2), G.rr(-2, 2))); f.v.set(0, 0.2, 0);
      }
      const sh = f.s, acc = tv.set(0, 0, 0);
      acc.addScaledVector(tv2.copy(sh.c).sub(f.p), 0.5);
      acc.addScaledVector(tv2.copy(sh.v).sub(f.v), 0.6);
      const goal = sh.alarm > 0 && sh.threat !== S.center ? sh.home : sh.goal;
      acc.addScaledVector(tv2.copy(goal).sub(f.p).clampLength(0, 8), sh.alarm > 0 ? 1.2 : 0.35);
      for (const o of sh.members) {
        if (o === f || !o.alive) continue;
        const dx = f.p.x - o.p.x, dy = f.p.y - o.p.y, dz = f.p.z - o.p.z, d2 = dx * dx + dy * dy + dz * dz;
        if (d2 < 0.6 && d2 > 1e-5) { const k = 1.8 / (d2 + 0.05); acc.x += dx * k; acc.y += dy * k; acc.z += dz * k; }
      }
      if (sh.threat) { tv2.copy(f.p).sub(sh.threat); const d = tv2.length(); if (d < 14 && d > 0.01) acc.addScaledVector(tv2.normalize(), 10 * (1 - d / 14) + 2); }
      for (const vl of E.veils) {
        const dx = f.p.x - vl.p.x, dz = f.p.z - vl.p.z, dh = Math.hypot(dx, dz) + 0.01;
        if (f.p.y < vl.p.y + 2 && f.p.y > vl.p.y - vl.len && dh < vl.r + 3) {
          acc.x += dx / dh * 2.2; acc.z += dz / dh * 2.2;
          if (dh < vl.r * 0.85 && f.p.y < vl.p.y - 0.5 && G.rng() < dt * 0.22) {
            killFish(f); E.emit('veil', 'sting', f.p, () => `${cap(G.nm('veil'))} ужалила ${G.nm('fish', 'acc')}`); break;
          }
        }
      }
      if (!f.alive) continue;
      acc.x += Math.sin(t * 1.7 + f.ph) * 0.6; acc.y += Math.sin(t * 1.3 + f.ph * 2) * 0.3; acc.z += Math.cos(t * 1.5 + f.ph) * 0.6;
      const h = H(f.p.x, f.p.z);
      if (f.p.y < h + 1.2) acc.y += (h + 1.2 - f.p.y) * 6;
      if (f.p.y > -3) acc.y -= 4;
      f.v.addScaledVector(acc, dt);
      const hide = sh.alarm > 0 && f.p.distanceTo(sh.home) < 4;
      const maxS = hide ? 1.0 : (sh.alarm > 0 ? 6.5 : 2.4);
      const sp = f.v.length();
      if (sp > maxS) f.v.multiplyScalar(maxS / sp); else if (sp < 0.5) f.v.multiplyScalar(0.5 / (sp + 1e-3));
      f.p.addScaledVector(f.v, dt);
      S.pushOut(f.p, 0.3, f.v); // сквозь корпус не проплывают
      if (f.p.y < h + 0.4) f.p.y = h + 0.4;
      clampArea(f.p);
      dummy.position.copy(f.p); dummy.lookAt(tv2.copy(f.p).add(f.v)); dummy.rotateY(Math.sin(t * 12 + f.ph) * 0.25);
      dummy.scale.setScalar(1); dummy.updateMatrix(); im.setMatrixAt(f.i, dummy.matrix);
    }
    im.instanceMatrix.needsUpdate = true;
  }

  /* ======================= СЕРПОХВОСТЫ ======================= */
  const PSEG = 11;
  function initPreds(scene) {
    const N = 3;
    E.predSegIM = new THREE.InstancedMesh(new THREE.SphereGeometry(1, 10, 8), new THREE.MeshLambertMaterial({ color: 0x31445e, emissive: 0x070b12 }), N * (PSEG - 1));
    E.predDotIM = new THREE.InstancedMesh(new THREE.SphereGeometry(0.07, 6, 4), new THREE.MeshBasicMaterial({ color: 0xff9a3c }), N * (PSEG - 1) * 2);
    [E.predSegIM, E.predDotIM].forEach(m => { m.frustumCulled = false; scene.add(m); });
    const starts = [[-60, 20], [70, -20], [10, -110]];
    E.predHeadParts = partsIM(scene, [
      { g: new THREE.SphereGeometry(1, 12, 8), mat: new THREE.MeshLambertMaterial({ color: 0x3a5272 }), m: new THREE.Matrix4().makeScale(0.55, 0.5, 1.3) },
      { g: new THREE.ConeGeometry(0.35, 1.1, 8), mat: new THREE.MeshLambertMaterial({ color: 0x1d2838 }), m: mTRS(0, -0.22, 0.95, Math.PI / 2, 0, 0, 1, 1, 1) },
      { g: new THREE.SphereGeometry(0.1, 8, 6), mat: new THREE.MeshBasicMaterial({ color: 0xff3b4e }), m: [mT(-0.33, 0.16, 0.72), mT(0.33, 0.16, 0.72)], per: 2 }
    ], N);
    E.predLeechParts = partsIM(scene, [{ g: leechGeo(), mat: new THREE.MeshLambertMaterial({ color: 0x8a2f3c, emissive: 0x3a0a12 }), m: mTRS(0.5, -0.05, 0.25, 0, 0.4, -0.5, 1, 1, 1) }], N);
    E.predTailParts = partsIM(scene, [{ g: new THREE.TorusGeometry(1.1, 0.08, 5, 18, Math.PI * 0.95), mat: new THREE.MeshLambertMaterial({ color: 0x5a7394, emissive: 0x140c1c }), m: mTRS(0, 0, -0.9, 0, Math.PI / 2, -Math.PI / 2, 1, 1, 1) }], N);
    for (let i = 0; i < N; i++) {
      const p = new V3(starts[i][0], 0, starts[i][1]); p.y = Math.min(H(p.x, p.z) + 8, -6);
      const leechM = { visible: false }; // пиявник рисуется общим InstancedMesh, тут только видимость
      const pr = { p, v: new V3(0, 0, 1), state: 'patrol', hunger: G.rr(0.1, 0.5), timer: 0, target: null, goal: p.clone(), segs: [], cd: 20, avoidCd: 0, i,
        leech: false, leechCd: 0, angryCd: 0, truceCd: 0, flareCd: 0, station: null, leechM, leechP: new V3(), p0: p.clone() };
      setLeech(pr, i === 0); pr.leechCd = G.rr(90, 160);
      for (let k = 0; k < PSEG; k++) pr.segs.push(p.clone().add(new V3(0, 0, -k * 0.6)));
      E.preds.push(pr);
    }
  }
  function leechGeo() { const g = new THREE.CapsuleGeometry(0.09, 0.32, 3, 6); g.rotateX(Math.PI / 2); g.scale(1.4, 0.45, 1); return g; }
  function setLeech(pr, on) { pr.leech = on; pr.leechM.visible = on; if (!on) pr.station = null; }
  function startCharge(pr) {
    pr.state = 'charge'; pr.timer = 10;
    const ping = G.Game.t - E.lastPing < 12;
    if (G.Ship.light) E.emit('pred', 'ship', pr.p, () => `${cap(G.nm('pred'))} разворачивается к кораблю — его привлёк свет`);
    else if (ping) E.emit('pred', 'ping', pr.p, () => `${cap(G.nm('pred'))} разворачивается к кораблю — его привлёк сонар`);
    else if (E.shipWake > 0.5) E.emit('plankton', 'betray', pr.p, () => `${cap(G.nm('pred'))} заметил светящийся след ${G.nm('plankton', 'gen')} и разворачивается к кораблю`);
    else E.emit('pred', 'hear', pr.p, () => `${cap(G.nm('pred'))} услышал двигатели и разворачивается к кораблю`);
  }
  E.lure = pr => startCharge(pr); // серпохвост идёт на корабль (эхоловец заманил светом)
  function predUpdate(pr, dt) {
    const S = G.Ship;
    pr.hunger = Math.min(1, pr.hunger + dt * (pr.state === 'clean' ? 0.01 : pr.leech ? 0.05 : 0.03)); pr.timer -= dt; pr.cd -= dt; pr.avoidCd -= dt; pr.truceCd -= dt; pr.angryCd -= dt; pr.flareCd -= dt;
    const dShip = pr.p.distanceTo(S.center), atStation = nearStation(pr.p);
    const reach = (pr.leech ? 48 : 32) * G.Run.predK(); // заражённый пиявником замечает корабль издалека; глубже — чутьё острее
    const lured = ((dShip < reach * (G.Silt.inside ? 0.4 : 1) && (S.light || G.Game.t - E.lastPing < 12 || E.shipWake > 0.5)) || hearsShip(pr, dShip)) // в иле свет корабля почти не виден && !E.shipHidden && S.hull > 0;
    const canAttack = pr.cd <= 0 && pr.hunger > (pr.leech ? 0.1 : 0.2) && lured && !E.shipSheltered && !atStation;
    /* вспышка радужников выдаёт корабль издалека: хищник плывёт проверить */
    if (E.flare > 0.5 && dShip >= reach && dShip < FLARE_REACH && !E.shipHidden && !E.shipSheltered && S.hull > 0 && pr.cd <= 0 && (pr.state === 'patrol' || pr.state === 'investigate')) {
      pr.state = 'investigate'; pr.goal.copy(S.center); pr.timer = 25;
      if (pr.flareCd <= 0) { pr.flareCd = 30; E.emit('raduzh', 'betray', pr.p, () => `${cap(G.nm('pred'))} заметил вспышку ${G.nm('raduzh', 'gen')} и плывёт к кораблю`); }
    }
    if (pr.leech && canAttack && dShip > 32 && pr.angryCd <= 0) { pr.angryCd = 60; E.emit('leech', 'angry', pr.p, () => `Заражённый ${G.nm('pred')} злее обычного и замечает корабль издалека`); }
    if (lured && E.shipSheltered && pr.cd <= 0 && pr.truceCd <= 0 && (pr.state === 'patrol' || pr.state === 'investigate')) {
      pr.truceCd = 40; pr.cd = Math.max(pr.cd, 8);
      E.emit('ognevka', 'shelter', pr.p, () => `${cap(G.nm('pred'))} не трогает корабль у станции чистки`);
    }
    /* заражение пиявником и поиск станции чистки */
    if (!pr.leech) {
      pr.leechCd -= dt;
      if (pr.leechCd <= 0 && !atStation) { setLeech(pr, true); E.emit('leech', 'infest', pr.p, () => `${cap(G.nm('leech'))} присосался к жабрам ${G.nm('pred', 'acc')}`); }
    } else if (!pr.station && pr.hunger < 0.45 && (pr.state === 'patrol' || pr.state === 'eat') && E.stations.length) {
      pr.station = nearestStation(pr.p); pr.state = 'clean'; pr.timer = 60; pr.goal.copy(pr.station.top);
    }
    let speed = 3;
    switch (pr.state) {
      case 'patrol':
        if (pr.timer <= 0 || pr.p.distanceTo(pr.goal) < 4) {
          pr.timer = G.rr(10, 20);
          if (G.rng() < 0.6 && E.shoals.length) { const h = G.pick(E.shoals).home; pr.goal.set(h.x + G.rr(-25, 25), 0, h.z + G.rr(-25, 25)); }
          else pr.goal.set(G.rr(-170, 150), 0, G.rr(-170, 150));
          pr.goal.y = Math.min(H(pr.goal.x, pr.goal.z) + G.rr(4, 14), -6);
        }
        if (pr.hunger > 0.45 && !atStation) { const f = nearestFish(pr.p, 50); if (f) { pr.state = 'hunt'; pr.target = f; pr.timer = 12; } }
        if (canAttack) startCharge(pr);
        break;
      case 'clean': {
        const st = pr.station;
        if (!st || !pr.leech) { pr.state = 'patrol'; pr.timer = 0; break; }
        const d = pr.p.distanceTo(st.top);
        speed = d < 4 ? 0.6 : 4;
        pr.goal.copy(st.top);
        if (d < 4) { st.busy = pr; st.work += dt; }
        if (st.work >= 6) {
          st.work = 0; st.busy = null; setLeech(pr, false); pr.leechCd = G.rr(150, 260); pr.state = 'patrol'; pr.timer = G.rr(4, 8); pr.hunger = Math.min(pr.hunger, 0.3);
          E.emit('ognevka', 'clean', st.top, () => `${cap(G.nm('pred'))} на станции чистки: его очистили от ${G.nm('leech', 'acc')}`);
          E.emit('leech', 'cleaned', st.top, null);
        } else if (pr.timer <= 0 || pr.hunger > 0.9) { pr.state = 'patrol'; pr.station = null; pr.timer = 0; }
        if (canAttack && pr.hunger > 0.6) startCharge(pr);
        break;
      }
      case 'hunt':
        speed = 7.6;
        if (!pr.target || !pr.target.alive || pr.timer <= 0) { pr.state = 'patrol'; pr.timer = 0; pr.target = null; break; }
        if (atStation || nearStation(pr.target.p)) { // у станции чистки перемирие
          pr.state = 'patrol'; pr.timer = G.rr(4, 8); pr.target = null;
          if (pr.truceCd <= 0) { pr.truceCd = 40; E.emit('ognevka', 'truce', pr.p, () => `${cap(G.nm('pred'))} бросил охоту у станции чистки`); }
          break;
        }
        { const gr = kelpShelter(pr.target); // стая нырнула в густой ленточник
          if (gr) {
            pr.state = 'patrol'; pr.timer = G.rr(4, 8); pr.target = null;
            if (gr.msgCd <= 0) { gr.msgCd = 40; E.emit('fish', 'kelp', gr.c, () => `${cap(G.nm('fish'))}: стая спряталась в ленточнике, ${G.nm('pred')} её потерял`); }
            break;
          } }
        { const cu = inkAt(pr.target.p); // светляк скрылся в чернилах подушечника
          if (cu) {
            pr.state = 'patrol'; pr.timer = G.rr(4, 8); pr.target = null;
            if (cu.hideCd <= 0) { cu.hideCd = 30; E.emit('cushion', 'hide', cu.inkC, () => `${cap(G.nm('fish'))}: стая скрылась в чернилах ${G.nm('cushion', 'gen')}, ${G.nm('pred')} её потерял`); }
            break;
          } }
        { const gr = grotShelter(pr.target); // стая нырнула в риф на спине гротовика
          if (gr) {
            pr.state = 'patrol'; pr.timer = G.rr(4, 8); pr.target = null;
            if (gr.hideCd <= 0) { gr.hideCd = 40; E.emit('grot', 'hide', gr.back, () => `${cap(G.nm('fish'))}: стая спряталась в рифе на спине ${G.nm('grot', 'gen')}, ${G.nm('pred')} её потерял`); }
            break;
          } }
        pr.goal.copy(pr.target.v).multiplyScalar(0.4).add(pr.target.p);
        if (pr.p.distanceTo(pr.target.p) < 1.6) {
          const bare = groveOf(pr.target.p);
          killFish(pr.target); pr.hunger = 0; pr.state = 'eat'; pr.timer = 5; pr.target = null;
          E.emit('pred', 'catch', pr.p, () => `${cap(G.nm('pred'))} поймал ${G.nm('fish', 'acc')}`);
          if (bare && bare.cover < COVER_MIN && bare.msgCd <= 0) { bare.msgCd = 40; E.emit('ezh', 'bare', bare.c, () => `Ленточник объеден ${SP.ezh.scanned ? 'шипоежами' : 'морскими ежами'}: стае негде спрятаться`); }
        } else if (canAttack && pr.hunger > 0.6) startCharge(pr);
        break;
      case 'eat': speed = 1; if (pr.timer <= 0) { pr.state = 'patrol'; pr.timer = 0; } break;
      case 'investigate':
        speed = 5.5;
        if (pr.p.distanceTo(pr.goal) < 10 || pr.timer <= 0) { pr.state = 'patrol'; pr.timer = 0; }
        if (canAttack) startCharge(pr);
        break;
      case 'charge':
        speed = 9.5; pr.goal.copy(S.center);
        if (E.shipSheltered) {
          pr.state = 'retreat'; pr.timer = 8; pr.cd = Math.max(pr.cd, 15); pr.goal.copy(pr.p).add(tv.set(G.rr(-40, 40), 4, G.rr(-40, 40))); pr.goal.y = Math.min(pr.goal.y, -6);
          if (pr.truceCd <= 0) { pr.truceCd = 40; E.emit('ognevka', 'shelter', pr.p, () => `${cap(G.nm('pred'))} отвернул: корабль у станции чистки`); }
          break;
        }
        if (E.shipHidden) {
          pr.state = 'retreat'; pr.timer = 10; pr.goal.copy(pr.p).add(tv.set(G.rr(-40, 40), 5, G.rr(-40, 40))); pr.goal.y = Math.min(pr.goal.y, -6);
          if (E.shipInk) E.emit('cushion', 'ship', pr.p, () => `Корабль в чернилах ${G.nm('cushion', 'gen')}: ${G.nm('pred')} потерял его из виду`);
          else E.emit('veil', 'hide', pr.p, () => `Корабль под куполом: ${G.nm('pred')} потерял его из виду`);
          break;
        }
        if (dShip < 8.5 || S.hullDist(pr.p) < 1.2) { // кусает, когда дотянулся до корпуса
          G.Game.hullHit(12, 'bite');
          pr.state = 'retreat'; pr.timer = 14; pr.cd = 25;
          tv.copy(pr.p).sub(S.center).setY(0); if (tv.lengthSq() < 0.01) tv.set(1, 0, 0);
          pr.goal.copy(pr.p).add(tv.normalize().multiplyScalar(60)); pr.goal.y = Math.min(H(pr.goal.x, pr.goal.z) + 8, -6);
        } else if (pr.timer <= 0) { pr.state = 'patrol'; pr.cd = 10; }
        break;
      case 'retreat': case 'flee':
        speed = pr.state === 'flee' ? 9 : 6;
        if (pr.timer <= 0) { pr.state = 'patrol'; pr.timer = 0; }
        break;
    }
    const steer = tv2.copy(pr.state === 'charge' ? pr.goal : S.detour(pr.p, pr.goal, 0.7, tv3)).sub(pr.p); // в броске — прямо на корпус, иначе в обход
    if (pr.leech && pr.state !== 'clean') speed *= 0.75; // пиявник замедляет хищника
    if (steer.lengthSq() > 1e-4) steer.normalize().multiplyScalar(speed);
    for (const vl of E.veils) {
      const dx = pr.p.x - vl.p.x, dz = pr.p.z - vl.p.z, dh = Math.hypot(dx, dz) + 0.01;
      if (dh < vl.r + 9 && pr.p.y < vl.p.y + 4 && pr.p.y > vl.p.y - vl.len - 2) {
        steer.x += dx / dh * 8; steer.z += dz / dh * 8;
        if (pr.avoidCd <= 0) { pr.avoidCd = 40; E.emit('pred', 'avoid', pr.p, () => `${cap(G.nm('pred'))} обходит ${G.nm('veil', 'acc')} стороной`); }
      }
    }
    pr.v.lerp(steer, Math.min(1, dt * (pr.state === 'hunt' || pr.state === 'charge' ? 1.6 : 1.1)));
    pr.p.addScaledVector(pr.v, dt);
    const h = H(pr.p.x, pr.p.z);
    if (pr.p.y < h + 1.8) { pr.p.y = h + 1.8; if (pr.v.y < 0) pr.v.y *= -0.3; }
    if (pr.p.y > -4) pr.p.y = -4;
    clampArea(pr.p);
    S.pushOut(pr.p, 0.7, pr.v); // корпус не пускает внутрь
  }
  function predRender(pr, idx, t) {
    const segs = pr.segs; segs[0].copy(pr.p);
    for (let k = 1; k < segs.length; k++) { tv.copy(segs[k]).sub(segs[k - 1]); const L = tv.length(); if (L > 0.62) segs[k].copy(segs[k - 1]).addScaledVector(tv, 0.62 / L); G.Ship.pushOut(segs[k], 0.45); }
    dummy.position.copy(pr.p); dummy.rotation.set(0, 0, 0); dummy.scale.setScalar(1);
    dummy.lookAt(tv.copy(pr.p).add(pr.v.lengthSq() > 0.01 ? tv3.copy(pr.v) : tv3.set(0, 0, 1))); dummy.updateMatrix();
    const headM = pr.headM = (pr.headM || new THREE.Matrix4()).copy(dummy.matrix);
    placeParts(E.predHeadParts, idx, headM, false);
    placeParts(E.predLeechParts, idx, headM, !pr.leechM.visible);
    pr.leechP.set(0, 0, 0).applyMatrix4(tm.multiplyMatrices(headM, E.predLeechParts[0].m));
    const freq = 3 + pr.v.length() * 0.6;
    const base = idx * (PSEG - 1);
    let lastPos = null;
    for (let k = 1; k < segs.length; k++) {
      tv.copy(segs[k - 1]).sub(segs[k]); if (tv.lengthSq() < 1e-6) tv.set(0, 0, 1); tv.normalize();
      tv2.set(tv.z, 0, -tv.x); if (tv2.lengthSq() < 1e-6) tv2.set(1, 0, 0); tv2.normalize();
      const w = Math.sin(t * freq - k * 0.75) * 0.08 * k;
      dummy.position.copy(segs[k]).addScaledVector(tv2, w);
      dummy.lookAt(tv3.copy(dummy.position).add(tv));
      const r = 0.55 * (1 - (k - 1) / segs.length * 0.8);
      dummy.scale.set(r * 0.9, r, r * 1.5); dummy.updateMatrix();
      E.predSegIM.setMatrixAt(base + k - 1, dummy.matrix);
      [-1, 1].forEach((s, j) => {
        tv3.set(0.95 * s, 0.25, 0).applyMatrix4(dummy.matrix);
        const m = new THREE.Matrix4().makeTranslation(tv3.x, tv3.y, tv3.z);
        E.predDotIM.setMatrixAt((base + k - 1) * 2 + j, m);
      });
      lastPos = (pr.lastPos = pr.lastPos || new V3()).copy(dummy.position);
    }
    dummy.position.copy(lastPos); dummy.rotation.set(0, 0, 0); dummy.scale.setScalar(1); dummy.lookAt(segs[segs.length - 2]); dummy.updateMatrix();
    placeParts(E.predTailParts, idx, dummy.matrix, false);
  }

  /* ======================= ФОНАРНЫЕ ВУАЛИ ======================= */
  function initVeils(scene) {
    [[-28, 42], [85, 25]].forEach(([x, z], i) => {
      const top = Math.min(H(x, z) + 21, -9);
      const vl = { p: new V3(x, top, z), home: new V3(x, top, z), r: 6, len: 15, ph: i * 2.1, group: new THREE.Group(), scanP: new V3() };
      const bell = new THREE.Mesh(new THREE.SphereGeometry(vl.r, 28, 12, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshBasicMaterial({ color: 0x7ff5ff, transparent: true, opacity: 0.22, side: THREE.DoubleSide, depthWrite: false }));
      const inner = new THREE.Mesh(new THREE.SphereGeometry(vl.r * 0.6, 20, 10, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshBasicMaterial({ color: 0xff8ae0, transparent: true, opacity: 0.28, side: THREE.DoubleSide, depthWrite: false }));
      vl.group.add(bell, inner); vl.bell = bell; vl.inner = inner;
      const rp = []; for (let k = 0; k < 48; k++) { const a = k / 48 * 6.283; rp.push(Math.cos(a) * vl.r, 0, Math.sin(a) * vl.r); }
      const rg = new THREE.BufferGeometry(); rg.setAttribute('position', new THREE.Float32BufferAttribute(rp, 3));
      vl.rim = new THREE.Points(rg, new THREE.PointsMaterial({ color: 0xcffcff, size: 0.5, transparent: true, opacity: 0.9 }));
      vl.group.add(vl.rim);
      const smallM = new THREE.MeshBasicMaterial({ color: 0xbff8ff, transparent: true, opacity: 0.35, depthWrite: false, side: THREE.DoubleSide });
      vl.small = [];
      for (let k = 0; k < 9; k++) { const s = new THREE.Mesh(new THREE.SphereGeometry(G.rr(0.5, 1), 12, 6, 0, Math.PI * 2, 0, Math.PI / 2), smallM); const a = k / 9 * 6.283; s.position.set(Math.cos(a) * (vl.r + 1.2), G.rr(-3, -1), Math.sin(a) * (vl.r + 1.2)); s.userData.ph = G.rr(0, 6); vl.group.add(s); vl.small.push(s); }
      const T = 40, SG = 10, arr = new Float32Array(T * SG * 2 * 3);
      const tg = new THREE.BufferGeometry(); tg.setAttribute('position', new THREE.BufferAttribute(arr, 3));
      vl.lines = new THREE.LineSegments(tg, new THREE.LineBasicMaterial({ color: 0xff9ae6, transparent: true, opacity: 0.6 }));
      vl.lines.frustumCulled = false; vl.group.add(vl.lines);
      vl.tent = { arr, tg, T, SG, base: Array.from({ length: T }, (_, k) => ({ a: k / T * 6.283 + G.rr(-0.05, 0.05), rr: vl.r * G.rr(0.25, 0.9), len: vl.len * G.rr(0.6, 1) })) };
      scene.add(vl.group); E.veils.push(vl);
    });
  }
  function veilUpdate(vl, dt, t) {
    vl.p.x += Math.sin(t * 0.031 + vl.ph) * 0.6 * dt + (vl.home.x - vl.p.x) * 0.004 * dt;
    vl.p.z += Math.cos(t * 0.027 + vl.ph * 1.7) * 0.6 * dt + (vl.home.z - vl.p.z) * 0.004 * dt;
    const floor = H(vl.p.x, vl.p.z) + vl.len + 3;
    vl.p.y = Math.min(Math.max(vl.home.y, floor), -7) + Math.sin(t * 0.3 + vl.ph) * 1.2;
    vl.group.position.copy(vl.p); vl.scanP.copy(vl.p).y -= 3;
    const s = 1 + Math.sin(t * 1.3 + vl.ph) * 0.07, s2 = 1 + Math.sin(t * 1.3 + vl.ph - 0.6) * 0.09;
    vl.bell.scale.set(s, 1 / s, s); vl.inner.scale.set(s2, 1 / s2, s2); vl.rim.scale.set(s, 1, s);
    vl.rim.material.opacity = 0.6 + 0.4 * Math.sin(t * 2.6 + vl.ph);
    vl.small.forEach(m => { const q = 1 + Math.sin(t * 2 + m.userData.ph) * 0.15; m.scale.set(q, 1 / q, q); });
    const { arr, T, SG, base } = vl.tent;
    let o = 0;
    for (let k = 0; k < T; k++) {
      const b = base[k], x0 = Math.cos(b.a) * b.rr * s, z0 = Math.sin(b.a) * b.rr * s, step = b.len / SG;
      let px = x0, py = -0.1, pz = z0;
      for (let j = 0; j < SG; j++) {
        const nx = x0 + Math.sin(t * 0.9 + j * 0.45 + k) * (j + 1) * 0.12;
        const nz = z0 + Math.cos(t * 0.7 + j * 0.4 + k * 1.3) * (j + 1) * 0.12;
        const ny = -(j + 1) * step;
        arr[o++] = px; arr[o++] = py; arr[o++] = pz; arr[o++] = nx; arr[o++] = ny; arr[o++] = nz;
        px = nx; py = ny; pz = nz;
      }
    }
    vl.tent.tg.attributes.position.needsUpdate = true;
  }

  /* ======================= СКРЕБУНЫ ======================= */
  /* светящиеся точки на панцире: генератор тратится как раньше (по 20 чисел на скребуна), чтобы не сдвинуть мир */
  function grazerDots() {
    const dp = [];
    for (let k = 0; k < 10; k++) { const a = G.rr(0, 6.28), b = G.rr(0.25, 1.25); dp.push(new V3(Math.cos(a) * Math.sin(b) * 0.8, Math.cos(b) * 0.48, Math.sin(a) * Math.sin(b) * 1.04)); }
    return dp;
  }
  function grazerParts(scene, dots, N) {
    const shell = new THREE.SphereGeometry(0.8, 14, 8, 0, Math.PI * 2, 0, Math.PI / 2); shell.scale(1, 0.6, 1.3);
    const dg = G.merge(dots.map(d => ({ g: new THREE.SphereGeometry(0.07, 6, 4), m: mT(d.x, d.y, d.z) })));
    const lp = [];
    [-1, 1].forEach(s => { for (let k = 0; k < 3; k++) { const geo = new THREE.CylinderGeometry(0.035, 0.03, 0.6, 4); geo.translate(0, -0.3, 0); lp.push({ g: geo, m: new THREE.Matrix4().makeTranslation(s * 0.6, 0.15, (k - 1) * 0.45).multiply(new THREE.Matrix4().makeRotationZ(s * 0.9)) }); } });
    return partsIM(scene, [
      { g: shell, mat: new THREE.MeshLambertMaterial({ color: 0x7b6a8c, emissive: 0x120a18 }), m: new THREE.Matrix4() },
      { g: dg, mat: new THREE.MeshBasicMaterial({ color: 0xffb259 }), m: new THREE.Matrix4() },
      { g: G.merge(lp), mat: new THREE.MeshLambertMaterial({ color: 0x3a2f45 }), m: new THREE.Matrix4() }
    ], N);
  }
  const gzShellL = new THREE.Matrix4(), gzLegL = new THREE.Matrix4(), gzBase = new THREE.Matrix4();
  function grazerRender(gz) {
    if (!gz.visible) { placeParts(E.grazerParts, gz.i, gzBase, true); return; }
    gzBase.compose(gz.p, tq.setFromAxisAngle(tv.set(0, 1, 0), gz.dir), tv2.set(1, 1, 1));
    gzShellL.makeRotationX(gz.shellRot || 0); gzLegL.makeRotationX(gz.legRot || 0);
    placeParts(E.grazerParts, gz.i, gzBase, false, [gzShellL, null, gzLegL]);
  }
  const tq = new THREE.Quaternion();
  function pickPatch(gz) {
    let best = null, bs = -1;
    for (const pt of G.World.patches) {
      if (pt === gz.patch) continue;
      const s = pt.food / (1 + Math.hypot(pt.x - gz.p.x, pt.z - gz.p.z) / 25) * G.rr(0.7, 1.3);
      if (s > bs) { bs = s; best = pt; }
    }
    return best;
  }
  function initGrazers(scene) {
    const P = G.World.patches; if (!P.length) return;
    for (let i = 0; i < 10; i++) {
      const pt = P[(i * 2) % P.length];
      const gz = { i, p: new V3(pt.x + G.rr(-3, 3), pt.y, pt.z + G.rr(-3, 3)), dir: G.rr(0, 6.28), state: 'walk', patch: null, timer: 0, alive: true, t: 0, gcd: G.rr(0, 20), dots: grazerDots(), visible: true, legRot: 0, shellRot: 0 };
      gz.patch = pickPatch(gz); E.grazers.push(gz);
    }
    E.grazerParts = grazerParts(scene, E.grazers[0].dots, E.grazers.length);
    E.grazers.forEach(grazerRender);
  }
  function grazerUpdate(gz, dt, t) {
    if (!gz.alive) {
      gz.t -= dt;
      if (gz.t <= 0) { const pt = G.pick(G.World.patches); gz.p.set(pt.x + G.rr(-3, 3), 0, pt.z + G.rr(-3, 3)); gz.patch = pickPatch(gz); gz.state = 'walk'; gz.alive = true; gz.visible = true; }
      else { grazerRender(gz); return; }
    }
    gz.gcd -= dt;
    if (gz.state === 'walk') {
      const tp = gz.patch; if (!tp) { gz.patch = pickPatch(gz); return; }
      const dx = tp.x - gz.p.x, dz = tp.z - gz.p.z, d = Math.hypot(dx, dz);
      if (d < 1.6) {
        gz.state = 'graze'; gz.timer = G.rr(8, 14);
        if (gz.gcd <= 0) { gz.gcd = 45; E.emit('grazer', 'graze', gz.p, () => `${cap(G.nm('grazer'))} объедает светящийся мох`); }
      } else {
        let da = Math.atan2(dx, dz) - gz.dir; da = Math.atan2(Math.sin(da), Math.cos(da));
        gz.dir += da * Math.min(1, dt * 1.5);
        gz.p.x += Math.sin(gz.dir) * 0.9 * dt; gz.p.z += Math.cos(gz.dir) * 0.9 * dt;
      }
      gz.legRot = Math.sin(t * 7 + gz.dir) * 0.18;
    } else {
      gz.patch.food = Math.max(0, gz.patch.food - dt * 0.05); gz.timer -= dt;
      gz.shellRot = Math.sin(t * 3) * 0.05;
      if (gz.timer <= 0 || gz.patch.food < 0.08) { gz.patch = pickPatch(gz); gz.state = 'walk'; }
    }
    gz.p.y = H(gz.p.x, gz.p.z) + 0.1;
    grazerRender(gz);
  }

  /* ======================= СТЕКЛОУСТЫ ======================= */
  const ESEG = 14;
  function initEels(scene) {
    const L = G.World.lairs, N = L.length;
    E.eelIM = new THREE.InstancedMesh(new THREE.SphereGeometry(1, 10, 8), new THREE.MeshLambertMaterial({ color: 0xc8f8ff, emissive: 0x2a6f7d, transparent: true, opacity: 0.4, depthWrite: false }), Math.max(1, N * (ESEG - 1)));
    E.eelDotIM = new THREE.InstancedMesh(new THREE.SphereGeometry(0.06, 6, 4), new THREE.MeshBasicMaterial({ color: 0xfff0a0 }), Math.max(1, N * (ESEG - 1)));
    [E.eelIM, E.eelDotIM].forEach(m => { m.frustumCulled = false; scene.add(m); });
    E.eelHeadParts = partsIM(scene, [
      { g: new THREE.SphereGeometry(0.3, 12, 8), mat: new THREE.MeshLambertMaterial({ color: 0xd8fbff, emissive: 0x2a6f7d, transparent: true, opacity: 0.55, depthWrite: false }), m: new THREE.Matrix4().makeScale(1, 0.8, 1.6) },
      { g: new THREE.SphereGeometry(0.09, 8, 6), mat: new THREE.MeshBasicMaterial({ color: 0xff3b4e }), m: mT(0, 0.13, 0.3) },
      { g: new THREE.TorusGeometry(0.17, 0.03, 6, 16), mat: new THREE.MeshBasicMaterial({ color: 0xffe2b8 }), m: mT(0, 0, 0.48) }
    ], N);
    L.forEach((lr, i) => {
      const el = { lair: lr.mouth.clone(), out: lr.out.clone(), state: 'hide', p: lr.mouth.clone(), target: null, kind: null, timer: 0, cd: G.rr(10, 25), segs: [], i };
      for (let k = 0; k < ESEG; k++) el.segs.push(lr.mouth.clone().addScaledVector(lr.out, -k * 0.45));
      E.eels.push(el);
    });
  }
  function eelUpdate(el, dt, t) {
    const S = G.Ship;
    el.timer -= dt; el.cd -= dt;
    let speed = 0, goal = null;
    switch (el.state) {
      case 'hide':
        el.p.copy(el.lair).addScaledVector(el.out, 0.3 + Math.sin(t * 0.8 + el.i) * 0.15);
        if (el.cd <= 0) {
          let prey = null, kind = null;
          for (const gz of E.grazers) if (gz.alive && gz.p.distanceTo(el.lair) < 9) { prey = gz; kind = 'grazer'; break; }
          if (!prey) for (const f of E.fish) if (f.alive && f.p.distanceTo(el.lair) < 6) { prey = f; kind = 'fish'; break; }
          if (prey && G.rng() < dt * 0.6) { el.state = 'strike'; el.target = prey; el.kind = kind; el.timer = 3; }
          else if (!E.latched && S.hull > 0 && S.front.distanceTo(el.lair) < 28 && G.rng() < dt * 0.5) {
            if (E.hullRemoras > 0) { // на корпусе уже кто-то есть — стеклоуст не садится
              el.cd = 15;
              if (E.rmEelCd <= 0) { E.rmEelCd = 40; E.emit('prisoska', 'eel', el.lair, () => `${cap(G.nm('eel'))} выглянул из расщелины, но не сел на корпус: там уже прилипалы`); }
            } else { el.state = 'toShip'; el.timer = 6; }
          }
        }
        break;
      case 'strike':
        speed = 11; goal = el.target.p;
        if (!el.target.alive || el.timer <= 0) { el.state = 'return'; el.cd = 8; break; }
        if (el.p.distanceTo(goal) < 1.3) {
          if (el.kind === 'grazer') {
            el.target.alive = false; el.target.t = G.rr(40, 60); el.target.visible = false;
            E.emit('eel', 'eelcatch', el.p, () => `${cap(G.nm('eel'))} утащил ${G.nm('grazer', 'acc')} в расщелину`);
          } else {
            killFish(el.target);
            E.emit('eel', 'eelcatch', el.p, () => `${cap(G.nm('eel'))} схватил ${G.nm('fish', 'acc')}`);
          }
          el.state = 'return'; el.cd = 25;
        }
        break;
      case 'return': case 'flee':
        speed = el.state === 'flee' ? 12 : 6; goal = el.lair;
        if (el.p.distanceTo(el.lair) < 0.8) el.state = 'hide';
        break;
      case 'toShip':
        speed = 10; goal = S.detour(el.p, S.front, 0.3, tv3); // к носу — вокруг корпуса
        if (E.latched || el.timer <= 0) { el.state = 'return'; el.cd = 15; break; }
        if (el.p.distanceTo(S.front) < 2) {
          el.state = 'latched'; E.latched = el;
          E.emit('eel', 'latch', el.p, () => `${cap(G.nm('eel'))} присосался к корпусу!`);
          G.Game.onLatch();
        }
        break;
    }
    if (goal) { tv.copy(goal).sub(el.p); const d = tv.length(); if (d > 0.01) el.p.addScaledVector(tv, Math.min(1, speed * dt / d)); }
    if (el.state !== 'hide' && el.state !== 'latched') S.pushOut(el.p, 0.3);
    const segs = el.segs;
    if (el.state === 'latched') {
      for (let k = 0; k < ESEG; k++) S.group.localToWorld(segs[k].set(-3.4 + k * 0.5, 1.8 + Math.sin(k * 0.8 + t * 2.2) * 0.45, -6.36));
      el.p.copy(segs[0]);
    } else if (el.state === 'hide') {
      for (let k = 0; k < ESEG; k++) segs[k].copy(el.p).addScaledVector(el.out, -(k + 0.5) * 0.45);
    } else {
      segs[0].copy(el.p);
      for (let k = 1; k < ESEG; k++) { tv.copy(segs[k]).sub(segs[k - 1]); const L = tv.length(); if (L > 0.42) segs[k].copy(segs[k - 1]).addScaledVector(tv, 0.42 / L); S.pushOut(segs[k], 0.25); }
    }
  }
  function eelRender(el, idx, t) {
    const segs = el.segs, base = idx * (ESEG - 1), moving = el.state !== 'hide' && el.state !== 'latched';
    for (let k = 1; k < ESEG; k++) {
      tv.copy(segs[k - 1]).sub(segs[k]); if (tv.lengthSq() < 1e-6) tv.set(0, 0, 1); tv.normalize();
      tv2.set(tv.z, 0, -tv.x); if (tv2.lengthSq() < 1e-6) tv2.set(1, 0, 0); tv2.normalize();
      const w = moving ? Math.sin(t * 10 - k * 0.9) * 0.05 * k : 0;
      dummy.position.copy(segs[k]).addScaledVector(tv2, w);
      dummy.lookAt(tv3.copy(dummy.position).add(tv));
      const r = 0.28 * (1 - k / ESEG * 0.7);
      dummy.scale.set(r, r * 0.85, r * 2.6); dummy.updateMatrix();
      E.eelIM.setMatrixAt(base + k - 1, dummy.matrix);
      E.eelDotIM.setMatrixAt(base + k - 1, new THREE.Matrix4().makeTranslation(dummy.position.x, dummy.position.y, dummy.position.z));
    }
    dummy.position.copy(segs[0]); dummy.rotation.set(0, 0, 0); dummy.scale.setScalar(1);
    dummy.lookAt(tv.copy(segs[0]).multiplyScalar(2).sub(segs[1])); dummy.updateMatrix();
    placeParts(E.eelHeadParts, idx, dummy.matrix, false);
  }

  /* ======================= ЛЕДОКРЫЛЫ ======================= */
  function rayGeo() {
    const g = new THREE.PlaneGeometry(14, 9, 18, 8); g.rotateX(-Math.PI / 2);
    const p = g.attributes.position, col = new Float32Array(p.count * 3);
    for (let i = 0; i < p.count; i++) {
      const x = p.getX(i), z = p.getZ(i);
      const f = Math.max(0.05, 1 - Math.pow(Math.abs(z + 0.6) / 5.1, 1.6));
      const nx = x * f; p.setX(i, nx);
      p.setY(i, Math.max(0, 1 - Math.abs(nx) / 2.2) * 0.5 * Math.max(0, 1 - Math.abs(z) / 4.5));
      const edge = Math.abs(x) / 7, c = 0.4 + edge * 0.6;
      col[i * 3] = c * 0.75; col[i * 3 + 1] = c * 1.0; col[i * 3 + 2] = c * 1.15;
    }
    g.setAttribute('color', new THREE.BufferAttribute(col, 3));
    g.computeVertexNormals();
    return g;
  }
  function initRays(scene) {
    [{ c: new V3(0, -9, 10), R: 85, sp: 4.2 }, { c: new V3(-140, -11, -90), R: 55, sp: 3.6 }].forEach((o, i) => {
      const geo = rayGeo();
      const mesh = new THREE.Mesh(geo, new THREE.MeshLambertMaterial({ color: 0xa8cfe0, emissive: 0x123848, side: THREE.DoubleSide, vertexColors: true }));
      const tail = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.12, 9, 5), mesh.material); tail.rotation.x = Math.PI / 2; tail.position.z = -8.5; mesh.add(tail);
      const spots = []; for (let k = 0; k < 14; k++) { const s = k % 2 ? 1 : -1; spots.push({ g: new THREE.SphereGeometry(0.12, 6, 4), m: new THREE.Matrix4().makeTranslation(s * (0.8 + (k >> 1) * 0.35), 0.45, 1 - (k >> 1) * 0.4) }); }
      mesh.add(new THREE.Mesh(G.merge(spots), new THREE.MeshBasicMaterial({ color: 0x9ffcff })));
      mesh.frustumCulled = false; scene.add(mesh);
      const ang = G.rr(0, 6.28);
      E.rays.push({ c: o.c, R: o.R, sp: o.sp, ang, ang0: ang, p: new V3(), dir: new V3(), mesh, geo, base: Float32Array.from(geo.attributes.position.array), fcd: G.rr(5, 15), i, init: false, nT: 0 });
    });
  }
  const RAY_WING = 11, RAY_OVER = 2.6;
  function rayUpdate(ry, dt, t) {
    ry.ang += ry.sp / ry.R * dt;
    const x = ry.c.x + Math.cos(ry.ang) * ry.R, z = ry.c.z + Math.sin(ry.ang) * ry.R;
    let ty = Math.min(-5.5, Math.max(ry.c.y + Math.sin(t * 0.2 + ry.i) * 1.5, H(x, z) + 7));
    /* корабль на пути: ледокрыл проплывает над ним, крылья не задевают корпус */
    const S = G.Ship, over = S.hullDist(tv.set(x, S.pos.y + 1.6, z)) < RAY_WING;
    if (over) ty = Math.min(-1, Math.max(ty, S.pos.y + 3.5 + RAY_OVER));
    ry.p.set(x, ry.init ? G.lerp(ry.p.y, ty, Math.min(1, dt * (over ? 3 : 0.5))) : ty, z); ry.init = true;
    S.pushOut(ry.p, 1.5);
    ry.dir.set(-Math.sin(ry.ang), 0, Math.cos(ry.ang));
    ry.mesh.position.copy(ry.p); ry.mesh.lookAt(tv.copy(ry.p).add(ry.dir)); ry.mesh.rotateZ(-0.22);
    const pa = ry.geo.attributes.position.array, b = ry.base;
    for (let i = 0; i < pa.length; i += 3) { const ax = Math.abs(b[i]); pa[i + 1] = b[i + 1] + Math.sin(t * 1.3 + ry.i - ax * 0.32) * Math.pow(ax / 7, 1.4) * 1.8; }
    ry.geo.attributes.position.needsUpdate = true;
    if (++ry.nT % 3 === 0) ry.geo.computeVertexNormals();
    ry.fcd -= dt;
    if (ry.fcd <= 0) {
      ry.fcd = G.rr(14, 22);
      let best = null, bd = 45;
      for (const sh of E.shoals) { const d = sh.c.distanceTo(ry.p); if (d < bd && !sh.follow) { bd = d; best = sh; } }
      if (best) {
        best.follow = ry; best.followT = 18;
        E.emit('ray', 'follow', ry.p, () => `${cap(G.nm('ray'))} ведёт за собой стаю рыб`);
        E.emit('fish', 'follow', ry.p, null);
      }
    }
  }


  /* ======================= ОГНЁВКИ И СТАНЦИИ ЧИСТКИ ======================= */
  const ST_R = 14, SHELTER_R = 18, SHRIMP = 10;
  function nearStation(p) { for (const st of E.stations) if (p.distanceTo(st.top) < ST_R) return st; return null; }
  function nearestStation(p) { let best = null, bd = 1e9; for (const st of E.stations) { const d = st.top.distanceTo(p); if (d < bd) { bd = d; best = st; } } return best; }
  E.nearStation = nearStation;
  function fireCoralGeo() { // огнецвет: веер толстых ветвей с огненными кончиками
    const parts = [], wood = new THREE.Color(0.75, 0.32, 0.16), tip = new THREE.Color(1, 0.75, 0.35);
    const trunk = new THREE.CylinderGeometry(0.28, 0.45, 2.2, 7); trunk.translate(0, 1.1, 0);
    parts.push({ g: trunk, c: wood });
    for (let k = 0; k < 6; k++) {
      const a = k / 6 * 6.283 + 0.3, tilt = 0.45 + (k % 2) * 0.25, L = 1.6 + (k % 3) * 0.35;
      const br = new THREE.CylinderGeometry(0.1, 0.2, L, 5); br.translate(0, L / 2, 0);
      const m = new THREE.Matrix4().makeTranslation(0, 1.9, 0).multiply(new THREE.Matrix4().makeRotationAxis(new V3(Math.sin(a), 0, -Math.cos(a)), tilt));
      parts.push({ g: br, m, c: wood });
      const tp = new THREE.SphereGeometry(0.22, 6, 4); tp.translate(0, L, 0);
      parts.push({ g: tp, m: m.clone(), c: tip });
    }
    return G.merge(parts);
  }
  function initStations(scene) {
    const spots = G.World.coralSpots;
    if (!spots.length) return;
    const geo = fireCoralGeo(), mat = new THREE.MeshLambertMaterial({ vertexColors: true, emissive: 0x5a1a04 });
    [[-45, 35], [38, 72], [22, -42]].forEach(([x, z]) => {
      let best = null, bd = 1e9;
      for (const sp of spots) { const d = Math.hypot(sp.x - x, sp.z - z); if (d < bd && E.stations.every(st => Math.hypot(st.base.x - sp.x, st.base.z - sp.z) > 40)) { bd = d; best = sp; } }
      if (!best) return;
      const base = best.clone(); base.y = H(base.x, base.z);
      const m = new THREE.Mesh(geo, mat); m.position.copy(base); m.rotation.y = G.rr(0, 6.28); m.scale.setScalar(1.3); scene.add(m);
      E.stations.push({ i: E.stations.length, base, top: base.clone().add(new V3(0, 4.2, 0)), busy: null, work: 0, mesh: m });
    });
    const sg = new THREE.CapsuleGeometry(0.06, 0.2, 2, 5); sg.rotateX(Math.PI / 2);
    E.shrimpIM = new THREE.InstancedMesh(sg, new THREE.MeshBasicMaterial({ color: 0xffa040 }), Math.max(1, E.stations.length * SHRIMP));
    E.shrimpIM.frustumCulled = false; scene.add(E.shrimpIM);
    E.shrimp = [];
    E.stations.forEach(st => { for (let k = 0; k < SHRIMP; k++) E.shrimp.push({ st, ph: G.rr(0, 6.28), r: G.rr(0.6, 1.6), h: G.rr(-0.6, 0.8), p: st.top.clone() }); });
  }
  function stationsUpdate(dt, t) {
    const S = G.Ship;
    E.shipSheltered = null;
    for (const st of E.stations) {
      if (st.busy && (st.busy.state !== 'clean' || st.busy.p.distanceTo(st.top) > 5)) st.busy = null;
      if (!st.busy) st.work = Math.max(0, st.work - dt * 0.5);
      if (S.center.distanceTo(st.top) < SHELTER_R) E.shipSheltered = st;
    }
    if (!E.shrimpIM) return;
    E.shrimp.forEach((sh, k) => {
      const st = sh.st, a = t * 0.8 + sh.ph;
      if (st.busy) tv.copy(st.busy.p).add(tv2.set(Math.cos(a * 2) * sh.r * 0.5, 0.4 + sh.h * 0.4, Math.sin(a * 2) * sh.r * 0.5));
      else if (k % 2 && E.fanAt && E.fanAt(st)) tv.copy(E.fanAt(st).top).add(tv2.set(Math.cos(a) * sh.r * 0.8, sh.h + Math.sin(t * 3 + sh.ph) * 0.3, Math.sin(a) * sh.r * 0.3)); // половина кормится на веернике
      else tv.copy(st.top).add(tv2.set(Math.cos(a) * sh.r, sh.h + Math.sin(t * 3 + sh.ph) * 0.15, Math.sin(a) * sh.r));
      tv3.copy(sh.p); sh.p.lerp(tv, Math.min(1, dt * 3));
      tv2.subVectors(sh.p, tv3); if (tv2.lengthSq() < 1e-8) tv2.set(Math.cos(a + 1.57), 0, Math.sin(a + 1.57));
      dummy.position.copy(sh.p); dummy.lookAt(tv3.copy(sh.p).add(tv2));
      dummy.scale.setScalar(1); dummy.updateMatrix(); E.shrimpIM.setMatrixAt(k, dummy.matrix);
    });
    E.shrimpIM.instanceMatrix.needsUpdate = true;
    if (E.fans.length && E.ognFanCd <= 0) {
      const st = E.stations.find(x => !x.busy && E.fanAt(x) && E.fanAt(x).p.distanceTo(G.Ship.center) < 30);
      if (st) { E.ognFanCd = 120; E.emit('fan', 'ognevka', E.fanAt(st).top, () => `${cap(G.nm('ognevka'))} кормятся на ${SP.fan.scanned ? 'веернике' : 'кружевном веере'}, пока станция пустует`); }
    }
    E.ognFanCd = (E.ognFanCd || 0) - dt;
  }

  /* ======================= ХВАТНИ И ПЕСТРЯНКИ ======================= */
  /* Хватень — анемон-засадчик у стай светляков. В темноте раскрывает щупальца,
     пестрянки подманивают стаю, хватень ловит неосторожную рыбу, пестрянки доедают остатки.
     В луче прожектора щупальца быстро прячутся. */
  const HV_TENT = 22, HV_PESTR = 3, HV_REACH = 1.9, BEAM_R = 45, BEAM_ANG = 0.5;
  const beamO = new V3(), beamD = new V3();
  function inBeam(p, fresh) {
    const S = G.Ship;
    if (fresh) updateBeam();
    if (!S.light || S.energy <= 0.5) return false;
    tv.copy(p).sub(beamO); const d = tv.length();
    if (d > BEAM_R * Math.sqrt(G.Power.k('lamp')) * (G.Silt.inside ? 0.45 : 1) || d < 0.01) return false; // луч длиннее при большей доле прожектора, в иле рассеивается
    return tv.dot(beamD) / d > Math.cos(BEAM_ANG);
  }
  E.inBeam = p => inBeam(p, true);
  function updateBeam() {
    const g = G.Ship.group;
    beamO.set(0, 0.8, -6.8); g.localToWorld(beamO);
    beamD.set(0, -10.8, -33.2).normalize().applyQuaternion(g.quaternion);
  }
  function tentGeo() {
    const g = new THREE.CylinderGeometry(0.015, 0.05, 1, 4, 3); g.translate(0, 0.5, 0);
    const p = g.attributes.position, col = new Float32Array(p.count * 3);
    for (let i = 0; i < p.count; i++) { const k = p.getY(i); col[i * 3] = 0.55 + k * 0.45; col[i * 3 + 1] = 0.25 + k * 0.6; col[i * 3 + 2] = 0.6 + k * 0.35; }
    g.setAttribute('color', new THREE.BufferAttribute(col, 3));
    return g;
  }
  function hvBodyGeo() {
    const col = new THREE.CylinderGeometry(0.32, 0.45, 0.8, 9); col.translate(0, 0.4, 0);
    const disc = new THREE.CylinderGeometry(0.4, 0.32, 0.08, 9); disc.translate(0, 0.82, 0);
    return G.merge([{ g: col, c: new THREE.Color(0.48, 0.22, 0.42) }, { g: disc, c: new THREE.Color(0.95, 0.55, 0.75) }]);
  }
  function initAnemones(scene) {
    const N = Math.min(4, E.shoals.length);
    if (!N) return;
    E.hvBodyIM = new THREE.InstancedMesh(hvBodyGeo(), new THREE.MeshLambertMaterial({ vertexColors: true, emissive: 0x2a0a24 }), N);
    E.hvTentIM = new THREE.InstancedMesh(tentGeo(), new THREE.MeshBasicMaterial({ vertexColors: true }), N * HV_TENT);
    const pg = new THREE.SphereGeometry(1, 6, 4); pg.scale(0.035, 0.05, 0.12);
    E.pestrIM = new THREE.InstancedMesh(pg, new THREE.MeshBasicMaterial({ color: 0xffffff }), N * HV_PESTR);
    [E.hvBodyIM, E.hvTentIM, E.pestrIM].forEach(m => { m.frustumCulled = false; scene.add(m); });
    const pc = [new THREE.Color(0xff7a2a), new THREE.Color(0xfff1d0), new THREE.Color(0xff9a4a)];
    for (let i = 0; i < N; i++) {
      const sh = E.shoals[i], a = i * 2.1 + 0.7;
      const base = new V3(sh.home.x + Math.cos(a) * 5, 0, sh.home.z + Math.sin(a) * 5); base.y = H(base.x, base.z);
      const top = base.clone().add(new V3(0, 0.85, 0));
      const hv = { i, base, top, mouth: top.clone().add(new V3(0, 0.7, 0)), open: 1, lit: false, digest: 0, lure: null, lureT: 0, lureCd: G.rr(4, 12), leftT: 0, hideCd: 0, msgCd: 0,
        tent: Array.from({ length: HV_TENT }, (_, k) => ({ a: k / HV_TENT * 6.283 + G.rr(-0.1, 0.1), tilt: G.rr(0.35, 1.0), len: G.rr(0.9, 1.4), ph: G.rr(0, 6) })),
        pestr: Array.from({ length: HV_PESTR }, (_, k) => ({ ph: k / HV_PESTR * 6.283, r: G.rr(0.3, 0.6), p: top.clone(), c: new V3() })), pc: new V3() };
      dummy.position.copy(base); dummy.rotation.set(0, a, 0); dummy.scale.setScalar(1); dummy.updateMatrix(); E.hvBodyIM.setMatrixAt(i, dummy.matrix);
      hv.pestr.forEach((p, k) => E.pestrIM.setColorAt(i * HV_PESTR + k, pc[k % pc.length]));
      E.anemones.push(hv);
    }
    E.hvBodyIM.instanceMatrix.needsUpdate = true;
    if (E.pestrIM.instanceColor) E.pestrIM.instanceColor.needsUpdate = true;
  }
  function anemoneUpdate(hv, dt, t) {
    hv.digest -= dt; hv.lureCd -= dt; hv.hideCd -= dt; hv.msgCd -= dt;
    const say = fn => (hv.msgCd > 0 ? null : fn); // не засорять ленту: у одного хватня — одна история за раз
    const wasLit = hv.lit; hv.lit = inBeam(hv.top);
    /* щупальца: в луче быстро прячутся, в темноте медленно раскрываются */
    const want = hv.lit ? 0 : hv.digest > 0 ? 0.5 : 1;
    hv.open = want < hv.open ? Math.max(want, hv.open - dt * 2.5) : Math.min(want, hv.open + dt * 0.35);
    if (hv.lit && !wasLit && hv.open > 0.5 && hv.hideCd <= 0) {
      hv.hideCd = 30;
      E.emit('hvaten', 'hide', hv.top, () => `${cap(G.nm('hvaten'))} прячет щупальца от прожектора`);
      E.emit('pestr', 'immune', hv.top, () => `${cap(G.nm('pestr'))} ныряет в сжатые щупальца ${G.nm('hvaten', 'gen')}`);
    }
    if (hv.lit) { if (hv.lure) hv.lure = null; }
    /* пестрянки подманивают ближайшую стаю */
    if (!hv.lure && hv.open > 0.85 && hv.digest <= 0 && hv.lureCd <= 0) {
      let best = null, bd = 30;
      for (const sh of E.shoals) { const d = sh.c.distanceTo(hv.top); if (sh.n >= 3 && !sh.follow && sh.alarm <= 0 && d < bd) { bd = d; best = sh; } }
      hv.lureCd = G.rr(25, 45);
      if (best) {
        hv.lure = best; hv.lureT = 14;
        E.emit('pestr', 'lure', hv.top, say(() => `${cap(G.nm('pestr'))} выманивает ${G.nm('fish', 'acc')} к щупальцам`));
      }
    }
    if (hv.lure) {
      const sh = hv.lure; hv.lureT -= dt;
      if (hv.lureT <= 0 || sh.follow || sh.alarm > 0) hv.lure = null;
      else { sh.goal.set(hv.top.x, hv.top.y + 1.1, hv.top.z); sh.gt = Math.max(sh.gt, 0.5); }
    }
    /* ловля: только раскрытые щупальца и только в темноте */
    if (hv.open > 0.7 && hv.digest <= 0) {
      for (const f of E.fish) {
        if (!f.alive) continue;
        const d = f.p.distanceTo(hv.mouth);
        if (d < HV_REACH * hv.open && G.rng() < dt * 1.5) {
          killFish(f); hv.digest = 35; hv.lure = null; hv.leftT = 3;
          E.emit('hvaten', 'catch', hv.mouth, say(() => `${cap(G.nm('hvaten'))} поймал ${G.nm('fish', 'acc')} щупальцами`));
          break;
        }
      }
    }
    if (hv.leftT > 0) { hv.leftT -= dt; if (hv.leftT <= 0) { E.emit('pestr', 'leftovers', hv.mouth, say(() => `${cap(G.nm('pestr'))} доедает остатки добычи ${G.nm('hvaten', 'gen')}`)); hv.msgCd = 90; } }
    /* отрисовка щупалец */
    const o = hv.open, base = hv.i * HV_TENT;
    hv.tent.forEach((tn, k) => {
      const sway = Math.sin(t * 1.4 + tn.ph) * 0.18 * o;
      dummy.position.set(hv.top.x + Math.cos(tn.a) * 0.3, hv.top.y, hv.top.z + Math.sin(tn.a) * 0.3);
      dummy.rotation.set(0, -tn.a, 0, 'YXZ');
      dummy.rotateZ(-(tn.tilt * (0.25 + 0.75 * o) + sway));
      const L = tn.len * (0.12 + 0.88 * o);
      dummy.scale.set(1 + (1 - o), L, 1 + (1 - o)); dummy.updateMatrix();
      E.hvTentIM.setMatrixAt(base + k, dummy.matrix);
    });
    /* пестрянки: среди щупалец, при подманивании выплывают к стае */
    hv.pc.set(0, 0, 0);
    hv.pestr.forEach((p, k) => {
      const a = t * (hv.lure ? 1.6 : 0.9) + p.ph;
      if (hv.lure) tv.copy(hv.top).lerp(hv.lure.c, 0.45 + Math.sin(t * 2 + p.ph) * 0.2).add(tv2.set(Math.cos(a) * 0.6, 0.3, Math.sin(a) * 0.6));
      else tv.set(hv.top.x + Math.cos(a) * p.r * (0.4 + 0.6 * o), hv.top.y + 0.25 + 0.35 * o + Math.sin(t * 2.3 + p.ph) * 0.08, hv.top.z + Math.sin(a) * p.r * (0.4 + 0.6 * o));
      tv3.copy(p.p); p.p.lerp(tv, Math.min(1, dt * 2.5)); hv.pc.add(p.p);
      tv2.subVectors(p.p, tv3); if (tv2.lengthSq() < 1e-8) tv2.set(-Math.sin(a), 0, Math.cos(a));
      dummy.position.copy(p.p); dummy.lookAt(tv3.copy(p.p).add(tv2)); dummy.rotation.z += Math.sin(t * 9 + p.ph) * 0.2;
      dummy.scale.setScalar(1); dummy.updateMatrix(); E.pestrIM.setMatrixAt(hv.i * HV_PESTR + k, dummy.matrix);
    });
    hv.pc.divideScalar(HV_PESTR);
  }

  /* ======================= ЛЕНТОЧНИК, ШИПОЕЖИ И КОЛЬЧУЖНИК ======================= */
  /* Заросли ленточника у двух стай: напуганные светляки прячутся в них, и хищник их теряет.
     Шипоежи объедают ленточник до голых стеблей — тогда стае негде спрятаться.
     Кольчужник сидит в норе у второй рощи, раскалывает ежей и носит их иглы на панцире. Нору охраняет. */
  const KELP_N = 34, KELP_R = 7, URCH_N = 7, COVER_MIN = 0.45, CRAB_R = 16, SPINE_MAX = 10;
  function spineGeo(n, len, base, tip, r0) {
    const parts = [{ g: new THREE.IcosahedronGeometry(r0, 0), c: base }];
    for (let k = 0; k < n; k++) {
      const y = 1 - (k + 0.5) / n * 1.2, rr = Math.sqrt(Math.max(0, 1 - y * y)), a = k * 2.39996;
      const dir = new V3(Math.cos(a) * rr, Math.max(y, -0.15), Math.sin(a) * rr).normalize();
      const q = new THREE.Quaternion().setFromUnitVectors(new V3(0, 1, 0), dir);
      const c = new THREE.ConeGeometry(0.02, len, 4); c.translate(0, len / 2 + r0 * 0.8, 0);
      parts.push({ g: c, m: new THREE.Matrix4().makeRotationFromQuaternion(q), c: base });
      const tp = new THREE.OctahedronGeometry(0.03, 0); tp.translate(0, len + r0 * 0.8, 0);
      parts.push({ g: tp, m: new THREE.Matrix4().makeRotationFromQuaternion(q), c: tip });
    }
    return G.merge(parts);
  }
  function setKelp(gr, k) {
    const s = gr.stalks[k], f = s.f;
    dummy.position.copy(s.p); dummy.rotation.set(s.tx, s.yaw, s.tz);
    dummy.scale.set(0.12 + 0.88 * f, s.h * (0.35 + 0.65 * f), 1); dummy.updateMatrix();
    E.kelpIM.setMatrixAt(gr.i * KELP_N + k, dummy.matrix);
    E.kelpIM.setColorAt(gr.i * KELP_N + k, tv3.set(0, 0, 0).lerpVectors(gr.bare, s.col, f));
  }
  function initKelp(scene) {
    const G2 = Math.min(2, Math.max(0, E.shoals.length - 1));
    if (!G2) return;
    const kg = new THREE.PlaneGeometry(0.45, 1, 1, 7); kg.translate(0, 0.5, 0);
    E.kelpIM = new THREE.InstancedMesh(kg, G.sway(new THREE.MeshLambertMaterial({ color: 0xffffff, side: THREE.DoubleSide, emissive: 0x0b1a10 }), 0.9), G2 * KELP_N);
    E.urchBodyIM = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(0.2, 1), new THREE.MeshLambertMaterial({ color: 0x3a1f4a, emissive: 0x12061a }), G2 * URCH_N);
    E.urchSpIM = new THREE.InstancedMesh(spineGeo(18, 0.32, new THREE.Color(0.25, 0.12, 0.35), new THREE.Color(0.55, 0.95, 1), 0.18), new THREE.MeshBasicMaterial({ vertexColors: true }), G2 * URCH_N);
    [E.kelpIM, E.urchBodyIM, E.urchSpIM].forEach(m => { m.frustumCulled = false; scene.add(m); });
    const pal = [0x5f9a4a, 0x8aa83c, 0x3f8f7a].map(c => new THREE.Color(c));
    for (let gi = 0; gi < G2; gi++) {
      const sh = E.shoals[gi + 1], c = new V3(sh.home.x, 0, sh.home.z); c.y = H(c.x, c.z);
      const gr = { i: gi, c, sh, cover: 1, msgCd: 0, grazeCd: 0, bare: new V3(0.32, 0.26, 0.16), stalks: [] };
      for (let k = 0; k < KELP_N; k++) {
        const a = k * 2.39996, r = Math.sqrt((k + 0.5) / KELP_N) * KELP_R;
        const p = new V3(c.x + Math.cos(a) * r, 0, c.z + Math.sin(a) * r); p.y = H(p.x, p.z) - 0.1;
        const col = G.pick(pal);
        gr.stalks.push({ p, h: G.rr(3, 5.5), f: 1, tx: G.rr(-0.08, 0.08), tz: G.rr(-0.08, 0.08), yaw: G.rr(0, 6.283), col: new V3(col.r, col.g, col.b), eater: null, drawn: 1 });
        setKelp(gr, k);
      }
      E.groves.push(gr);
      for (let k = 0; k < URCH_N; k++) {
        const u = { i: gi * URCH_N + k, gr, alive: true, t: 0, p: new V3(), goal: null, wander: new V3(), wt: 0, grazeCd: 0, ph: G.rr(0, 6) };
        urchSpawn(u); E.urchins.push(u);
      }
    }
    E.kelpIM.instanceMatrix.needsUpdate = true; E.kelpIM.instanceColor.needsUpdate = true;
    /* кольчужник: нора у края второй рощи */
    const gr = E.groves[G2 - 1], out = new V3(1, 0, 0.4).normalize();
    const den = gr.c.clone().addScaledVector(out, KELP_R + 3); den.y = H(den.x, den.z);
    const rocks = [];
    [[-1.3, 0.3, -0.4], [1.3, 0.3, -0.4], [0, 0.8, -1.1], [-0.6, 1.3, -0.9], [0.7, 0.2, -1.6]].forEach(([x, y, z]) => {
      const g = new THREE.DodecahedronGeometry(G.rr(0.8, 1.1), 0); g.scale(1, 0.6, 1);
      rocks.push({ g, m: new THREE.Matrix4().makeTranslation(x, y, z), c: new THREE.Color(0x4f4a5c) });
    });
    const denM = new THREE.Mesh(G.merge(rocks), new THREE.MeshLambertMaterial({ vertexColors: true, flatShading: true }));
    denM.position.copy(den); denM.lookAt(den.x + out.x, den.y, den.z + out.z); scene.add(denM);
    const legs = [{ g: new THREE.SphereGeometry(1, 10, 6), m: new THREE.Matrix4().makeScale(0.55, 0.22, 0.42).setPosition(0, 0.35, 0), c: new THREE.Color(0x8a4a2e) }];
    [-1, 1].forEach(sx => [-0.25, 0, 0.25].forEach(z => {
      const lg = new THREE.BoxGeometry(0.55, 0.05, 0.06); lg.translate(0.27, 0, 0);
      const m = new THREE.Matrix4().makeRotationY(sx > 0 ? -z * 1.5 : Math.PI + z * 1.5).multiply(new THREE.Matrix4().makeRotationZ(-0.5));
      m.setPosition(sx * 0.4, 0.33, z); legs.push({ g: lg, m, c: new THREE.Color(0x6a3a26) });
    }));
    const body = new THREE.Mesh(G.merge(legs), new THREE.MeshLambertMaterial({ vertexColors: true, emissive: 0x1a0804 }));
    const cl = [];
    [-1, 1].forEach(sx => {
      const arm = new THREE.BoxGeometry(0.08, 0.08, 0.4); arm.translate(sx * 0.22, 0, 0.2);
      const pin = new THREE.SphereGeometry(1, 8, 5); pin.scale(0.11, 0.08, 0.2); pin.translate(sx * 0.24, 0, 0.5);
      cl.push({ g: arm, c: new THREE.Color(0x7a4028) }, { g: pin, c: new THREE.Color(0xc06a3a) });
    });
    const claws = new THREE.Mesh(G.merge(cl), body.material); claws.position.set(0, 0.35, 0.3); body.add(claws);
    const spIM = new THREE.InstancedMesh((() => { const c = new THREE.ConeGeometry(0.025, 0.3, 4); c.translate(0, 0.15, 0); const tp = new THREE.OctahedronGeometry(0.03, 0); tp.translate(0, 0.3, 0); return G.merge([{ g: c, c: new THREE.Color(0.3, 0.15, 0.4) }, { g: tp, c: new THREE.Color(0.55, 0.95, 1) }]); })(), E.urchSpIM.material, SPINE_MAX);
    spIM.frustumCulled = false; body.add(spIM);
    const spines = Array.from({ length: SPINE_MAX }, (_, k) => {
      const a = k / SPINE_MAX * 6.283 + 0.3;
      dummy.position.set(Math.cos(a) * 0.38, 0.45, Math.sin(a) * 0.3); dummy.rotation.set(Math.sin(a) * 0.9, 0, -Math.cos(a) * 0.9); dummy.scale.setScalar(1); dummy.updateMatrix();
      return dummy.matrix.clone();
    });
    body.scale.setScalar(1.25); scene.add(body);
    E.crab = { den, out, body, claws, spIM, spineM: spines, p: den.clone(), dir: out.clone(), state: 'den', hunger: 0.3, target: null, timer: 0, spines: 3, guardCd: 0, pinchCd: 0, raise: 0, gr };
    crabSpines(E.crab);
  }
  function urchSpawn(u) {
    const gr = u.gr, a = G.rr(0, 6.283), r = G.rr(KELP_R * 0.6, KELP_R + 2);
    u.p.set(gr.c.x + Math.cos(a) * r, 0, gr.c.z + Math.sin(a) * r); u.p.y = H(u.p.x, u.p.z) + 0.15;
    u.alive = true; u.goal = null; u.wt = 0; u.grazeCd = 0;
  }
  function crabSpines(cr) {
    for (let k = 0; k < SPINE_MAX; k++) {
      if (k < cr.spines) cr.spIM.setMatrixAt(k, cr.spineM[k]);
      else { dummy.position.set(0, 0, 0); dummy.scale.setScalar(0.0001); dummy.rotation.set(0, 0, 0); dummy.updateMatrix(); cr.spIM.setMatrixAt(k, dummy.matrix); }
    }
    cr.spIM.instanceMatrix.needsUpdate = true;
  }
  /* роща, в которой прячется светляк, если ленточник ещё цел */
  function kelpShelter(f) {
    if (!(f.s.alarm > 0)) return null;
    for (const gr of E.groves) {
      if (gr.sh !== f.s || gr.cover < COVER_MIN) continue;
      if (Math.hypot(f.p.x - gr.c.x, f.p.z - gr.c.z) < KELP_R + 1 && f.p.y < gr.c.y + 5) return gr;
    }
    return null;
  }
  E.kelpShelter = kelpShelter;
  function groveOf(p) { return E.groves.find(gr => Math.hypot(p.x - gr.c.x, p.z - gr.c.z) < KELP_R + 1.5); }
  function urchinUpdate(u, dt, t) {
    if (!u.alive) { u.t -= dt; if (u.t <= 0) urchSpawn(u); return; }
    const gr = u.gr; u.grazeCd -= dt;
    if (u.goal && u.goal.f <= 0.15) { u.goal.eater = null; u.goal = null; }
    if (!u.goal) {
      let best = null, bd = 1e9;
      for (const s of gr.stalks) { if (s.f <= 0.3 || (s.eater && s.eater !== u)) continue; const d = s.p.distanceToSquared(u.p); if (d < bd) { bd = d; best = s; } }
      if (best) { u.goal = best; best.eater = u; }
    }
    let speed = 0.3;
    if (u.goal) tv.copy(u.goal.p);
    else { u.wt -= dt; if (u.wt <= 0) { u.wt = G.rr(6, 12); u.wander.set(gr.c.x + G.rr(-KELP_R, KELP_R), 0, gr.c.z + G.rr(-KELP_R, KELP_R)); } tv.copy(u.wander); speed = 0.15; }
    tv.sub(u.p).setY(0); const d = tv.length();
    if (u.goal && d < 0.45) {
      u.goal.f = Math.max(0.15, u.goal.f - dt * 0.035);
      if (u.grazeCd <= 0) { u.grazeCd = 60; const say = gr.grazeCd <= 0; if (say) gr.grazeCd = 90; E.emit('ezh', 'graze', u.p, say ? () => `${cap(G.nm('ezh'))} объедает ленточник до стеблей` : null); }
    } else if (d > 0.05) u.p.addScaledVector(tv, Math.min(d, speed * dt) / d);
    u.p.y = H(u.p.x, u.p.z) + 0.15;
  }
  function urchinRender(u, t) {
    if (u.alive) { dummy.position.copy(u.p); dummy.rotation.set(0, t * 0.1 + u.ph, 0); dummy.scale.setScalar(1 + Math.sin(t * 1.5 + u.ph) * 0.04); }
    else { dummy.position.set(0, -999, 0); dummy.scale.setScalar(0.001); }
    dummy.updateMatrix(); E.urchBodyIM.setMatrixAt(u.i, dummy.matrix); E.urchSpIM.setMatrixAt(u.i, dummy.matrix);
  }
  function crabUpdate(cr, dt, t) {
    const S = G.Ship;
    cr.hunger = Math.min(1.5, cr.hunger + dt / 30); cr.timer -= dt; cr.guardCd -= dt; cr.pinchCd -= dt;
    const dShip = S.center.distanceTo(cr.den);
    let speed = 0, goal = null, raise = 0;
    if (dShip < 12 && S.hull > 0 && cr.state !== 'crack') {
      if (cr.state === 'hunt' && cr.target) cr.target = null;
      cr.state = 'guard';
    }
    switch (cr.state) {
      case 'den':
        if (cr.hunger > 1 && !(cr.scared > 0)) {
          let best = null, bd = CRAB_R;
          for (const u of E.urchins) { if (!u.alive) continue; const d = u.p.distanceTo(cr.den); if (d < bd) { bd = d; best = u; } }
          if (best) { cr.state = 'hunt'; cr.target = best; cr.timer = 60; }
        }
        break;
      case 'hunt': {
        const u = cr.target;
        if (!u || !u.alive || cr.timer <= 0) { cr.state = 'home'; cr.target = null; break; }
        goal = u.p; speed = 0.9;
        if (cr.p.distanceTo(u.p) < 0.7) { cr.state = 'crack'; cr.timer = 3; }
        break;
      }
      case 'crack': {
        raise = 0.6 + Math.sin(t * 14) * 0.3;
        const u = cr.target;
        if (cr.timer <= 0) {
          if (u && u.alive) {
            u.alive = false; u.t = G.rr(80, 120); if (u.goal) { u.goal.eater = null; u.goal = null; }
            cr.hunger = 0; cr.spines = Math.min(SPINE_MAX, cr.spines + 2); crabSpines(cr);
            E.emit('krab', 'hunt', cr.p, () => `${cap(G.nm('krab'))} расколол ${G.nm('ezh', 'acc')}`);
            E.emit('krab', 'armor', cr.p, () => `${cap(G.nm('krab'))} вплетает иглы ${G.nm('ezh', 'gen')} в панцирь`);
          }
          cr.state = 'home'; cr.target = null;
        }
        break;
      }
      case 'home':
        goal = cr.den; speed = cr.scared > 0 ? 2 : 0.8; // напуганный скальником краб удирает бегом
        if (cr.p.distanceTo(cr.den) < 0.4) { cr.state = 'den'; cr.dir.copy(cr.out); }
        break;
      case 'guard':
        raise = 1; goal = cr.p.distanceTo(cr.den) > 0.4 ? cr.den : null; speed = 1.2;
        tv2.copy(S.center).sub(cr.p).setY(0); if (tv2.lengthSq() > 0.01) cr.dir.lerp(tv2.normalize(), Math.min(1, dt * 3)).normalize();
        if (cr.guardCd <= 0) { cr.guardCd = 40; E.emit('krab', 'guard', cr.p, () => `${cap(G.nm('krab'))} поднял клешни: корабль слишком близко к норе`); }
        if (dShip < 7 && cr.pinchCd <= 0) {
          cr.pinchCd = 8; G.Game.hullHit(3, 'pinch');
          E.emit('krab', 'guard', cr.p, () => `${cap(G.nm('krab'))} зажал корпус клешнёй`);
        }
        if (dShip > 14) cr.state = 'home';
        break;
    }
    if (goal) {
      tv.copy(goal).sub(cr.p).setY(0); const d = tv.length();
      if (d > 0.05) { cr.p.addScaledVector(tv, Math.min(d, speed * dt) / d); if (cr.state !== 'guard') cr.dir.lerp(tv.normalize(), Math.min(1, dt * 4)).normalize(); }
    }
    cr.p.y = H(cr.p.x, cr.p.z);
    cr.raise += (raise - cr.raise) * Math.min(1, dt * 5);
    cr.body.position.copy(cr.p); cr.body.position.y += Math.abs(Math.sin(t * 8)) * 0.03 * (goal ? 1 : 0);
    cr.body.rotation.set(0, Math.atan2(cr.dir.x, cr.dir.z), 0);
    cr.claws.rotation.x = -cr.raise * 0.9;
  }
  function kelpUpdate(dt) {
    let dirty = false;
    for (const gr of E.groves) {
      let sum = 0; gr.msgCd -= dt; gr.grazeCd -= dt;
      gr.stalks.forEach((s, k) => {
        if (!s.eater) s.f = Math.min(1, s.f + dt * 0.005); // объеденный ленточник медленно отрастает
        if (Math.abs(s.f - s.drawn) > 0.01) { s.drawn = s.f; setKelp(gr, k); dirty = true; }
        sum += s.f;
      });
      gr.cover = (sum / KELP_N - 0.15) / 0.85;
    }
    if (dirty) { E.kelpIM.instanceMatrix.needsUpdate = true; E.kelpIM.instanceColor.needsUpdate = true; }
  }

  /* ======================= РАДУЖНИКИ ======================= */
  /* Стаи гребневиков в толще воды. Своего света нет: в луче прожектора стая вспыхивает радугой,
     и серпохвосты видят корабль издалека. Погасишь прожектор — стая гаснет. */
  const RD_N = 28, RD_R = 4, FLARE_REACH = 110;
  const rdCol = new THREE.Color(), rdColT = new THREE.Color();
  function glowTex() { // мягкое круглое пятно для ореола вспышки
    const cv = document.createElement('canvas'); cv.width = cv.height = 32;
    const c = cv.getContext('2d'), gr = c.createRadialGradient(16, 16, 0, 16, 16, 16);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.35, 'rgba(255,255,255,0.45)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    c.fillStyle = gr; c.fillRect(0, 0, 32, 32);
    return new THREE.CanvasTexture(cv);
  }
  function initSwarms(scene) {
    const rng0 = G.rng; G.seed(7031); // своё зерно: новый вид не перетасовывает остальной мир
    const g = new THREE.SphereGeometry(1, 7, 5); g.scale(0.16, 0.24, 0.16);
    E.rdIM = new THREE.InstancedMesh(g, new THREE.MeshBasicMaterial({ transparent: true, opacity: 0.85, blending: THREE.AdditiveBlending, depthWrite: false }), 3 * RD_N);
    const pa = new Float32Array(3 * RD_N * 3), pc = new Float32Array(3 * RD_N * 3), pg = new THREE.BufferGeometry();
    pg.setAttribute('position', new THREE.BufferAttribute(pa, 3)); pg.setAttribute('color', new THREE.BufferAttribute(pc, 3));
    E.rdGlow = new THREE.Points(pg, new THREE.PointsMaterial({ size: 1.1, map: glowTex(), vertexColors: true, transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false }));
    for (let j = 0; j < 3 * RD_N; j++) E.rdIM.setColorAt(j, rdColT.setRGB(0.05, 0.06, 0.08));
    [E.rdIM, E.rdGlow].forEach(m => { m.frustumCulled = false; scene.add(m); });
    [[-25, 40], [45, 0], [-70, -50]].forEach(([x, z], i) => {
      const home = new V3(x, 0, z); home.y = Math.min(H(x, z) + 9, -8);
      const sw = { i, home, c: home.clone(), glow: 0, lit: false, flareCd: 0, fadeCd: 0, ph: G.rr(0, 6), m: [] };
      for (let k = 0; k < RD_N; k++) sw.m.push({ o: new V3(G.rr(-1, 1), G.rr(-0.6, 0.6), G.rr(-1, 1)).normalize().multiplyScalar(RD_R * Math.cbrt(G.rng())), ph: G.rr(0, 6.283), hue: G.rng(), p: new V3() });
      E.swarms.push(sw);
    });
    G.rng = rng0;
  }
  function swarmUpdate(sw, dt, t) {
    const S = G.Ship;
    sw.flareCd -= dt; sw.fadeCd -= dt;
    sw.c.set(sw.home.x + Math.sin(t * 0.05 + sw.ph) * 10, sw.home.y + Math.sin(t * 0.21 + sw.ph) * 1.2, sw.home.z + Math.cos(t * 0.04 + sw.ph * 1.3) * 10);
    const wasLit = sw.lit; sw.lit = false;
    const near = S.center.distanceTo(sw.c) < RD_R + 26;
    for (let k = 0; k < RD_N; k++) {
      const m = sw.m[k];
      m.p.copy(sw.c).add(m.o); m.p.x += Math.sin(t * 0.6 + m.ph) * 0.5; m.p.y += Math.sin(t * 0.8 + m.ph * 1.7) * 0.4;
      if (near) S.pushOut(m.p, 0.3);
      if (!sw.lit && k % 3 === 0 && inBeam(m.p)) sw.lit = true;
    }
    const prev = sw.glow;
    sw.glow = sw.lit ? Math.min(1, sw.glow + dt * 3) : Math.max(0, sw.glow - dt * 0.6);
    if (sw.lit && !wasLit && sw.flareCd <= 0) { sw.flareCd = 30; E.emit('raduzh', 'flare', sw.c, () => `Стая ${G.nm('raduzh', 'gen')} вспыхивает радугой в луче прожектора — корабль видно издалека`); }
    if (prev > 0.5 && sw.glow <= 0.5 && !S.light && sw.fadeCd <= 0 && S.center.distanceTo(sw.c) < 60) { sw.fadeCd = 60; E.emit('raduzh', 'fade', sw.c, () => `Прожектор погашен — стая ${G.nm('raduzh', 'gen')} гаснет`); }
  }
  function swarmRender(sw, t) {
    const pa = E.rdGlow.geometry.attributes.position.array, pc = E.rdGlow.geometry.attributes.color.array, g = sw.glow, gg = g * g;
    for (let k = 0; k < RD_N; k++) {
      const m = sw.m[k], j = sw.i * RD_N + k;
      dummy.position.copy(m.p); dummy.rotation.set(Math.sin(t * 0.7 + m.ph) * 0.4, m.ph, 0);
      dummy.scale.setScalar(1 + Math.sin(t * 2.4 + m.ph) * 0.08); dummy.updateMatrix(); E.rdIM.setMatrixAt(j, dummy.matrix);
      /* без света — едва заметный голубоватый силуэт, в луче — бегущая по ресничкам радуга */
      const base = 0.07 + 0.05 * Math.max(0, Math.sin(t * 0.9 + m.ph));
      rdCol.setHSL((m.hue + t * 0.35) % 1, 1, 0.55);
      rdColT.setRGB(G.lerp(base * 0.7, rdCol.r, g), G.lerp(base * 0.9, rdCol.g, g), G.lerp(base * 1.2, rdCol.b, g));
      E.rdIM.setColorAt(j, rdColT);
      pa[j * 3] = m.p.x; pa[j * 3 + 1] = m.p.y; pa[j * 3 + 2] = m.p.z;
      const q = gg * 0.7; pc[j * 3] = rdColT.r * q; pc[j * 3 + 1] = rdColT.g * q; pc[j * 3 + 2] = rdColT.b * q;
    }
  }

  /* ======================= МЕРЦАЮЩИЙ ПЛАНКТОН ======================= */
  /* Облака светящихся одноклеточных. Вспыхивают, когда сквозь них быстро проходит корабль,
     хищник или ледокрыл; след гаснет за пару секунд. След корабля виден хищникам даже без прожектора. */
  const PL_N = 360, PL_R = 12, WAKE_SPEED = 2.2, WAKE_R = 2.6, PRED_FAST = 5;
  const plSeg = new V3(), plCol = new THREE.Color();
  function initClouds(scene) {
    const rng0 = G.rng; G.seed(9157);
    const spots = [[8, 72], [-60, 0], [60, -60], [-20, -140]], N = spots.length * PL_N;
    const pa = new Float32Array(N * 3), pc = new Float32Array(N * 3), pg = new THREE.BufferGeometry();
    pg.setAttribute('position', new THREE.BufferAttribute(pa, 3)); pg.setAttribute('color', new THREE.BufferAttribute(pc, 3));
    E.plPts = new THREE.Points(pg, new THREE.PointsMaterial({ size: 0.8, map: glowTex(), vertexColors: true, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    E.plPts.frustumCulled = false; scene.add(E.plPts);
    spots.forEach(([x, z], i) => {
      const home = new V3(x, 0, z); home.y = Math.min(H(x, z) + 10, -10);
      const cl = { i, home, c: home.clone(), ph: G.rr(0, 6), o: new Float32Array(PL_N * 3), glow: new Float32Array(PL_N), by: new Uint8Array(PL_N), ship: 0, slowT: 0, wakeCd: 0, slowCd: 0, predCd: 0 };
      for (let k = 0; k < PL_N; k++) {
        const v = new V3(G.rr(-1, 1), G.rr(-0.5, 0.5), G.rr(-1, 1)); if (v.lengthSq() > 1) v.normalize();
        v.multiplyScalar(PL_R * Math.cbrt(G.rng())); cl.o[k * 3] = v.x; cl.o[k * 3 + 1] = v.y; cl.o[k * 3 + 2] = v.z;
      }
      E.clouds.push(cl);
    });
    G.rng = rng0;
  }
  /* квадрат расстояния от точки до отрезка a–b */
  function segD2(x, y, z, a, b) {
    plSeg.subVectors(b, a); const L2 = plSeg.lengthSq();
    let u = L2 > 0 ? ((x - a.x) * plSeg.x + (y - a.y) * plSeg.y + (z - a.z) * plSeg.z) / L2 : 0; u = Math.max(0, Math.min(1, u));
    const dx = x - a.x - plSeg.x * u, dy = y - a.y - plSeg.y * u, dz = z - a.z - plSeg.z * u;
    return dx * dx + dy * dy + dz * dz;
  }
  const shipBack = new V3(), plP = new V3();
  function cloudUpdate(cl, dt, t) {
    const S = G.Ship, pa = E.plPts.geometry.attributes.position.array, pc = E.plPts.geometry.attributes.color.array;
    cl.wakeCd -= dt; cl.slowCd -= dt; cl.predCd -= dt;
    cl.c.set(cl.home.x + Math.sin(t * 0.03 + cl.ph) * 6, cl.home.y + Math.sin(t * 0.17 + cl.ph) * 1, cl.home.z + Math.cos(t * 0.025 + cl.ph) * 6);
    /* кто сейчас «режет» облако: корабль, если быстрый; хищники в броске; ледокрылы */
    const cutters = [];
    const shipIn = S.center.distanceTo(cl.c) < PL_R + 8;
    if (shipIn && Math.abs(S.speed) > WAKE_SPEED) { shipBack.set(0, 1.5, 12).applyMatrix4(S.group.matrixWorld); cutters.push({ a: S.front, b: shipBack, r2: WAKE_R * WAKE_R, who: 1 }); }
    for (const pr of E.preds) if (pr.v.length() > PRED_FAST && pr.p.distanceTo(cl.c) < PL_R + 4) cutters.push({ a: pr.p, b: pr.segs[pr.segs.length - 1], r2: 4, who: 2 });
    for (const ry of E.rays) if (ry.p.distanceTo(cl.c) < PL_R + 8) cutters.push({ a: ry.p.clone().addScaledVector(ry.dir, 3), b: ry.p.clone().addScaledVector(ry.dir, -4), r2: 36, who: 3 });
    let lit = 0, predLit = 0;
    const hullNear = S.center.distanceTo(cl.c) < PL_R + 24;
    const base = cl.i * PL_N;
    for (let k = 0; k < PL_N; k++) {
      const j = (base + k) * 3, w = t * 0.3 + k;
      let x = cl.c.x + cl.o[k * 3] + Math.sin(w) * 0.4, y = cl.c.y + cl.o[k * 3 + 1] + Math.sin(w * 1.3) * 0.25, z = cl.c.z + cl.o[k * 3 + 2] + Math.cos(w * 0.9) * 0.4;
      if (hullNear && S.pushOut(plP.set(x, y, z), 0.2)) { x = plP.x; y = plP.y; z = plP.z; } // корабль раздвигает облако
      pa[j] = x; pa[j + 1] = y; pa[j + 2] = z;
      for (const cu of cutters) if (segD2(x, y, z, cu.a, cu.b) < cu.r2) { cl.glow[k] = 1; cl.by[k] = cu.who; break; }
      let g = cl.glow[k];
      if (g > 0) { g = Math.max(0, g - dt * 0.45); cl.glow[k] = g; if (g > 0.4) { if (cl.by[k] === 1) lit++; else if (cl.by[k] === 2) predLit++; } }
      const b = 0.05 + 0.03 * Math.sin(t * 1.1 + k * 1.7);
      pc[j] = b * 0.4 + g * 0.35; pc[j + 1] = b + g * 1.0; pc[j + 2] = b * 1.1 + g * 0.85;
    }
    cl.ship = Math.min(1, lit / 25);
    if (cl.ship > 0.5 && cl.wakeCd <= 0) { cl.wakeCd = 40; E.emit('plankton', 'wake', S.center, () => `${cap(G.nm('plankton'))} вспыхивает: за кораблём тянется светящийся след`); }
    if (predLit > 8 && cl.predCd <= 0) { cl.predCd = 40; E.emit('plankton', 'pred', cl.c, () => `Бросок ${G.nm('pred', 'gen')} сквозь ${G.nm('plankton', 'acc')} видно издалека`); }
    /* медленно сквозь облако — без следа */
    if (S.center.distanceTo(cl.c) < PL_R && Math.abs(S.speed) > 0.3 && Math.abs(S.speed) <= WAKE_SPEED && lit === 0) cl.slowT += dt; else cl.slowT = 0;
    if (cl.slowT > 4 && cl.slowCd <= 0) { cl.slowCd = 60; E.emit('plankton', 'slow', S.center, () => `Корабль идёт медленно — ${G.nm('plankton')} не вспыхивает`); }
  }

  /* ======================= МОНЕТНИКИ И ПЕСЧАНЫЕ ГЛАЗУНЫ ======================= */
  /* Стайки монетников пасутся на пятнах мха. Рядом в песке лежат глазуны: на сонаре их нет,
     видно только глаза. Монетник, проплывший над глазуном, пропадает. От импульса сонара стайка
     рассыпается прочь от ближайшей угрозы — даже от невидимого глазуна. */
  const CN_PER = 9, GZ_REACH = 1.5, SCATTER_R = 70;
  function initCoins(scene) {
    const P = G.World.patches; if (!P.length) return;
    const rng0 = G.rng; G.seed(4421);
    const S0 = G.Ship.start, picks = [];
    P.slice().sort((a, b) => Math.hypot(a.x - S0.x, a.z - S0.z) - Math.hypot(b.x - S0.x, b.z - S0.z))
      .forEach(pt => { if (picks.length < 3 && picks.every(q => Math.hypot(q.x - pt.x, q.z - pt.z) > 25)) picks.push(pt); });
    const cg = new THREE.CylinderGeometry(0.15, 0.15, 0.035, 12); cg.rotateZ(Math.PI / 2); // диск боком: плоская круглая рыбка
    const fin = new THREE.ConeGeometry(0.06, 0.12, 4); fin.rotateX(-Math.PI / 2); fin.translate(0, 0, -0.18);
    E.coinIM = new THREE.InstancedMesh(G.merge([{ g: cg, c: new THREE.Color(0xe8d48a) }, { g: fin, c: new THREE.Color(0xb59a50) }]), new THREE.MeshLambertMaterial({ vertexColors: true, emissive: 0x3a3010 }), picks.length * CN_PER);
    const bg = new THREE.SphereGeometry(1, 10, 6); bg.scale(0.45, 0.08, 0.3);
    const stalk = new THREE.CylinderGeometry(0.012, 0.016, 0.12, 4);
    const parts = [{ g: bg, c: new THREE.Color(0x8a7a60) }];
    [-1, 1].forEach(sx => { const st = stalk.clone(); st.translate(sx * 0.07, 0.08, 0.16); parts.push({ g: st, c: new THREE.Color(0x6a5a44) }); });
    E.glzBodyIM = new THREE.InstancedMesh(G.merge(parts), new THREE.MeshLambertMaterial({ vertexColors: true }), picks.length);
    E.glzEyeIM = new THREE.InstancedMesh(new THREE.SphereGeometry(0.045, 6, 4), new THREE.MeshBasicMaterial({ color: 0xffffff }), picks.length * 2);
    [E.coinIM, E.glzBodyIM, E.glzEyeIM].forEach(m => { m.frustumCulled = false; scene.add(m); });
    picks.forEach((pt, i) => {
      const c = new V3(pt.x, H(pt.x, pt.z), pt.z);
      const sc = { i, pt, c, scatter: 0, from: new V3(), grazeCd: G.rr(5, 15), scatCd: 0, members: [] };
      const a = G.rr(0, 6.28), gp = new V3(c.x + Math.cos(a) * 2.2, 0, c.z + Math.sin(a) * 2.2); gp.y = H(gp.x, gp.z);
      const gz = { i, p: gp, yaw: G.rr(0, 6.28), sc, cd: G.rr(8, 20), lunge: 0, lit: false, eyesCd: 0, eye: [new V3(), new V3()], eyeC: new V3() };
      sc.gz = gz;
      for (let k = 0; k < CN_PER; k++) {
        const cn = { s: sc, i: i * CN_PER + k, alive: true, t: 0, p: new V3(), v: new V3(), goal: new V3(), gt: 0, ph: G.rr(0, 6.28) };
        coinSpawn(cn); sc.members.push(cn); E.coins.push(cn);
      }
      E.schools.push(sc);
      dummy.position.copy(gp); dummy.rotation.set(0, gz.yaw, 0); dummy.scale.setScalar(1); dummy.updateMatrix();
      E.glzBodyIM.setMatrixAt(i, dummy.matrix);
      [-1, 1].forEach((sx, k) => { gz.eye[k].set(sx * 0.07, 0.15, 0.16).applyMatrix4(dummy.matrix); });
      gz.eyeC.addVectors(gz.eye[0], gz.eye[1]).multiplyScalar(0.5);
      E.glazuns.push(gz);
      for (let k = 0; k < 2; k++) E.glzEyeIM.setColorAt(i * 2 + k, rdColT.setRGB(0.55, 0.6, 0.25));
    });
    E.glzBodyIM.instanceMatrix.needsUpdate = true;
    G.rng = rng0;
  }
  /* монетник появляется над мхом, но не прямо над глазуном */
  function coinSpawn(cn) {
    const sc = cn.s, gz = sc.gz;
    for (let k = 0; k < 10; k++) {
      cn.p.set(sc.c.x + G.rr(-2.5, 2.5), sc.c.y + G.rr(0.6, 1.4), sc.c.z + G.rr(-2.5, 2.5));
      if (!gz || Math.hypot(cn.p.x - gz.p.x, cn.p.z - gz.p.z) > GZ_REACH + 0.8) break;
    }
    cn.alive = true; cn.t = 0; cn.v.set(0, 0, 0); cn.gt = 0; cn.goal.copy(cn.p);
  }
  function coinsUpdate(dt, t) {
    for (const sc of E.schools) {
      sc.scatter -= dt; sc.grazeCd -= dt; sc.scatCd -= dt;
      if (sc.scatter <= 0 && sc.grazeCd <= 0 && sc.pt.food > 0.2 && sc.members.some(c => c.alive)) {
        sc.grazeCd = 60; E.emit('monet', 'graze', sc.c, () => `Стайка ${G.nm('monet', 'gen')} пасётся на светящемся мху`);
      }
      if (sc.scatter <= 0) sc.pt.food = Math.max(0, sc.pt.food - dt * 0.002);
    }
    for (const cn of E.coins) {
      const sc = cn.s;
      if (!cn.alive) { cn.t -= dt; if (cn.t <= 0) coinSpawn(cn); else continue; }
      let maxS = 0.8;
      if (sc.scatter > 0) { // бегство прочь от угрозы
        tv.copy(cn.p).sub(sc.from).setY(0); if (tv.lengthSq() < 0.01) tv.set(Math.cos(cn.ph), 0, Math.sin(cn.ph));
        cn.goal.copy(cn.p).addScaledVector(tv.normalize(), 6); cn.goal.y = sc.c.y + 1.5; maxS = 5;
      } else {
        cn.gt -= dt;
        const fd = sc.feed && sc.feed.life > 0 ? sc.feed : null; // кормёжка на спорах пузырчатки
        if (cn.gt <= 0 || (fd && cn.goal.distanceTo(fd.c) > 3)) { cn.gt = G.rr(2, 5); if (fd) cn.goal.copy(fd.c).add(tv.set(G.rr(-1.5, 1.5), G.rr(-1, 1), G.rr(-1.5, 1.5))); else cn.goal.set(sc.c.x + G.rr(-3, 3), sc.c.y + G.rr(0.5, 1.3), sc.c.z + G.rr(-3, 3)); }
        if (fd || Math.hypot(cn.p.x - sc.c.x, cn.p.z - sc.c.z) > 4) maxS = 2.2; // к спорам и обратно на мох — быстрее
      }
      tv.copy(cn.goal).sub(cn.p); const d = tv.length();
      if (d > 0.05) cn.v.lerp(tv.multiplyScalar(Math.min(maxS, d * 1.5) / d), Math.min(1, dt * 3));
      cn.p.addScaledVector(cn.v, dt);
      G.Ship.pushOut(cn.p, 0.25, cn.v);
      const h = H(cn.p.x, cn.p.z); if (cn.p.y < h + 0.3) cn.p.y = h + 0.3;
      clampArea(cn.p);
    }
    for (const gz of E.glazuns) {
      gz.cd -= dt; gz.eyesCd -= dt; gz.lunge = Math.max(0, gz.lunge - dt * 2);
      if (gz.cd <= 0) {
        for (const cn of gz.sc.members) {
          if (!cn.alive) continue;
          if (Math.hypot(cn.p.x - gz.p.x, cn.p.z - gz.p.z) < GZ_REACH && cn.p.y - gz.p.y < 2.2) {
            cn.alive = false; cn.t = G.rr(30, 45); gz.cd = 18; gz.lunge = 1;
            E.emit('glazun', 'ambush', gz.p, () => SP.glazun.scanned ? `Песчаный глазун схватил ${G.nm('monet', 'acc')}` : `Из песка что-то схватило ${G.nm('monet', 'acc')}`);
            break;
          }
        }
      }
      const wasLit = gz.lit; gz.lit = inBeam(gz.eyeC);
      if (gz.lit && !wasLit && gz.eyesCd <= 0) { gz.eyesCd = 40; E.emit('glazun', 'eyes', gz.eyeC, () => `В луче прожектора блеснули ${SP.glazun.scanned ? 'глаза песчаного глазуна' : 'два глаза в песке'}`); }
    }
  }
  function coinsRender(t) {
    for (const cn of E.coins) {
      if (cn.alive) {
        dummy.position.copy(cn.p);
        if (cn.v.lengthSq() > 1e-4) dummy.lookAt(tv.copy(cn.p).add(cn.v)); else dummy.rotation.set(0, cn.ph, 0);
        dummy.rotateZ(Math.sin(t * 2 + cn.ph) * 0.2); dummy.scale.setScalar(1);
      } else { dummy.position.set(0, -999, 0); dummy.rotation.set(0, 0, 0); dummy.scale.setScalar(0.001); }
      dummy.updateMatrix(); E.coinIM.setMatrixAt(cn.i, dummy.matrix);
    }
    E.coinIM.instanceMatrix.needsUpdate = true;
    for (const gz of E.glazuns) {
      /* бросок: тело приподнимается из песка */
      dummy.position.copy(gz.p); dummy.position.y += gz.lunge * 0.35; dummy.rotation.set(-gz.lunge * 0.4, gz.yaw, 0, 'YXZ'); dummy.scale.setScalar(1); dummy.updateMatrix();
      E.glzBodyIM.setMatrixAt(gz.i, dummy.matrix);
      const k = gz.lit ? 1 : 0.35 + 0.1 * Math.sin(t * 1.3 + gz.i);
      for (let e = 0; e < 2; e++) {
        dummy.position.copy(gz.eye[e]); dummy.position.y += gz.lunge * 0.35; dummy.rotation.set(0, 0, 0); dummy.scale.setScalar(gz.lit ? 1.6 : 1); dummy.updateMatrix();
        E.glzEyeIM.setMatrixAt(gz.i * 2 + e, dummy.matrix);
        E.glzEyeIM.setColorAt(gz.i * 2 + e, rdColT.setRGB(k + 0.2, k + 0.25, 0.45 * k));
      }
    }
    E.glzBodyIM.instanceMatrix.needsUpdate = true; E.glzEyeIM.instanceMatrix.needsUpdate = true; E.glzEyeIM.instanceColor.needsUpdate = true;
  }
  /* импульс сонара: стайки рассыпаются прочь от ближайшей угрозы */
  function coinsPing(pos) {
    for (const sc of E.schools) {
      if (sc.c.distanceTo(pos) > SCATTER_R || !sc.members.some(c => c.alive)) continue;
      let from = null, kind = null, bd = 1e9;
      const gz = E.glazuns[sc.i], dg = Math.hypot(gz.p.x - sc.c.x, gz.p.z - sc.c.z);
      if (dg < 12) { from = gz.p; kind = 'glazun'; bd = dg; }
      for (const pr of E.preds) { const d = pr.p.distanceTo(sc.c); if (d < 30 && d < bd) { from = pr.p; kind = 'pred'; bd = d; } }
      if (!from) { from = pos; kind = 'ship'; }
      sc.from.copy(from); sc.scatter = 2.5;
      if (sc.scatCd > 0) continue;
      sc.scatCd = 30;
      const where = kind === 'glazun' ? 'от песка рядом — там кто-то прячется' : kind === 'pred' ? `от ${G.nm('pred', 'gen')}` : 'от корабля';
      E.emit('monet', 'scatter', sc.c, () => `Стайка ${G.nm('monet', 'gen')} рассыпается ${where}`);
      if (kind === 'glazun') E.emit('glazun', 'sonar', gz.p, null);
    }
  }

  /* ======================= ГРОТОВИК ======================= */
  /* Живой остров: панцирное существо с рифом на спине бредёт по отмели. Одна стая светляков
     живёт в его рифе и кочует вместе с ним; напуганные рыбы прячутся в риф, и хищник их теряет.
     Если задеть гротовика корпусом, он прячет ноги и замирает. */
  const GR_R = 3.2, GR_SPEED = 0.45, GR_HIDE_R = 5;
  function grotGeo() {
    const shell = new THREE.SphereGeometry(1, 16, 8, 0, Math.PI * 2, 0, Math.PI / 2); shell.scale(2.4, 1.1, 3.2);
    const rim = new THREE.TorusGeometry(1, 0.12, 5, 20); rim.rotateX(Math.PI / 2); rim.scale(2.4, 1, 3.2);
    const head = new THREE.SphereGeometry(0.55, 10, 6); head.scale(1, 0.7, 1.2); head.translate(0, 0.25, 3.4);
    const eyes = []; [-1, 1].forEach(sx => { const e = new THREE.SphereGeometry(0.09, 6, 4); e.translate(sx * 0.3, 0.45, 3.85); eyes.push(e); });
    return G.merge([{ g: shell, c: new THREE.Color(0x5b5a4a) }, { g: rim, c: new THREE.Color(0x3e3b30) }, { g: head, c: new THREE.Color(0x6b6656) },
      ...eyes.map(g => ({ g, c: new THREE.Color(0xffe08a) }))]);
  }
  function grotLegsGeo() {
    const lp = [];
    [-1, 1].forEach(sx => [-1.8, 0, 1.8].forEach(z => {
      const g = new THREE.CylinderGeometry(0.22, 0.3, 1.1, 6); g.translate(0, -0.55, 0);
      lp.push({ g, m: new THREE.Matrix4().makeTranslation(sx * 2.1, 0.35, z).multiply(new THREE.Matrix4().makeRotationZ(sx * 0.5)), c: new THREE.Color(0x4a473a) });
    }));
    return G.merge(lp);
  }
  function grotReefGeo() { // риф на спине: ветки огнецвета, светящиеся кончики, мшистые бугры
    const parts = [], wood = new THREE.Color(0.7, 0.35, 0.2), tip = new THREE.Color(1, 0.75, 0.35), moss = new THREE.Color(0.35, 0.8, 0.55);
    for (let k = 0; k < 11; k++) {
      const a = k * 2.39996, r = Math.sqrt((k + 0.5) / 11) * 0.85;
      const x = Math.cos(a) * r * 2.1, z = Math.sin(a) * r * 2.8, y = Math.sqrt(Math.max(0, 1 - r * r)) * 1.05;
      const L = 0.9 + (k % 3) * 0.35;
      const br = new THREE.CylinderGeometry(0.06, 0.14, L, 5); br.translate(0, L / 2, 0);
      const m = new THREE.Matrix4().makeTranslation(x, y, z).multiply(new THREE.Matrix4().makeRotationAxis(new V3(Math.sin(a), 0, -Math.cos(a)), 0.25 + (k % 2) * 0.2));
      parts.push({ g: br, m, c: wood });
      const tp = new THREE.SphereGeometry(0.16, 6, 4); tp.translate(0, L, 0); parts.push({ g: tp, m: m.clone(), c: tip });
    }
    for (let k = 0; k < 6; k++) {
      const a = k * 1.1 + 0.4, g = new THREE.SphereGeometry(0.45, 8, 5); g.scale(1, 0.45, 1);
      g.translate(Math.cos(a) * 1.5, 0.8, Math.sin(a) * 2.1); parts.push({ g, c: moss });
    }
    return G.merge(parts);
  }
  function initGrot(scene) {
    if (E.shoals.length < 6) return;
    const route = [[-22, 62], [18, 44], [30, 4], [-14, 12]].map(([x, z]) => new V3(x, H(x, z), z));
    const g = new THREE.Group();
    const body = new THREE.Mesh(grotGeo(), new THREE.MeshLambertMaterial({ vertexColors: true, emissive: 0x0e0c08 }));
    const legs = new THREE.Mesh(grotLegsGeo(), new THREE.MeshLambertMaterial({ vertexColors: true }));
    const reef = new THREE.Mesh(grotReefGeo(), new THREE.MeshLambertMaterial({ vertexColors: true, emissive: 0x2a1004 }));
    g.add(body, legs, reef); scene.add(g);
    const p = route[0].clone();
    const ob = { x: p.x, z: p.z, r: GR_R, top: p.y + 4, grot: true };
    G.World.obstacles.push(ob);
    const sh = E.shoals[5]; sh.range = 4;
    E.grot = { g, body, legs, reef, route, wp: 1, p, yaw: 0, back: new V3(), sh, ob, shy: 0, lift: 1, shyCd: 0, hideCd: 0, driftCd: 0, homeOld: sh.home.clone() };
    grotPlace(E.grot, 0, 0);
  }
  function grotPlace(gr, dt, t) {
    const y = H(gr.p.x, gr.p.z) + 0.6 + 0.55 * gr.lift;
    gr.g.position.set(gr.p.x, y, gr.p.z); gr.g.rotation.set(0, gr.yaw, 0);
    gr.back.set(gr.p.x, y + 1.6, gr.p.z);
    gr.ob.x = gr.p.x; gr.ob.z = gr.p.z; gr.ob.top = y + 3.5;
    gr.sh.home.set(gr.back.x, gr.back.y + 0.6, gr.back.z);
  }
  function grotUpdate(gr, dt, t) {
    const S = G.Ship;
    gr.shy -= dt; gr.shyCd -= dt; gr.hideCd -= dt; gr.driftCd -= dt;
    /* корабль задел панцирь */
    const dx = S.pos.x - gr.p.x, dz = S.pos.z - gr.p.z;
    if (Math.hypot(dx, dz) < GR_R + 6.4 && S.pos.y < gr.ob.top && gr.shy <= 0 && gr.shyCd <= 0) {
      gr.shy = 10; gr.shyCd = 25; gr.sh.alarm = Math.max(gr.sh.alarm, 3); gr.sh.threat = null;
      E.emit('grot', 'shy', gr.back, () => `${cap(G.nm('grot'))} прячет ноги под панцирь и замирает`);
    }
    const moving = gr.shy <= 0;
    gr.lift += ((moving ? 1 : 0) - gr.lift) * Math.min(1, dt * 2);
    if (moving) {
      const tg = gr.route[gr.wp];
      tv.set(tg.x - gr.p.x, 0, tg.z - gr.p.z); const d = tv.length();
      if (d < 1.5) gr.wp = (gr.wp + 1) % gr.route.length;
      else {
        let da = Math.atan2(tv.x, tv.z) - gr.yaw; da = Math.atan2(Math.sin(da), Math.cos(da));
        gr.yaw += da * Math.min(1, dt * 0.3);
        gr.p.x += Math.sin(gr.yaw) * GR_SPEED * dt; gr.p.z += Math.cos(gr.yaw) * GR_SPEED * dt;
      }
      if (gr.driftCd <= 0 && S.center.distanceTo(gr.back) < 35) { gr.driftCd = 90; E.emit('grot', 'drift', gr.back, () => `${cap(G.nm('grot'))} неспешно бредёт по отмели, на спине у него риф`); }
    }
    gr.legs.rotation.x = moving ? Math.sin(t * 2.2) * 0.08 : 0;
    gr.legs.scale.y = 0.35 + 0.65 * gr.lift;
    grotPlace(gr, dt, t);
  }
  /* светляк его стаи прячется в рифе на спине */
  function grotShelter(f) {
    const gr = E.grot;
    if (!gr || f.s !== gr.sh || !(f.s.alarm > 0)) return null;
    return f.p.distanceTo(gr.back) < GR_HIDE_R ? gr : null;
  }
  E.grotShelter = grotShelter;

  /* ======================= СКАЛЬНИК ======================= */
  /* Рогатый спрут у норы кольчужника. Неподвижный — неотличим от камня (на сонаре и в прицеле его нет),
     в луче прожектора меняет цвет и выдаёт себя. Подстерегает кольчужника, вышедшего на охоту:
     краба с бедным панцирем выгоняет обратно в нору, от краба в полной броне из игл отступает.
     Любопытен: к неподвижному кораблю с погашенным светом подплывает к самому стеклу. */
  const SK_ARMS = 8, SK_SEG = 6, SK_ARMOR = 7, SK_THIEF_R = 12;
  const skRock = new THREE.Color(0x4f4a5c), skSkin = new THREE.Color(0xb8553c);
  function initSkalnik(scene) {
    const cr = E.crab; if (!cr) return;
    const side = new V3(-cr.out.z, 0, cr.out.x);
    const home = cr.den.clone().addScaledVector(side, 7); home.y = H(home.x, home.z);
    const mantle = new THREE.SphereGeometry(1, 12, 8); mantle.scale(0.6, 0.5, 0.75); mantle.translate(0, 0.45, -0.15);
    const parts = [{ g: mantle }];
    [-1, 1].forEach(sx => {
      const horn = new THREE.ConeGeometry(0.08, 0.45, 5); horn.rotateZ(-sx * 0.5); horn.translate(sx * 0.35, 0.95, 0.15); parts.push({ g: horn });
      const eye = new THREE.SphereGeometry(0.08, 6, 4); eye.translate(sx * 0.3, 0.55, 0.45); parts.push({ g: eye });
    });
    const body = new THREE.Mesh(G.merge(parts), new THREE.MeshLambertMaterial({ color: skRock.clone(), flatShading: true }));
    const arms = new THREE.InstancedMesh(new THREE.SphereGeometry(1, 6, 4), body.material, SK_ARMS * SK_SEG);
    arms.frustumCulled = false; scene.add(body); scene.add(arms);
    const carryM = new THREE.Mesh(new THREE.OctahedronGeometry(0.22, 0), new THREE.MeshBasicMaterial({ color: 0xffffff })); carryM.visible = false; scene.add(carryM);
    E.skalnik = { carryM, loot: null, home, p: home.clone(), v: new V3(), dir: cr.out.clone().negate(), body, arms, state: 'rock', timer: 0, cd: 20, curCd: 0, camo: 1, reveal: 0, lit: false, mimicCd: 0, goal: new V3() };
  }
  function skUpdate(sk, dt, t) {
    const S = G.Ship, cr = E.crab;
    sk.timer -= dt; sk.cd -= dt; sk.curCd -= dt; sk.reveal -= dt; sk.mimicCd -= dt;
    const wasLit = sk.lit; sk.lit = inBeam(tv3.copy(sk.p).setY(sk.p.y + 0.5));
    if (sk.lit && !wasLit && sk.camo > 0.6) { // камень ожил: в луче спрут меняет цвет
      sk.reveal = 6;
      if (sk.mimicCd <= 0) { sk.mimicCd = 40; E.emit('skalnik', 'mimic', sk.p, () => SP.skalnik.scanned ? 'Скальник в луче прожектора сбросил маскировку' : 'Камень в луче прожектора меняет цвет — это живое существо'); }
    }
    let speed = 0;
    const still = Math.abs(S.speed) < 0.5 && !S.light && S.hull > 0;
    switch (sk.state) {
      case 'rock':
        sk.goal.copy(sk.home);
        if (sk.cd <= 0 && cr && (cr.state === 'hunt' || cr.state === 'crack') && cr.p.distanceTo(cr.den) > 2.5) { sk.state = 'stalk'; sk.timer = 30; }
        else if (sk.curCd <= 0 && still && S.front.distanceTo(sk.home) < 25) {
          sk.state = 'curious'; sk.timer = 14; sk.curCd = 60;
        }
        break;
      case 'stalk':
        speed = 1.6; sk.goal.copy(cr.p);
        if (sk.timer <= 0 || !(cr.state === 'hunt' || cr.state === 'crack')) { sk.state = 'back'; break; }
        if (Math.hypot(sk.p.x - cr.p.x, sk.p.z - cr.p.z) < 1.4) {
          if (cr.spines >= SK_ARMOR) {
            E.emit('skalnik', 'armor', cr.p, () => `${cap(G.nm('skalnik'))} отступает: панцирь ${G.nm('krab', 'gen')} весь в иглах`);
          } else {
            if (cr.target) { cr.target = null; }
            cr.state = 'home'; cr.scared = 6;
            E.emit('skalnik', 'hunt', cr.p, () => `${cap(G.nm('skalnik'))} набросился на ${G.nm('krab', 'acc')} — тот удирает в нору`);
          }
          sk.state = 'back'; sk.cd = 60;
        }
        break;
      case 'curious': {
        speed = 1.2;
        tv.set(0, 0, -1).applyQuaternion(S.group.quaternion);
        sk.goal.copy(S.front).addScaledVector(tv, 2.6); sk.goal.y -= 0.8;
        if (sk.p.distanceTo(sk.goal) < 1 && sk.timer < 11 && !sk.seen) { sk.seen = true; E.emit('skalnik', 'curious', sk.p, () => `${cap(G.nm('skalnik'))} подплыл к самому стеклу и разглядывает корабль`); }
        if (S.light || Math.abs(S.speed) > 1.5) { sk.state = 'back'; sk.reveal = 4; speed = 0; break; } // спугнули
        if (sk.timer <= 0) sk.state = 'back';
        break;
      }
      case 'back':
        speed = 1.8; sk.goal.copy(sk.home); sk.seen = false;
        if (sk.p.distanceTo(sk.home) < 0.5) { sk.state = 'rock'; sk.p.copy(sk.home); }
        break;
      case 'thief': { // рука манипулятора с образцом рядом — стащить
        const M = G.Manip; speed = 5;
        if (!M.arm || M.state === 'idle') { sk.state = 'back'; break; }
        G.Ship.group.localToWorld(sk.goal.copy(M.arm.tipL));
        if (sk.p.distanceTo(sk.goal) < 2.2 && M.state === 'back') { // щупальца длинные: хватает за пару метров
          sk.loot = M.steal(); sk.state = 'loot'; sk.reveal = 6;
          E.emit('skalnik', 'thief', sk.p, () => `${cap(G.nm('skalnik'))} стащил образец с манипулятора и уносит его к себе`);
        }
        break;
      }
      case 'loot':
        speed = 2.2; sk.goal.copy(sk.home);
        if (sk.p.distanceTo(sk.home) < 0.6) { // добычу — в нору, к камням
          const s = sk.loot; sk.loot = null; sk.state = 'rock'; sk.p.copy(sk.home);
          if (s) G.Manip.drop(s, tv.copy(sk.home).addScaledVector(tv2.set(Math.cos(s.i), 0, Math.sin(s.i)), 1.2));
        }
        break;
    }
    /* рука тянется за образцом недалеко от норы — скальник бросается её обчистить */
    if (sk.state === 'rock' && G.Manip.arm && (G.Manip.state === 'reach' || G.Manip.state === 'back') && G.Manip.target && G.Manip.target.pos.distanceTo(sk.home) < SK_THIEF_R) { sk.state = 'thief'; sk.reveal = 4; }
    if (sk.carryM) { sk.carryM.visible = !!sk.loot; if (sk.loot) { sk.carryM.position.copy(sk.p).y += 0.9; sk.carryM.material.color.set(G.Manip.KIND[sk.loot.kind].color); } }
    if (speed > 0) {
      tv.copy(G.Ship.detour(sk.p, sk.goal, 0.5, tv3)).sub(sk.p); const d = tv.length();
      if (d > 0.05) { sk.v.copy(tv).multiplyScalar(Math.min(speed, d * 2) / d); sk.p.addScaledVector(sk.v, dt); tv2.copy(sk.v).setY(0); if (tv2.lengthSq() > 1e-4) sk.dir.lerp(tv2.normalize(), Math.min(1, dt * 3)).normalize(); }
      else sk.v.set(0, 0, 0);
      G.Ship.pushOut(sk.p, 0.5, sk.v);
      const h = H(sk.p.x, sk.p.z); if (sk.p.y < h) sk.p.y = h;
      if (sk.state === 'stalk' || sk.state === 'back') sk.p.y = Math.max(h, sk.p.y + (h + 0.2 - sk.p.y) * Math.min(1, dt * 3));
    } else sk.v.set(0, 0, 0);
    const camoWant = sk.state === 'rock' && sk.reveal <= 0 ? 1 : 0;
    sk.camo += (camoWant - sk.camo) * Math.min(1, dt * (camoWant ? 0.5 : 4));
    if (cr && cr.scared > 0) cr.scared -= dt;
  }
  function skRender(sk, t) {
    const b = sk.body;
    b.position.copy(sk.p); b.rotation.set(0, Math.atan2(sk.dir.x, sk.dir.z), 0);
    b.material.color.copy(skRock).lerp(skSkin, 1 - sk.camo);
    b.material.emissive.setRGB(0.12 * (1 - sk.camo), 0.03 * (1 - sk.camo), 0.02 * (1 - sk.camo));
    const moving = sk.v.lengthSq() > 0.01, spread = sk.state === 'rock' ? 0.55 : 1;
    tv2.copy(sk.v).normalize();
    for (let a = 0; a < SK_ARMS; a++) {
      const ang = a / SK_ARMS * 6.283 + 0.2, ca = Math.cos(ang), sa = Math.sin(ang);
      for (let j = 0; j < SK_SEG; j++) {
        const r = (0.35 + j * 0.24) * spread, w = Math.sin(t * 2.5 + a + j * 0.7) * 0.06 * j;
        tv.set(sk.p.x + ca * r + w, sk.p.y + 0.25 - j * 0.05, sk.p.z + sa * r - w);
        if (moving) tv.addScaledVector(tv2, -j * 0.22);
        const h = H(tv.x, tv.z) + 0.06; if (tv.y < h) tv.y = h;
        dummy.position.copy(tv); dummy.rotation.set(0, 0, 0);
        const s = 0.2 * (1 - j / SK_SEG * 0.65); dummy.scale.set(s, s * 0.75, s); dummy.updateMatrix();
        sk.arms.setMatrixAt(a * SK_SEG + j, dummy.matrix);
      }
    }
    sk.arms.instanceMatrix.needsUpdate = true;
  }

  /* ======================= ПРИСОСКИ ======================= */
  /* Рыбы-прилипалы катаются на ледокрылах. Если корабль подойдёт к ледокрылу, они перебираются на корпус.
     Стеклоуст не садится туда, где уже кто-то есть, — прилипалы на корпусе его отпугивают.
     Зато каждая немного тормозит корабль. Разряд по корпусу их сбрасывает, и они уплывают к ледокрылам. */
  const RM_PER_RAY = 3, RM_HOP_R = 16, RM_DRAG = 0.025;
  const RM_SLOTS = E.RM_SLOTS = [[-3.3, 0.85, -6.25], [3.4, 0.85, -6.25], [-2.5, 3.45, -3], [2.5, 3.45, -3.6], [0, 3.45, 0.5], [-5.25, 0.7, -0.9], [5.25, 0.7, -3.2], [0, 2.85, 4.2], [-4.25, 0.6, 9.5], [4.25, 0.6, 8.6]]; // снаружи корпуса (S.HULL)
  const RM_ON_RAY = [[-0.9, 0.55, 0.6], [1.0, 0.5, -0.4], [0.2, 0.6, -1.6]];
  function initRemoras(scene) {
    if (!E.rays.length) return;
    const body = new THREE.SphereGeometry(1, 8, 5); body.scale(0.07, 0.05, 0.2);
    const disc = new THREE.SphereGeometry(1, 8, 4); disc.scale(0.05, 0.015, 0.09); disc.translate(0, 0.045, 0.06);
    const tail = new THREE.ConeGeometry(0.05, 0.1, 4); tail.rotateX(Math.PI / 2); tail.translate(0, 0, -0.24);
    E.rmIM = new THREE.InstancedMesh(G.merge([{ g: body, c: new THREE.Color(0x55606a) }, { g: disc, c: new THREE.Color(0xd8e6ea) }, { g: tail, c: new THREE.Color(0x3a444c) }]),
      new THREE.MeshLambertMaterial({ vertexColors: true, emissive: 0x0c1418 }), E.rays.length * RM_PER_RAY);
    E.rmIM.frustumCulled = false; scene.add(E.rmIM);
    E.rays.forEach((ry, ri) => { for (let k = 0; k < RM_PER_RAY; k++) E.remoras.push({ i: E.remoras.length, state: 'ray', ray: ry, spot: k, slot: -1, p: new V3(), v: new V3(), dir: new V3(0, 0, 1), cd: 0, ph: k * 1.7 + ri }); });
    E.remoras.forEach(rm => rmAnchor(rm, rm.p));
  }
  function rmAnchor(rm, out) { // точка, где прилипала держится сейчас
    if (rm.state === 'hull' || (rm.state === 'swim' && rm.slot >= 0)) { const s = RM_SLOTS[rm.slot]; return G.Ship.group.localToWorld(out.set(s[0], s[1], s[2])); }
    const o = RM_ON_RAY[rm.spot % RM_ON_RAY.length]; rm.ray.mesh.updateMatrixWorld(); return rm.ray.mesh.localToWorld(out.set(o[0], o[1], o[2]));
  }
  function freeSlot() { for (let s = 0; s < RM_SLOTS.length; s++) if (!E.remoras.some(r => r.slot === s)) return s; return -1; }
  function remorasUpdate(dt, t) {
    const S = G.Ship;
    E.rmHopCd -= dt; E.rmEelCd -= dt; E.rmRideCd -= dt;
    if (E.rmRideCd <= 0) for (const ry of E.rays) if (ry.p.distanceTo(S.center) < 40 && E.remoras.some(r => r.state === 'ray' && r.ray === ry)) {
      E.rmRideCd = 120; E.emit('prisoska', 'ride', ry.p, () => `На спине ${G.nm('ray', 'gen')} катаются ${SP.prisoska.scanned ? 'присоски' : 'рыбы-прилипалы'}`); break;
    }
    for (const rm of E.remoras) {
      rm.cd -= dt;
      if (rm.state === 'ray') {
        rmAnchor(rm, rm.p); rm.dir.copy(rm.ray.dir);
        if (rm.cd <= 0 && E.rmHopCd <= 0 && S.hull > 0 && rm.ray.p.distanceTo(S.center) < RM_HOP_R) {
          const s = freeSlot(); if (s >= 0) { rm.state = 'swim'; rm.slot = s; E.rmHopCd = 1.5; }
        }
      } else if (rm.state === 'swim') {
        rmAnchor(rm, tv); tv2.copy(tv).sub(rm.p); const d = tv2.length();
        if (d < 0.3) {
          if (rm.slot >= 0) {
            rm.state = 'hull';
            const n = E.remoras.filter(r => r.state === 'hull').length;
            E.emit('prisoska', 'hop', rm.p, n === 1 ? () => `${cap(G.nm('prisoska'))} перебралась с ${G.nm('ray', 'gen')} на корпус корабля` : null);
            if (n === 3) E.emit('prisoska', 'drag', rm.p, () => `${cap(G.nm('prisoska', 'gen'))} на корпусе уже три — корабль идёт тяжелее`);
          } else { rm.state = 'ray'; rm.cd = 60; }
        } else { rm.p.addScaledVector(tv2, Math.min(1, 8 * dt / d)); rm.dir.copy(tv2).normalize(); if (rm.slot < 0) S.pushOut(rm.p, 0.2); }
      } else if (rm.state === 'hull') { rmAnchor(rm, rm.p); tv.set(0, 0, -1).applyQuaternion(S.group.quaternion); rm.dir.copy(tv); }
    }
    E.hullRemoras = E.remoras.filter(r => r.state === 'hull').length;
    E.remoras.forEach(rm => {
      dummy.position.copy(rm.p); dummy.lookAt(tv.copy(rm.p).add(rm.dir));
      if (rm.state === 'swim') dummy.rotateY(Math.sin(t * 14 + rm.ph) * 0.3);
      dummy.scale.setScalar(1.6); dummy.updateMatrix(); E.rmIM.setMatrixAt(rm.i, dummy.matrix);
    });
    E.rmIM.instanceMatrix.needsUpdate = true;
  }
  /* разряд: прилипалы отцепляются и уплывают к ближайшему ледокрылу */
  function remorasZap() {
    let n = 0;
    for (const rm of E.remoras) {
      if (rm.state !== 'hull' && !(rm.state === 'swim' && rm.slot >= 0)) continue;
      let best = E.rays[0], bd = 1e9; for (const ry of E.rays) { const d = ry.p.distanceTo(rm.p); if (d < bd) { bd = d; best = ry; } }
      rm.ray = best; rm.slot = -1; rm.state = 'swim'; rm.cd = 60; n++;
    }
    E.hullRemoras = 0;
    if (n) E.emit('prisoska', 'zap', G.Ship.center, () => `Разряд сбросил ${G.nm('prisoska', 'acc')} с корпуса`);
  }

  /* ======================= КАМЕНЩИКИ И ТРУБНЫЙ ОРГАН ======================= */
  /* Каменщики — ряды трубчатых червей у огнецвета. Венчики прячутся в трубки, когда рядом проходит
     что-то крупное: корабль на ходу, серпохвост, гротовик. По рядам видно, где идёт хищник.
     Трубный орган — губка из толстых труб, гудит в течении. Гул заглушает двигатели: рядом с ним
     серпохвост не слышит быстрый ход корабля. */
  const KM_N = 16, KM_LEN = 7, KM_BIG_SHIP = 9, KM_BIG_PRED = 7, ORG_R = 22, HEAR_R = 24, HEAR_SPEED = 3;
  function initMasons(scene) {
    if (!E.stations.length) return;
    const tg = new THREE.CylinderGeometry(0.05, 0.07, 0.35, 6); tg.translate(0, 0.17, 0);
    const cg = new THREE.ConeGeometry(0.16, 0.14, 8, 1, true); cg.rotateX(Math.PI); cg.translate(0, 0.07, 0);
    const N = E.stations.length * KM_N;
    E.kmTubeIM = new THREE.InstancedMesh(tg, new THREE.MeshLambertMaterial({ color: 0xd8d0c0 }), N);
    E.kmCrownIM = new THREE.InstancedMesh(cg, new THREE.MeshBasicMaterial({ side: THREE.DoubleSide }), N);
    [E.kmTubeIM, E.kmCrownIM].forEach(m => { m.frustumCulled = false; scene.add(m); });
    const pal = [0xff5f7a, 0xffb347, 0x6fe3ff, 0xc38cff].map(c => new THREE.Color(c));
    E.stations.forEach((st, si) => {
      const a = si * 2.1 + 0.5, dir = new V3(Math.cos(a), 0, Math.sin(a)), side = new V3(-dir.z, 0, dir.x);
      const c0 = st.base.clone().addScaledVector(dir, 5);
      const col = { i: si, st, c: c0.clone(), worms: [], hideCd: 0, warnCd: 0 };
      for (let k = 0; k < KM_N; k++) {
        const p = c0.clone().addScaledVector(side, (k / (KM_N - 1) - 0.5) * KM_LEN).addScaledVector(dir, Math.sin(k * 1.7) * 0.25);
        p.y = H(p.x, p.z) - 0.02;
        const w = { j: si * KM_N + k, p, top: p.clone().add(new V3(0, 0.35, 0)), ext: 1, quiet: 0 };
        dummy.position.copy(p); dummy.rotation.set(Math.sin(k) * 0.12, k, Math.cos(k) * 0.12); dummy.scale.setScalar(1); dummy.updateMatrix();
        E.kmTubeIM.setMatrixAt(w.j, dummy.matrix);
        E.kmCrownIM.setColorAt(w.j, pal[(k + si) % pal.length]);
        col.worms.push(w);
      }
      col.c.y = H(col.c.x, col.c.z);
      E.masons.push(col);
    });
    E.kmTubeIM.instanceMatrix.needsUpdate = true; E.kmCrownIM.instanceColor.needsUpdate = true;
  }
  /* кто «крупный и шумный» рядом с точкой: 'ship', 'pred', 'grot' или null */
  function bigNear(p) {
    const S = G.Ship;
    if ((Math.abs(S.speed) > 0.6 || Math.abs(S.vy) > 0.6) && S.center.distanceTo(p) < KM_BIG_SHIP) return 'ship';
    for (const pr of E.preds) if (pr.p.distanceTo(p) < KM_BIG_PRED) return 'pred';
    if (E.grot && E.grot.shy <= 0 && Math.hypot(E.grot.p.x - p.x, E.grot.p.z - p.z) < KM_BIG_PRED) return 'grot';
    return null;
  }
  function masonsUpdate(dt, t) {
    const S = G.Ship;
    for (const col of E.masons) {
      col.hideCd -= dt; col.warnCd -= dt;
      let hidden = 0, why = null;
      for (const w of col.worms) {
        const b = bigNear(w.top);
        if (b) { w.quiet = 3; why = why || b; }
        w.quiet -= dt;
        const want = w.quiet > 0 ? 0 : 1;
        w.ext = want < w.ext ? Math.max(0, w.ext - dt * 6) : Math.min(1, w.ext + dt * 0.5); // прячутся мгновенно, раскрываются не спеша
        if (w.ext < 0.3) hidden++;
        dummy.position.copy(w.top); dummy.position.y -= (1 - w.ext) * 0.3;
        dummy.rotation.set(0, t * 0.2 + w.j, 0);
        const sc = 0.15 + 0.85 * w.ext; dummy.scale.set(sc, 0.3 + 0.7 * w.ext + Math.sin(t * 3 + w.j) * 0.05 * w.ext, sc); dummy.updateMatrix();
        E.kmCrownIM.setMatrixAt(w.j, dummy.matrix);
      }
      col.hidden = hidden;
      if (hidden >= 4 && col.hideCd <= 0) {
        col.hideCd = 50;
        E.emit('kamen', 'hide', col.c, () => `${cap(G.nm('kamen'))} прячут венчики в трубки${why === 'ship' ? ' — корабль идёт слишком близко' : ''}`);
      }
      if (hidden >= 4 && why === 'pred' && col.warnCd <= 0 && S.center.distanceTo(col.c) < 45) {
        col.warnCd = 60;
        E.emit('kamen', 'warn', col.c, () => `Ряд ${G.nm('kamen', 'gen')} у огнецвета спрятался — рядом проходит ${G.nm('pred')}`);
      }
    }
    E.kmCrownIM.instanceMatrix.needsUpdate = true;
  }
  function organGeo(pos) { // губка из толстых труб, все органы — в одном меше
    const parts = [], c1 = new THREE.Color(0x9a7f6a), c2 = new THREE.Color(0x6f5b4c), rim = new THREE.Color(0xffd9a0);
    pos.forEach(o => {
      for (let k = 0; k < 7; k++) {
        const a = k * 2.39996, r = k ? 0.75 + (k % 2) * 0.35 : 0, L = 3.4 - r * 1.2 + (k % 3) * 0.4;
        const x = o.x + Math.cos(a) * r, z = o.z + Math.sin(a) * r, y = H(x, z) - 0.1;
        const tb = new THREE.CylinderGeometry(0.32, 0.42, L, 10, 1, true); tb.translate(x, y + L / 2, z);
        parts.push({ g: tb, c: k % 2 ? c1 : c2 });
        const ring = new THREE.TorusGeometry(0.32, 0.05, 4, 10); ring.rotateX(Math.PI / 2); ring.translate(x, y + L, z);
        parts.push({ g: ring, c: rim });
      }
    });
    return G.merge(parts);
  }
  function initOrgans(scene) {
    const spots = [[-38, 78], [52, 30]].map(([x, z]) => new V3(x, H(x, z), z));
    E.organMesh = new THREE.Mesh(organGeo(spots), new THREE.MeshLambertMaterial({ vertexColors: true, side: THREE.DoubleSide, emissive: 0x1a1008 }));
    scene.add(E.organMesh);
    spots.forEach((p, i) => E.organs.push({ i, p, top: p.clone().add(new V3(0, 3.2, 0)), maskCd: 0, humCd: 0 }));
  }
  function organsUpdate(dt, t) {
    const S = G.Ship;
    let best = 1e9;
    E.shipMasked = null;
    for (const og of E.organs) {
      og.maskCd -= dt; og.humCd -= dt;
      const d = S.center.distanceTo(og.p); best = Math.min(best, d);
      if (d < ORG_R) E.shipMasked = og;
      if (d < 30 && og.humCd <= 0) { og.humCd = 120; E.emit('organ', 'hum', og.top, () => `${cap(G.nm('organ'))} гудит в течении, как орган`); }
    }
    E.organMesh.material.emissive.setRGB(0.1 + 0.05 * Math.sin(t * 1.7), 0.06, 0.03);
    if (G.Audio.organ) G.Audio.organ(Math.max(0, 1 - best / 45));
  }
  /* серпохвост слышит быстрый ход корабля поблизости, если его не заглушает трубный орган */
  function hearsShip(pr, dShip) {
    const S = G.Ship;
    if (dShip >= HEAR_R * (G.Cargo.has('quiet') ? 0.5 : 1) || Math.abs(S.speed) <= HEAR_SPEED || S.hull <= 0) return false; // глушитель двигателей
    if (E.shipMasked) {
      const og = E.shipMasked;
      if (og.maskCd <= 0 && (pr.state === 'patrol' || pr.state === 'investigate')) { og.maskCd = 40; E.emit('organ', 'mask', og.top, () => `Гул ${G.nm('organ', 'gen')} заглушает двигатели — ${G.nm('pred')} не слышит корабль`); }
      return false;
    }
    return true;
  }

  /* ======================= ПОДУШЕЧНИК И ПУЗЫРЧАТКА-ФОНАРЬ ======================= */
  /* Подушечник — мягкий коралл у стаи светляков. От касания (корабль или напуганная стая) сжимается
     и выпускает облако чернил: в нём рыбы и корабль скрыты от серпохвоста.
     Пузырчатка-фонарь — стебли со светящимися луковицами у пятен мха. Спелая луковица лопается
     облаком светящихся спор, и на кормёжку слетаются светляки и монетники. */
  const PD_INK_N = 70, PD_INK_R = 5.5, PD_INK_LIFE = 9, PD_RECHARGE = 40;
  const PZ_STEMS = 7, PZ_SPORE_N = 60, PZ_LIFE = 12, PZ_RIPEN = 70, PZ_CALL_R = 35;
  function initCushions(scene) {
    if (E.shoals.length < 5) return;
    const rng0 = G.rng; G.seed(6271);
    const g = new THREE.SphereGeometry(1, 14, 8, 0, Math.PI * 2, 0, Math.PI / 2); g.scale(1.1, 0.75, 1);
    const pos = g.attributes.position, col = new Float32Array(pos.count * 3);
    for (let i = 0; i < pos.count; i++) { const y = pos.getY(i); col.set([0.85 - y * 0.2, 0.45 + y * 0.25, 0.6 + y * 0.3], i * 3); } // бархатные полипы светлее к макушке
    g.setAttribute('color', new THREE.BufferAttribute(col, 3));
    E.pdIM = new THREE.InstancedMesh(g, new THREE.MeshLambertMaterial({ vertexColors: true, emissive: 0x1a0a14 }), 2);
    const ig = new THREE.BufferGeometry(), ia = new Float32Array(2 * PD_INK_N * 3), ic = new Float32Array(2 * PD_INK_N * 3);
    ig.setAttribute('position', new THREE.BufferAttribute(ia, 3)); ig.setAttribute('color', new THREE.BufferAttribute(ic, 3));
    E.inkPts = new THREE.Points(ig, new THREE.PointsMaterial({ size: 2.4, map: glowTex(), vertexColors: true, transparent: true, opacity: 0.85, depthWrite: false }));
    [E.pdIM, E.inkPts].forEach(m => { m.frustumCulled = false; scene.add(m); });
    [3, 4].forEach((si, i) => {
      const sh = E.shoals[si], a = i * 2.4 + 1.1;
      const base = new V3(sh.home.x + Math.cos(a) * 3, 0, sh.home.z + Math.sin(a) * 3); base.y = H(base.x, base.z) - 0.1;
      const cu = { i, sh, base, top: base.clone().add(new V3(0, 1.4, 0)), squeeze: 0, cd: 0, ink: 0, inkC: base.clone().add(new V3(0, 2, 0)), hideCd: 0, off: [] };
      for (let k = 0; k < PD_INK_N; k++) { const v = new V3(G.rr(-1, 1), G.rr(-0.6, 1), G.rr(-1, 1)); if (v.lengthSq() > 1) v.normalize(); cu.off.push(v.multiplyScalar(PD_INK_R * Math.cbrt(G.rng()))); }
      E.cushions.push(cu);
    });
    G.rng = rng0;
  }
  function squeeze(cu, why) {
    if (cu.cd > 0) return false;
    cu.cd = PD_RECHARGE; cu.squeeze = 1; cu.ink = PD_INK_LIFE;
    E.emit('cushion', 'touch', cu.top, () => `${cap(G.nm('cushion'))} сжимается и выпускает облако чернил${why === 'ship' ? ' — корабль его задел' : ''}`);
    return true;
  }
  function inkAt(p) { for (const cu of E.cushions) if (cu.ink > 0 && p.distanceTo(cu.inkC) < PD_INK_R) return cu; return null; }
  E.inkAt = inkAt;
  function cushionsUpdate(dt, t) {
    const S = G.Ship;
    E.shipInk = null;
    const ia = E.inkPts.geometry.attributes.position.array, ic = E.inkPts.geometry.attributes.color.array;
    for (const cu of E.cushions) {
      cu.cd -= dt; cu.ink -= dt; cu.hideCd -= dt;
      /* касание: корабль у самой подушки или напуганная стая, нырнувшая в неё */
      if (Math.hypot(S.center.x - cu.base.x, S.center.z - cu.base.z) < 6.8 && S.pos.y < cu.top.y + 1.2 && S.hull > 0) squeeze(cu, 'ship');
      else if (cu.sh.alarm > 0 && cu.sh.members.some(f => f.alive && f.p.distanceTo(cu.top) < 2.2)) squeeze(cu, 'fish');
      cu.squeeze = Math.max(0, cu.squeeze - dt * 0.15);
      if (cu.ink > 0 && S.center.distanceTo(cu.inkC) < PD_INK_R + 2) E.shipInk = cu;
      const k = Math.max(0, Math.min(1, cu.ink / 2)) ; // последние 2 с облако тает
      const grow = Math.min(1, (PD_INK_LIFE - cu.ink) * 2);
      for (let j = 0; j < PD_INK_N; j++) {
        const q = (cu.i * PD_INK_N + j) * 3, o = cu.off[j];
        if (cu.ink > 0) {
          ia[q] = cu.inkC.x + o.x * grow + Math.sin(t * 0.5 + j) * 0.3; ia[q + 1] = cu.inkC.y + o.y * grow; ia[q + 2] = cu.inkC.z + o.z * grow + Math.cos(t * 0.4 + j) * 0.3;
          ic[q] = 0.05 * k; ic[q + 1] = 0.04 * k; ic[q + 2] = 0.12 * k;
        } else { ia[q] = 0; ia[q + 1] = -999; ia[q + 2] = 0; }
      }
      const s = 1 - cu.squeeze * 0.45;
      dummy.position.copy(cu.base); dummy.rotation.set(0, cu.i, 0); dummy.scale.set(s, s * (1 - cu.squeeze * 0.2), s); dummy.updateMatrix(); E.pdIM.setMatrixAt(cu.i, dummy.matrix);
    }
    E.pdIM.instanceMatrix.needsUpdate = true;
    E.inkPts.geometry.attributes.position.needsUpdate = true; E.inkPts.geometry.attributes.color.needsUpdate = true;
  }
  function initBladders(scene) {
    if (!E.schools.length) return;
    const rng0 = G.rng; G.seed(8813);
    const stemG = new THREE.CylinderGeometry(0.025, 0.04, 1, 4); stemG.translate(0, 0.5, 0);
    const N = E.schools.length * PZ_STEMS;
    E.pzStemIM = new THREE.InstancedMesh(stemG, new THREE.MeshLambertMaterial({ color: 0x3f7a5a }), N);
    const bg = new THREE.SphereGeometry(0.16, 8, 6); bg.scale(1, 1.3, 1);
    E.pzBulbIM = new THREE.InstancedMesh(bg, new THREE.MeshBasicMaterial({ transparent: true, opacity: 0.9 }), N);
    const sg = new THREE.BufferGeometry(), sa = new Float32Array(E.schools.length * PZ_SPORE_N * 3), sc = new Float32Array(E.schools.length * PZ_SPORE_N * 3);
    sg.setAttribute('position', new THREE.BufferAttribute(sa, 3)); sg.setAttribute('color', new THREE.BufferAttribute(sc, 3));
    E.sporePts = new THREE.Points(sg, new THREE.PointsMaterial({ size: 0.5, map: glowTex(), vertexColors: true, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    [E.pzStemIM, E.pzBulbIM, E.sporePts].forEach(m => { m.frustumCulled = false; scene.add(m); });
    E.schools.forEach((s, i) => {
      const a = i * 1.9 + 2.6, base = new V3(s.c.x + Math.cos(a) * 4.5, 0, s.c.z + Math.sin(a) * 4.5); base.y = H(base.x, base.z);
      const bl = { i, base, sc: s, ripe: G.rr(0.2, 0.8), life: 0, c: base.clone().add(new V3(0, 2.2, 0)), stems: [], off: [], feedCd: 0 };
      for (let k = 0; k < PZ_STEMS; k++) {
        const r = k ? 0.35 + (k % 3) * 0.2 : 0, b = k * 2.39996, h = G.rr(0.8, 1.4);
        const p = new V3(base.x + Math.cos(b) * r, H(base.x + Math.cos(b) * r, base.z + Math.sin(b) * r) - 0.05, base.z + Math.sin(b) * r);
        const tilt = new V3(Math.cos(b) * r * 0.25, 1, Math.sin(b) * r * 0.25).normalize();
        dummy.position.copy(p); dummy.quaternion.setFromUnitVectors(tv.set(0, 1, 0), tilt); dummy.scale.set(1, h, 1); dummy.updateMatrix();
        E.pzStemIM.setMatrixAt(i * PZ_STEMS + k, dummy.matrix);
        bl.stems.push({ top: p.clone().addScaledVector(tilt, h), ph: G.rr(0, 6) });
      }
      for (let k = 0; k < PZ_SPORE_N; k++) { const v = new V3(G.rr(-1, 1), G.rr(-0.5, 1), G.rr(-1, 1)); if (v.lengthSq() > 1) v.normalize(); bl.off.push(v.multiplyScalar(2.5 * Math.cbrt(G.rng()))); }
      E.bladders.push(bl); s.feed = null;
    });
    dummy.quaternion.identity(); dummy.rotation.set(0, 0, 0);
    E.pzStemIM.instanceMatrix.needsUpdate = true;
    G.rng = rng0;
  }
  function pop(bl, why) {
    bl.ripe = 0; bl.life = PZ_LIFE;
    E.emit('bladder', 'pop', bl.c, () => why === 'ship' ? 'Корабль задел спелые луковицы — они лопаются облаком светящихся спор' : `Спелые луковицы${SP.bladder.scanned ? ' пузырчатки' : ''} лопаются облаком светящихся спор`);
  }
  function bladdersUpdate(dt, t) {
    const S = G.Ship;
    const sa = E.sporePts.geometry.attributes.position.array, sc = E.sporePts.geometry.attributes.color.array;
    for (const bl of E.bladders) {
      bl.feedCd -= dt;
      if (bl.life > 0) {
        bl.life -= dt;
        /* на споры слетаются светляки (кроме стаи гротовика: она держится своего рифа) и монетники */
        let came = false;
        for (const sh of E.shoals) if (!sh.range && sh.alarm <= 0 && !sh.follow && sh.n >= 3 && sh.c.distanceTo(bl.c) < PZ_CALL_R) { sh.goal.copy(bl.c); sh.gt = Math.max(sh.gt, 0.5); if (sh.c.distanceTo(bl.c) < 6) came = true; }
        if (bl.sc.c.distanceTo(bl.c) < 25 && bl.sc.scatter <= 0) { bl.sc.feed = bl; if (bl.sc.members.some(c => c.alive && c.p.distanceTo(bl.c) < 3)) came = true; }
        if (came && bl.feedCd <= 0) { bl.feedCd = 60; E.emit('bladder', 'feed', bl.c, () => 'На светящиеся споры слетаются рыбы'); }
        if (bl.life <= 0 && bl.sc.feed === bl) bl.sc.feed = null;
      } else {
        bl.ripe = Math.min(1, bl.ripe + dt / PZ_RIPEN);
        if (bl.ripe >= 1) pop(bl, 'ripe');
        else if (bl.ripe > 0.6 && Math.abs(S.speed) > 0.5 && Math.hypot(S.center.x - bl.base.x, S.center.z - bl.base.z) < 6.5 && S.pos.y < bl.base.y + 3) pop(bl, 'ship');
      }
      const k = Math.max(0, Math.min(1, bl.life / 3)), spread = Math.min(1, (PZ_LIFE - bl.life) * 0.6);
      for (let j = 0; j < PZ_SPORE_N; j++) {
        const q = (bl.i * PZ_SPORE_N + j) * 3, o = bl.off[j];
        if (bl.life > 0) {
          sa[q] = bl.c.x + o.x * (0.3 + spread) + Math.sin(t + j) * 0.2; sa[q + 1] = bl.c.y + o.y * (0.3 + spread) + (PZ_LIFE - bl.life) * 0.08; sa[q + 2] = bl.c.z + o.z * (0.3 + spread);
          sc[q] = 0.5 * k; sc[q + 1] = 1 * k; sc[q + 2] = 0.55 * k;
        } else { sa[q] = 0; sa[q + 1] = -999; sa[q + 2] = 0; }
      }
      bl.stems.forEach((st, k) => {
        const j = bl.i * PZ_STEMS + k, r = bl.life > 0 ? 0.2 : 0.35 + 0.65 * bl.ripe;
        dummy.position.copy(st.top); dummy.position.x += Math.sin(t * 0.8 + st.ph) * 0.05; dummy.scale.setScalar(r); dummy.rotation.set(0, 0, 0); dummy.updateMatrix();
        E.pzBulbIM.setMatrixAt(j, dummy.matrix);
        E.pzBulbIM.setColorAt(j, rdColT.setRGB(0.3 + 0.5 * bl.ripe, 0.6 + 0.4 * bl.ripe, 0.35 + 0.2 * bl.ripe));
      });
    }
    E.pzBulbIM.instanceMatrix.needsUpdate = true; if (E.pzBulbIM.instanceColor) E.pzBulbIM.instanceColor.needsUpdate = true;
    E.sporePts.geometry.attributes.position.needsUpdate = true; E.sporePts.geometry.attributes.color.needsUpdate = true;
  }

  /* ======================= ТЕЧЕНИЕ, ВЕЕРНИКИ И ВОЛНОЛИСТ ======================= */
  /* По отмели идёт медленное течение, раз в несколько минут оно меняет направление и сносит корабль.
     Веерники всегда стоят поперёк течения — по ним пилот читает поток; огнёвки кормятся на веернике
     у своей станции, пока та пустует. Волнолист раскрывается в луче прожектора и сворачивается в темноте;
     под раскрытыми листьями видны моллюски, и к ним приплывают светляки. */
  const CUR_SPEED = 0.3, CUR_DIRS = [0.7, 2.4, -1.9, 0.1, 2.9, -0.9], CUR_PERIOD = 180;
  const VN_TURN_R = 70, FERN_LEAVES = 6, FERN_SHELLS = 3, FERN_CALL_R = 25;
  function fanTex() { // кружевная сетка ветвей веерника на прозрачном фоне
    return G.canvasTex(256, 256, (x, w, h) => {
      x.clearRect(0, 0, w, h);
      x.strokeStyle = 'rgba(255,190,150,1)'; x.lineCap = 'round';
      const cx = w / 2, cy = h - 8;
      x.lineWidth = 9; x.beginPath(); x.moveTo(cx, h); x.lineTo(cx, cy - 30); x.stroke();
      for (let k = 0; k < 13; k++) { const a = -1.25 + k / 12 * 2.5; x.lineWidth = 3.2; x.beginPath(); x.moveTo(cx, cy - 30); x.lineTo(cx + Math.sin(a) * 120, cy - 30 - Math.cos(a) * 210); x.stroke(); }
      x.lineWidth = 1.6;
      for (let r = 50; r < 240; r += 20) { x.beginPath(); x.ellipse(cx, cy - 30, r * 0.55, r * 0.95, 0, Math.PI * 1.1, Math.PI * 1.9); x.stroke(); }
    });
  }
  function initFans(scene) {
    if (!E.stations.length) return;
    const g = new THREE.PlaneGeometry(2.6, 3, 1, 1); g.translate(0, 1.5, 0);
    const tex = fanTex(); tex.userData = tex.userData || {};
    E.fanIM = new THREE.InstancedMesh(g, new THREE.MeshLambertMaterial({ map: tex, alphaTest: 0.4, transparent: false, side: THREE.DoubleSide, emissive: 0x3a1408 }), E.stations.length + 1);
    E.fanIM.frustumCulled = false; scene.add(E.fanIM);
    const spots = E.stations.map((st, i) => { const a = i * 2.1 + 2.6; return new V3(st.base.x + Math.cos(a) * 7, 0, st.base.z + Math.sin(a) * 7); });
    spots.push(new V3(-6, 0, 74)); // у старта, чтобы его увидеть сразу
    spots.forEach((p, i) => { p.y = H(p.x, p.z) - 0.05; E.fans.push({ i, p, top: p.clone().add(new V3(0, 2.2, 0)), yaw: 0, st: E.stations[i] || null, ph: i * 1.3 }); });
    E.curIdx = 0; E.curAng = CUR_DIRS[0]; E.curTarget = CUR_DIRS[0]; E.curT = CUR_PERIOD;
  }
  function currentUpdate(dt, t) {
    const S = G.Ship;
    E.curT -= dt; E.fanCd -= dt;
    if (E.curT <= 0) { // течение сменилось
      E.curT = CUR_PERIOD; E.curIdx = (E.curIdx + 1) % CUR_DIRS.length; E.curTarget = CUR_DIRS[E.curIdx];
      if (E.fanCd <= 0 && E.fans.some(f => f.p.distanceTo(S.center) < VN_TURN_R)) { E.fanCd = 60; E.emit('fan', 'turn', S.center, () => `${cap(G.nm('fan'))} разворачиваются — течение сменилось`); }
    }
    let da = E.curTarget - E.curAng; da = Math.atan2(Math.sin(da), Math.cos(da));
    E.curAng += da * Math.min(1, dt * 0.08);
    E.current.set(Math.sin(E.curAng), 0, Math.cos(E.curAng)).multiplyScalar(CUR_SPEED);
    for (const f of E.fans) {
      let dy = E.curAng - f.yaw; dy = Math.atan2(Math.sin(dy), Math.cos(dy)); f.yaw += dy * Math.min(1, dt * 0.3); // плоскость веера смотрит на поток
      dummy.position.copy(f.p); dummy.rotation.set(Math.sin(t * 0.9 + f.ph) * 0.05, f.yaw, 0, 'YXZ'); dummy.scale.setScalar(1); dummy.updateMatrix();
      E.fanIM.setMatrixAt(f.i, dummy.matrix);
    }
    E.fanIM.instanceMatrix.needsUpdate = true;
    if (E.fanReadCd <= 0 && E.fans.some(f => f.p.distanceTo(S.center) < 30)) { E.fanReadCd = 150; E.emit('fan', 'across', S.center, () => `${cap(G.nm('fan'))} стоит поперёк течения — по нему видно, куда несёт`); }
    E.fanReadCd -= dt;
  }
  E.fanAt = st => E.fans.find(f => f.st === st);
  function initFerns(scene) {
    if (E.shoals.length < 3) return;
    const rng0 = G.rng; G.seed(3307);
    const lg = new THREE.PlaneGeometry(0.28, 1.4, 1, 6); lg.translate(0, 0.7, 0);
    const pos = lg.attributes.position; for (let i = 0; i < pos.count; i++) { const y = pos.getY(i); pos.setX(i, pos.getX(i) * Math.sin(Math.min(1, y / 1.4) * Math.PI) * 1.2); } // лист-перо
    lg.computeVertexNormals();
    const cl = [new V3(14, 0, 78), E.shoals[2].home.clone().add(new V3(-6, 0, 4))];
    const N = cl.length * 4;
    E.fernIM = new THREE.InstancedMesh(lg, new THREE.MeshLambertMaterial({ color: 0x5fc48a, side: THREE.DoubleSide, emissive: 0x0a2a14 }), N * FERN_LEAVES);
    const sg = new THREE.SphereGeometry(0.11, 7, 4, 0, Math.PI * 2, 0, Math.PI / 2); sg.scale(1, 0.5, 1.3);
    E.shellIM = new THREE.InstancedMesh(sg, new THREE.MeshLambertMaterial({ color: 0xe8c9a8, emissive: 0x2a1a10 }), N * FERN_SHELLS);
    [E.fernIM, E.shellIM].forEach(m => { m.frustumCulled = false; scene.add(m); });
    cl.forEach((c, ci) => {
      for (let k = 0; k < 4; k++) {
        const p = new V3(c.x + G.rr(-2.5, 2.5), 0, c.z + G.rr(-2.5, 2.5)); p.y = H(p.x, p.z);
        const fe = { i: E.ferns.length, p, top: p.clone().add(new V3(0, 0.9, 0)), open: 0, lit: false, ph: G.rr(0, 6), yaw: G.rr(0, 6.28), openCd: 0, feedCd: 0, litT: 0 };
        for (let j = 0; j < FERN_SHELLS; j++) {
          const a = j / FERN_SHELLS * 6.283 + fe.yaw;
          dummy.position.set(p.x + Math.cos(a) * 0.35, H(p.x + Math.cos(a) * 0.35, p.z + Math.sin(a) * 0.35) + 0.02, p.z + Math.sin(a) * 0.35);
          dummy.rotation.set(0, a, 0); dummy.scale.setScalar(1); dummy.updateMatrix(); E.shellIM.setMatrixAt(fe.i * FERN_SHELLS + j, dummy.matrix);
        }
        E.ferns.push(fe);
      }
    });
    E.shellIM.instanceMatrix.needsUpdate = true;
    G.rng = rng0;
  }
  function fernsUpdate(dt, t) {
    E.fernMsgCd = (E.fernMsgCd || 0) - dt; E.fernFeedCd = (E.fernFeedCd || 0) - dt;
    for (const fe of E.ferns) {
      fe.openCd -= dt; fe.feedCd -= dt;
      const was = fe.lit; fe.lit = inBeam(fe.top);
      fe.litT = fe.lit ? 5 : fe.litT - dt; // после луча листья ещё немного остаются раскрытыми
      const want = fe.litT > 0 ? 1 : 0;
      fe.open = want > fe.open ? Math.min(1, fe.open + dt * 0.6) : Math.max(0, fe.open - dt * 0.25);
      if (fe.lit && !was && fe.open < 0.3 && E.fernMsgCd <= 0) { E.fernMsgCd = 40; E.emit('fern', 'open', fe.top, () => `${cap(G.nm('fern'))} разворачивает листья к свету прожектора`); }
      if (fe.open > 0.8) { // открытые моллюски манят светляков
        let came = false;
        for (const sh of E.shoals) if (!sh.range && sh.alarm <= 0 && !sh.follow && sh.n >= 3 && sh.c.distanceTo(fe.top) < FERN_CALL_R) { sh.goal.copy(fe.top); sh.gt = Math.max(sh.gt, 0.5); if (sh.c.distanceTo(fe.top) < 4) came = true; }
        if (came && E.fernFeedCd <= 0) { E.fernFeedCd = 60; E.emit('fern', 'mollusk', fe.top, () => `Под листьями ${G.nm('fern', 'gen')} открылись моллюски — к ним приплыли рыбы`); }
      }
      for (let j = 0; j < FERN_LEAVES; j++) {
        const a = j / FERN_LEAVES * 6.283 + fe.yaw, o = fe.open;
        dummy.position.copy(fe.p); dummy.rotation.set(0, a, 0, 'YXZ');
        dummy.rotateX(-(0.25 + 1.0 * o) + Math.sin(t * 1.2 + fe.ph + j) * 0.05 * o); // раскрытый лист ложится наружу
        dummy.scale.set(0.6 + 0.4 * o, 0.45 + 0.55 * o, 1); dummy.updateMatrix();
        E.fernIM.setMatrixAt(fe.i * FERN_LEAVES + j, dummy.matrix);
      }
    }
    E.fernIM.instanceMatrix.needsUpdate = true;
  }

  /* ======================= ОБЩЕЕ ======================= */
  E.init = function (scene) { initVeils(scene); initFish(scene); initStations(scene); initAnemones(scene); initKelp(scene); initSwarms(scene); initClouds(scene); initCoins(scene); initGrot(scene); initSkalnik(scene); initMasons(scene); initOrgans(scene); initCushions(scene); initBladders(scene); initFans(scene); initFerns(scene); initPreds(scene); initGrazers(scene); initEels(scene); initRays(scene); initRemoras(scene); };

  E.update = function (dt, t) {
    const S = G.Ship;
    E.veils.forEach(v => veilUpdate(v, dt, t));
    E.shipHidden = !!E.shipInk || E.veils.some(vl => Math.hypot(S.center.x - vl.p.x, S.center.z - vl.p.z) < vl.r + 6 && S.center.y < vl.p.y + 1 && S.center.y > vl.p.y - vl.len - 6);
    stationsUpdate(dt, t);
    updateBeam(); E.anemones.forEach(hv => anemoneUpdate(hv, dt, t));
    if (E.hvTentIM) { E.hvTentIM.instanceMatrix.needsUpdate = true; E.pestrIM.instanceMatrix.needsUpdate = true; }
    if (E.kelpIM) {
      E.urchins.forEach(u => { urchinUpdate(u, dt, t); urchinRender(u, t); });
      E.urchBodyIM.instanceMatrix.needsUpdate = true; E.urchSpIM.instanceMatrix.needsUpdate = true;
      kelpUpdate(dt); if (E.crab) crabUpdate(E.crab, dt, t);
      if (E.skalnik) { skUpdate(E.skalnik, dt, t); skRender(E.skalnik, t); }
    }
    if (E.rdIM) {
      E.flare = 0; E.flareSw = null;
      E.swarms.forEach(sw => { swarmUpdate(sw, dt, t); swarmRender(sw, t); if (sw.glow > E.flare) { E.flare = sw.glow; E.flareSw = sw; } });
      E.rdIM.instanceMatrix.needsUpdate = true; if (E.rdIM.instanceColor) E.rdIM.instanceColor.needsUpdate = true;
      E.rdGlow.geometry.attributes.position.needsUpdate = true; E.rdGlow.geometry.attributes.color.needsUpdate = true;
    }
    if (E.plPts) {
      E.shipWake = 0;
      E.clouds.forEach(cl => { cloudUpdate(cl, dt, t); E.shipWake = Math.max(E.shipWake, cl.ship); });
      E.plPts.geometry.attributes.position.needsUpdate = true; E.plPts.geometry.attributes.color.needsUpdate = true;
    }
    if (E.coinIM) { coinsUpdate(dt, t); coinsRender(t); }
    if (E.grot) grotUpdate(E.grot, dt, t);
    if (E.organMesh) organsUpdate(dt, t);
    if (E.pdIM) cushionsUpdate(dt, t);
    if (E.pzBulbIM) bladdersUpdate(dt, t);
    if (E.fanIM) currentUpdate(dt, t);
    if (E.fernIM) fernsUpdate(dt, t);
    updateFish(dt, t);
    E.preds.forEach((p, i) => { predUpdate(p, dt); predRender(p, i, t); });
    E.predSegIM.instanceMatrix.needsUpdate = true; E.predDotIM.instanceMatrix.needsUpdate = true;
    E.grazers.forEach(gz => grazerUpdate(gz, dt, t));
    E.eels.forEach((el, i) => { eelUpdate(el, dt, t); eelRender(el, i, t); });
    E.eelIM.instanceMatrix.needsUpdate = true; E.eelDotIM.instanceMatrix.needsUpdate = true;
    E.rays.forEach(r => rayUpdate(r, dt, t));
    if (E.kmCrownIM) masonsUpdate(dt, t);
    if (E.rmIM) remorasUpdate(dt, t);
    if (G.Silt.pts) G.Silt.update(dt, t);
    if (G.Echo) G.Echo.update(dt);
  };

  E.scanTargets = function () {
    const L = [];
    E.shoals.forEach(sh => { if (sh.n >= 3) L.push({ sp: 'fish', pos: sh.c, r: 2.5 }); });
    E.preds.forEach(p => L.push({ sp: 'pred', pos: p.p, r: 2.5 }));
    const ec = G.Echo && G.Echo.target(); if (ec) L.push(ec);
    E.veils.forEach(v => L.push({ sp: 'veil', pos: v.scanP, r: 7 }));
    E.grazers.forEach(gz => { if (gz.alive) L.push({ sp: 'grazer', pos: gz.p, r: 1.4 }); });
    E.eels.forEach(el => L.push({ sp: 'eel', pos: el.p, r: 1.3 }));
    E.rays.forEach(r => L.push({ sp: 'ray', pos: r.p, r: 7 }));
    E.stations.forEach(st => L.push({ sp: 'ognevka', pos: st.top, r: 1.6 }));
    E.preds.forEach(p => { if (p.leech) L.push({ sp: 'leech', pos: p.leechP, r: 0.7 }); });
    E.urchins.forEach(u => { if (u.alive) L.push({ sp: 'ezh', pos: u.p, r: 0.6 }); });
    if (E.crab) L.push({ sp: 'krab', pos: E.crab.p, r: 0.9 });
    E.swarms.forEach(sw => L.push({ sp: 'raduzh', pos: sw.c, r: RD_R }));
    E.clouds.forEach(cl => L.push({ sp: 'plankton', pos: cl.c, r: 4 }));
    E.schools.forEach(sc => { const a = sc.members.filter(c => c.alive); if (a.length >= 3) L.push({ sp: 'monet', pos: a[0].p, r: 1.2 }); });
    if (E.grot) L.push({ sp: 'grot', pos: E.grot.back, r: 3 });
    E.fans.forEach(f => L.push({ sp: 'fan', pos: f.top, r: 1.4 }));
    E.ferns.forEach(fe => L.push({ sp: 'fern', pos: fe.top, r: 0.7 }));
    E.cushions.forEach(cu => L.push({ sp: 'cushion', pos: cu.top, r: 1.3 }));
    E.bladders.forEach(bl => L.push({ sp: 'bladder', pos: bl.stems[0].top, r: 0.9 }));
    E.masons.forEach(col => L.push({ sp: 'kamen', pos: col.worms[KM_N >> 1].top, r: 1.5 }));
    E.organs.forEach(og => L.push({ sp: 'organ', pos: og.top, r: 1.6 }));
    E.remoras.forEach(rm => L.push({ sp: 'prisoska', pos: rm.p, r: 0.4, noSonar: true }));
    if (E.skalnik) { const h = E.skalnik.camo >= 0.5; L.push({ sp: 'skalnik', pos: E.skalnik.p, r: 1, hidden: h, noSonar: h }); } // замаскированного не видно ни в прицеле, ни на сонаре
    E.glazuns.forEach(gz => L.push({ sp: 'glazun', pos: gz.eyeC, r: 0.6, noSonar: true })); // на сонаре не виден
    E.anemones.forEach(hv => { L.push({ sp: 'hvaten', pos: hv.top, r: 1.2 }); L.push({ sp: 'pestr', pos: hv.pc, r: 0.6 }); });
    return L;
  };

  E.onPing = function (pos) {
    E.lastPing = G.Game.t; let heard = false;
    if (G.Echo) G.Echo.onPing(pos);
    E.preds.forEach(pr => {
      if (pr.state === 'charge' || pr.state === 'retreat' || pr.state === 'flee') return;
      const d = pr.p.distanceTo(pos);
      if (d < 150) { pr.state = 'investigate'; pr.goal.copy(pos); pr.timer = 25; if (d < 110) heard = true; }
    });
    if (heard) E.emit('pred', 'ping', pos, () => `${cap(G.nm('pred'))} услышал сонар и плывёт на звук`);
    coinsPing(pos);
  };

  E.onZap = function () {
    const S = G.Ship;
    remorasZap();
    const sk = E.skalnik;
    if (sk && (sk.state === 'thief' || sk.state === 'loot') && sk.p.distanceTo(S.center) < 20 * G.Power.k('zap')) { // разряд — бросить добычу
      if (sk.loot) { const s = sk.loot; sk.loot = null; G.Manip.drop(s, tv.copy(sk.p)); E.emit('skalnik', 'drop', sk.p, () => `Разряд спугнул ${G.nm('skalnik', 'acc')}: он бросил образец`); }
      sk.state = 'back'; sk.cd = 30; sk.reveal = 4;
    }
    if (E.latched) {
      const el = E.latched; el.state = 'flee'; el.cd = 40; E.latched = null;
      E.emit('eel', 'zap', S.front, () => `Разряд сбросил ${G.nm('eel', 'acc')} с корпуса`);
    }
    E.preds.forEach(pr => {
      if (pr.p.distanceTo(S.center) < 20 * G.Power.k('zap')) { // радиус разряда — от доли в реакторе
        pr.state = 'flee'; pr.timer = 8; pr.cd = 30;
        tv.copy(pr.p).sub(S.center); if (tv.lengthSq() < 0.01) tv.set(1, 0, 0);
        pr.goal.copy(pr.p).add(tv.normalize().multiplyScalar(50)); pr.goal.y = Math.min(pr.goal.y, -6);
        E.emit('pred', 'zap', pr.p, () => `Разряд отпугнул ${G.nm('pred', 'acc')}`);
      }
    });
  };

  E.reset = function () {
    if (E.latched) { E.latched.state = 'flee'; E.latched.cd = 40; E.latched = null; }
    E.preds.forEach((pr, i) => { pr.p.copy(pr.p0); pr.goal.copy(pr.p0); pr.v.set(0, 0, 1); pr.segs.forEach((sg, k) => sg.copy(pr.p0).z -= k * 0.6); pr.state = 'patrol'; pr.timer = 0; pr.cd = 30; pr.target = null; setLeech(pr, i === 0); pr.leechCd = G.rr(90, 160); pr.truceCd = 0; pr.angryCd = 0; pr.flareCd = 0; });
    E.stations.forEach(st => { st.busy = null; st.work = 0; });
    E.anemones.forEach(hv => { hv.open = 1; hv.lit = false; hv.digest = 0; hv.lure = null; hv.lureT = 0; hv.lureCd = G.rr(4, 12); hv.leftT = 0; hv.hideCd = 0; hv.msgCd = 0; });
    E.groves.forEach(gr => { gr.msgCd = 0; gr.grazeCd = 0; gr.stalks.forEach((s, k) => { s.f = 1; s.eater = null; s.drawn = 1; setKelp(gr, k); }); gr.cover = 1; });
    if (E.kelpIM) { E.kelpIM.instanceMatrix.needsUpdate = true; E.kelpIM.instanceColor.needsUpdate = true; }
    E.urchins.forEach(urchSpawn);
    E.swarms.forEach(sw => { sw.glow = 0; sw.lit = false; sw.flareCd = 0; sw.fadeCd = 0; });
    E.flare = 0; E.flareSw = null;
    E.clouds.forEach(cl => { cl.glow.fill(0); cl.ship = 0; cl.slowT = 0; cl.wakeCd = cl.slowCd = cl.predCd = 0; });
    E.shipWake = 0;
    E.schools.forEach(sc => { sc.scatter = 0; sc.scatCd = 0; sc.grazeCd = G.rr(5, 15); });
    E.glazuns.forEach(gz => { gz.cd = G.rr(8, 20); gz.lunge = 0; gz.lit = false; gz.eyesCd = 0; });
    E.coins.forEach(coinSpawn);
    const sk = E.skalnik;
    if (sk) { sk.p.copy(sk.home); sk.v.set(0, 0, 0); sk.state = 'rock'; sk.timer = 0; sk.cd = 20; sk.curCd = 0; sk.camo = 1; sk.reveal = 0; sk.lit = false; sk.mimicCd = 0; sk.seen = false; sk.loot = null; if (sk.carryM) sk.carryM.visible = false; }
    const gt = E.grot;
    if (gt) { gt.p.copy(gt.route[0]); gt.wp = 1; gt.yaw = 0; gt.shy = 0; gt.shyCd = 0; gt.lift = 1; gt.hideCd = 0; gt.driftCd = 0; grotPlace(gt, 0, 0); }
    const cr = E.crab;
    if (cr) { cr.p.copy(cr.den); cr.dir.copy(cr.out); cr.state = 'den'; cr.hunger = 0.3; cr.target = null; cr.timer = 0; cr.spines = 3; cr.guardCd = 0; cr.pinchCd = 0; cr.raise = 0; cr.scared = 0; crabSpines(cr); }
    /* хищники, рыбы и ледокрылы — на исходные места (после гротовика: стая на его спине): тесты не зависят от предыдущих */
    E.shoals.forEach(sh => { sh.alarm = 0; sh.follow = null; sh.followT = 0; sh.gt = 0; sh.fleeCd = 0; sh.threat = null; sh.goal.copy(sh.home); sh.c.copy(sh.home); });
    E.fish.forEach(f => { f.alive = true; f.t = 0; f.p.copy(f.s.home).add(f.o); f.v.copy(f.v0); });
    E.rays.forEach(r => { r.ang = r.ang0; r.init = false; r.fcd = 10; r.nT = 0; });
    E.remoras.forEach(rm => { rm.state = 'ray'; rm.ray = E.rays[Math.floor(rm.i / RM_PER_RAY)]; rm.slot = -1; rm.cd = 0; });
    E.hullRemoras = 0; E.rmHopCd = 0; E.rmEelCd = 0; E.rmRideCd = 0;
    E.masons.forEach(col => { col.hideCd = 0; col.warnCd = 0; col.hidden = 0; col.worms.forEach(w => { w.ext = 1; w.quiet = 0; }); });
    E.organs.forEach(og => { og.maskCd = 0; og.humCd = 0; }); E.shipMasked = null;
    E.cushions.forEach(cu => { cu.squeeze = 0; cu.cd = 0; cu.ink = 0; cu.hideCd = 0; }); E.shipInk = null;
    E.bladders.forEach((bl, i) => { bl.ripe = 0.3 + i * 0.2; bl.life = 0; bl.feedCd = 0; bl.sc.feed = null; });
    E.curIdx = 0; E.curAng = E.curTarget = CUR_DIRS[0]; E.curT = CUR_PERIOD; E.fanCd = 0; E.fanReadCd = 0; E.ognFanCd = 0; E.current.set(Math.sin(E.curAng), 0, Math.cos(E.curAng)).multiplyScalar(CUR_SPEED);
    E.fans.forEach(f => { f.yaw = E.curAng; });
    E.ferns.forEach(fe => { fe.open = 0; fe.lit = false; fe.litT = 0; }); E.fernMsgCd = 0; E.fernFeedCd = 0;
  };
})(window.G);
