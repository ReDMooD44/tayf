import 'engine.dart';

/// Elle tasarlanmış altı bölüm. Açı: derece, ekranda saat yönünde
/// (0° = sağ, 90° = aşağı). prism.a = tepe yönü · mirror.a = yansıtıcı
/// yüzün normali · lens.a = optik eksen.
final List<Level> levels = [
  Level(
    id: 'ilk',
    name: 'ilk ışık',
    desc: 'aynalarla beyaz demeti köşeden döndür',
    tip: 'parçayı alttan sürükle · turuncu tutamaçla döndür',
    inv: {'mirror': 2},
    par: 2,
    emitters: [Emitter(x: 96, y: 720, a: 0)],
    walls: [
      [30, 452, 560, 24]
    ],
    targets: [Target(x: 230, y: 230, kind: 'white')],
    sol: [
      Piece(type: 'mirror', x: 740, y: 720, a: 225),
      Piece(type: 'mirror', x: 740, y: 230, a: 135),
    ],
  ),
  Level(
    id: 'tayf',
    name: 'tayf',
    desc: 'beyazı prizmayla renklerine ayır',
    tip: 'renkli algılayıcılar saf renk ister — beyaz ışık onları doldurmaz',
    inv: {'prism': 1},
    par: 1,
    emitters: [Emitter(x: 96, y: 280, a: 0)],
    walls: [
      [30, 520, 300, 24]
    ],
    targets: [
      Target(x: 720, y: 572, kind: 'red'),
      Target(x: 720, y: 690, kind: 'blue'),
    ],
    sol: [Piece(type: 'prism', x: 320, y: 295, a: 280)],
  ),
  Level(
    id: 'odak',
    name: 'odak',
    desc: 'dağılmış renkleri mercekle yeniden birleştir',
    tip: 'beyaz algılayıcı sıcak, orta ve soğuk bantları aynı anda ister',
    inv: {'lens': 1},
    par: 1,
    emitters: [Emitter(x: 96, y: 285, a: 0)],
    blocks: [Block(kind: 'prism', x: 250, y: 300, a: 280, side: 92)],
    targets: [Target(x: 700, y: 620, kind: 'white', need: 6)],
    sol: [Piece(type: 'lens', x: 397, y: 393, a: 39.5)],
  ),
  Level(
    id: 'tir',
    name: 'tam yansıma',
    desc: 'ayna yok: camın içinden yansıt',
    tip: 'prizmanın yüzüne dik giren ışık renklerine ayrılmadan iç yüzeyden yansır',
    inv: {'prism': 2},
    par: 2,
    emitters: [Emitter(x: 96, y: 740, a: 0)],
    targets: [Target(x: 590, y: 200, kind: 'white', need: 6)],
    sol: [
      Piece(type: 'prism', x: 559, y: 710, a: 359.9),
      Piece(type: 'prism', x: 706, y: 475, a: 300.3),
    ],
  ),
  Level(
    id: 'goz',
    name: 'göz',
    desc: 'tekilliğin çevresinde ışığı bük',
    tip: 'halkanın içine giren ışık merkeze doğru eğrilir; çekirdeğe düşen yutulur',
    inv: {'prism': 1, 'mirror': 1, 'lens': 1},
    par: 3,
    emitters: [Emitter(x: 96, y: 150, a: 0), Emitter(x: 96, y: 790, a: 0)],
    wells: [Well(x: 470, y: 450, r: 125, rh: 22, core: 34, g: 3.5)],
    walls: [
      [30, 560, 440, 24],
      [30, 370, 290, 24]
    ],
    targets: [
      Target(x: 150, y: 450, kind: 'white', need: 5),
      Target(x: 760, y: 700, kind: 'amber', need: 4),
    ],
    sol: [
      Piece(type: 'mirror', x: 716, y: 790, a: 210.6),
      Piece(type: 'lens', x: 426, y: 423, a: 2.9),
      Piece(type: 'prism', x: 267, y: 163, a: 275.3),
    ],
  ),
  // İki kuyunun arasından geçen ışın kaotiktir: eski yerleşimde mavi kolu
  // yakalayan açı aralığı 0,6° idi ve bölüm pratikte çözülemiyordu. Bu düzen,
  // çözümün ±4 px / ±1,6° sarsıntıya %95 dayandığı doğrulanarak seçildi.
  Level(
    id: 'ikiz',
    name: 'ikiz tekillik',
    desc: 'iki kuyunun arasından saf mavi geçir',
    tip: 'iki kuyu tayfı yelpaze gibi açar; mavi kolu aynayla algılayıcıya düşür',
    inv: {'prism': 1, 'mirror': 1},
    par: 2,
    emitters: [Emitter(x: 389, y: 96, a: 90)],
    wells: [
      Well(x: 402, y: 559, r: 126, rh: 21, core: 32, g: 3.49),
      Well(x: 543, y: 300, r: 117, rh: 21, core: 32, g: 3.02),
    ],
    targets: [Target(x: 457, y: 738, kind: 'blue', need: 1.8)],
    sol: [
      Piece(type: 'prism', x: 372, y: 369, a: 161.1),
      Piece(type: 'mirror', x: 596, y: 730, a: 209.5),
    ],
  ),
];
