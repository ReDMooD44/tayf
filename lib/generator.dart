import 'dart:math' as math;
import 'dart:typed_data';
import 'engine.dart';

/// Bölüm üreteci — JS sürümünün birebir Dart karşılığı.
///
/// Yöntem: önce arena (duvar · kuyu · sabit blok) kurulur, sonra parçalar
/// ışının GERÇEK yolu üzerine zincirleme konur, algılayıcılar da ışığın
/// gerçekten düştüğü noktalara. Çözülebilirlik böylece tasarım gereği garanti
/// olur; ardından denetimlerle doğrulanır.

int _u32(int v) => v & 0xFFFFFFFF;

/// Math.imul karşılığı — web'de (int == double) de kesin kalsın diye
/// 16-bit parçalara bölerek çarpar.
int _imul(int a, int b) {
  final ah = (a >>> 16) & 0xffff, al = a & 0xffff;
  final bh = (b >>> 16) & 0xffff, bl = b & 0xffff;
  return _u32(al * bl + (((ah * bl + al * bh) & 0xffff) << 16));
}

/// Tohumlu rastgele sayı üreteci (mulberry32).
double Function() mulberry(int seed) {
  var a = _u32(seed);
  return () {
    a = _u32(a + 0x6D2B79F5);
    var t = _imul(a ^ (a >>> 15), a | 1);
    t = _u32(t ^ _u32(t + _imul(t ^ (t >>> 7), t | 61)));
    return _u32(t ^ (t >>> 14)) / 4294967296;
  };
}

const List<String> genA = [
  'dar', 'eğik', 'sessiz', 'kırık', 'derin', 'ters', 'soğuk', 'uzak', 'kapalı', 'çift', //
  'ince', 'yüksek', 'gizli', 'ağır', 'dağınık', 'keskin', 'donuk', 'çıplak', 'yalın', 'uzun'
];
const List<String> genB = [
  'geçit', 'eşik', 'yay', 'koridor', 'kavis', 'düğüm', 'oda', 'kol', 'yarık', 'halka', //
  'eksen', 'çatı', 'kenar', 'baca', 'aralık', 'köşe', 'oluk', 'boşluk', 'kuyu', 'perde'
];

const double gbLo = 150, gbHi = W - 150;

/// Üretilen bölümler elle tasarlanan 6 bölümden SONRA başlar (n >= 7).
/// Zorluk hiçbir yerde geri düşmez.
const List<List<String>> combo2 = [
  ['prism', 'mirror'],
  ['prism', 'lens'],
  ['mirror', 'lens'],
  ['prism', 'prism'],
  ['mirror', 'mirror'],
  ['lens', 'mirror'],
];

/// Mercek tek başına ışığı yönlendirmez, bu yüzden onu "gerekli" kılmak zor:
/// her üçlüde en çok bir mercek var ve zincirde her zaman prizmadan sonraya konur.
const List<List<String>> combo3 = [
  ['prism', 'mirror', 'lens'],
  ['prism', 'prism', 'mirror'],
  ['mirror', 'mirror', 'prism'],
  ['prism', 'mirror', 'mirror'],
  ['mirror', 'prism', 'lens'],
  ['prism', 'prism', 'lens'],
  ['mirror', 'mirror', 'lens'],
];

class Tier {
  List<String> set;
  int pieces, floor, targets, walls, wells;
  bool block, tilt, color;
  Tier({
    required this.set,
    required this.pieces,
    this.floor = 2,
    required this.targets,
    required this.walls,
    required this.wells,
    required this.block,
    required this.tilt,
    this.color = true,
  });
  Tier copy({List<String>? set, int? pieces, int? targets, int? walls, int? wells, bool? block}) => Tier(
        set: set ?? this.set,
        pieces: pieces ?? this.pieces,
        floor: floor,
        targets: targets ?? this.targets,
        walls: walls ?? this.walls,
        wells: wells ?? this.wells,
        block: block ?? this.block,
        tilt: tilt,
        color: color,
      );
}

Tier genTier(int n) {
  final three = n >= 10;
  final set = three ? combo3[n % combo3.length] : combo2[n % combo2.length];
  return Tier(
    set: set,
    pieces: set.length,
    targets: n < 12 ? 2 : 3,
    walls: n < 8 ? 0 : (n < 13 ? 1 : 2),
    wells: n >= 14 ? 1 : 0,
    block: n >= 18,
    tilt: n >= 9,
  );
}

/// Zorluk merdiveni: önce arena ve hedef sayısı gevşer, parça sayısı en son.
List<Tier> genLadder(Tier b) {
  final out = <Tier>[b];
  final plain = b.copy(walls: 0, wells: 0, block: false);
  if (b.walls > 0 || b.wells > 0 || b.block) out.add(plain);
  if (b.targets > 1) {
    out.add(b.copy(targets: b.targets - 1));
    out.add(plain.copy(targets: b.targets - 1));
  }
  if (b.pieces > b.floor) {
    out.add(plain.copy(set: b.set.sublist(0, b.floor), pieces: b.floor, targets: 1));
  }
  return out;
}

/// coarse: arama için seyrek demet (7 alt ışın) — ~3x hızlı.
/// Doğrulama ve eşik ölçümü her zaman gerçek demetle (25) yapılır.
const int genCoarseN = 7;
const double genCoarseScale = genCoarseN / 25;

class Probe {
  final List<Target> ts;
  final List<double>? path;
  Probe(this.ts, this.path);
}

Probe genProbe(Level l, List<Piece> pieces, List<Target> targets, bool rec, [bool coarse = false]) {
  final ts = targets.map((t) => t.copy()).toList();
  final ws = l.wells.map((w) => w.copy()).toList();
  final src = coarse
      ? (Level(
          id: l.id,
          name: l.name,
          emitters: l.emitters.map((e) => Emitter(x: e.x, y: e.y, a: e.a, n: genCoarseN, w: e.w, mono: e.mono)).toList(),
          wells: l.wells,
          walls: l.walls,
          blocks: l.blocks,
        ))
      : l;
  pathRec = rec ? <double>[] : null;
  trace(buildScene(src, pieces, ts, ws));
  final p = pathRec;
  pathRec = null;
  evalTargets(ts);
  return Probe(ts, p);
}

bool genSolved(List<Target> ts) => ts.isNotEmpty && ts.every((t) => t.fill >= 1);

bool inWall(List<List<double>> walls, double x, double y, double pad) {
  for (final w in walls) {
    if (x > w[0] - pad && x < w[0] + w[2] + pad && y > w[1] - pad && y < w[1] + w[3] + pad) return true;
  }
  return false;
}

bool inWell(List<Well> wells, double x, double y, double pad) {
  for (final w in wells) {
    if (math.sqrt((x - w.x) * (x - w.x) + (y - w.y) * (y - w.y)) < w.r + pad) return true;
  }
  return false;
}

class Spot {
  final double x, y, dx, dy, i;
  Spot(this.x, this.y, this.dx, this.dy, this.i);
}

/// Işın yolu üzerindeki kullanılabilir noktalar.
List<Spot> genSpots(List<double>? path, Level l, List<Piece> pieces, Emitter em, double minPiece) {
  final out = <Spot>[];
  if (path == null) return out;
  for (var i = 0; i < path.length; i += 5) {
    final x1 = path[i], y1 = path[i + 1];
    final dx = path[i + 2] - x1, dy = path[i + 3] - y1;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 14) continue;
    for (var u = 0.25; u <= 0.81; u += 0.27) {
      final x = x1 + dx * u, y = y1 + dy * u;
      if (x < gbLo || x > gbHi || y < gbLo || y > gbHi) continue;
      if (math.sqrt((x - em.x) * (x - em.x) + (y - em.y) * (y - em.y)) < 170) continue;
      if (inWall(l.walls, x, y, 56) || inWell(l.wells, x, y, 26)) continue;
      var ok = true;
      for (final p in pieces) {
        if (math.sqrt((x - p.x) * (x - p.x) + (y - p.y) * (y - p.y)) < minPiece) {
          ok = false;
          break;
        }
      }
      if (ok) out.add(Spot(x, y, dx / len, dy / len, path[i + 4]));
    }
  }
  return out;
}

double _norm360(double a) => ((a % 360) + 360) % 360;
double _clamp(double v, double a, double b) => v < a ? a : (v > b ? b : v);
double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _r1(double v) => (v * 10).round() / 10;

Piece genPiece(String kind, Spot s, double Function() r) {
  final dirA = math.atan2(s.dy, s.dx) / DEG;
  final sg = r() < 0.5 ? -1 : 1;
  double a;
  if (kind == 'mirror') {
    a = dirA + 180 + sg * (28 + r() * 44); // normal gelen ışına dönük
  } else if (kind == 'prism') {
    a = dirA + sg * (60 + r() * 50); // ışın yan yüze girsin
  } else {
    a = dirA + (r() * 70 - 35); // optik eksen ışın boyunca
  }
  final off = r() * 30 - 15;
  return Piece(
    type: kind,
    a: _r1(_norm360(a)),
    x: _clamp(s.x - s.dy * off, gbLo, gbHi),
    y: _clamp(s.y + s.dx * off, gbLo, gbHi),
  );
}

/// Bir türün ham gücü: eşik bununla belirlenir (fill = raw / need).
double rawFor(Float32List bins, String kind) {
  double tot = 0;
  for (var i = 0; i < NW; i++) {
    tot += bins[i];
  }
  if (tot <= 0) return 0;
  if (kind == 'white') {
    final cool = (bins[0] + bins[1] + bins[2] + bins[3]) / 4;
    final mid = (bins[4] + bins[5] + bins[6]) / 3;
    final warm = (bins[7] + bins[8] + bins[9] + bins[10] + bins[11]) / 5;
    return math.min(cool, math.min(mid, warm));
  }
  final bd = bands[kind]!;
  double s = 0;
  for (var i = bd[0]; i <= bd[1]; i++) {
    s += bins[i];
  }
  return s / (bd[1] - bd[0] + 1) * _clamp01((s / tot - 0.36) / 0.2);
}

double purityFor(Float32List bins, String kind) {
  double tot = 0;
  for (var i = 0; i < NW; i++) {
    tot += bins[i];
  }
  if (tot <= 0) return 0;
  final bd = bands[kind]!;
  double s = 0;
  for (var i = bd[0]; i <= bd[1]; i++) {
    s += bins[i];
  }
  return s / tot;
}

/// Cılız ışıkla dolan algılayıcı istemiyoruz.
double needFloor(String k) => k == 'white' ? 2 : 1;

class Classified {
  final String kind;
  final double need;
  Classified(this.kind, this.need);
}

/// Ölçülen tayftan algılayıcı türü + eşik; eşik 1.55x pay bırakır.
Classified? genClassify(Float32List bins, bool preferColor, double Function() r, [double scale = 1]) {
  final opts = <List<dynamic>>[]; // [kind, raw, weight]
  final wr = rawFor(bins, 'white');
  if (wr >= 4 * scale) opts.add(['white', wr, preferColor ? 1 : 4]);
  for (final k in bands.keys) {
    final raw = rawFor(bins, k);
    if (purityFor(bins, k) >= 0.55 && raw >= 1.6 * scale) {
      opts.add([k, raw, preferColor ? 4 : 1]);
    }
  }
  if (opts.isEmpty) return null;
  var sum = 0;
  for (final o in opts) {
    sum += o[2] as int;
  }
  var rr = r() * sum;
  var ch = opts.last;
  for (final o in opts) {
    rr -= o[2] as int;
    if (rr <= 0) {
      ch = o;
      break;
    }
  }
  return Classified(ch[0] as String, _r1((ch[1] as double) / 1.55));
}

String genTip(Level l) {
  if (l.wells.isNotEmpty) return 'kuyunun halkasına giren ışık merkeze doğru eğrilir';
  if (l.targets.any((t) => t.kind != 'white')) return 'renkli algılayıcı saf renk ister — beyaz ışık doldurmaz';
  if (l.targets.any((t) => t.kind == 'white')) return 'beyaz algılayıcı sıcak, orta ve soğuk bantları birlikte ister';
  return 'turuncu tutamaçla döndür · ince ayar düğmeleriyle 0,1°';
}

class _Cand {
  final double x, y;
  final String kind;
  final double need, raw;
  final List<int> dep;
  _Cand(this.x, this.y, this.kind, this.need, this.raw, this.dep);
}

Level? genTry(int n, double Function() r, [Tier? forceTier]) {
  final t = forceTier ?? genTier(n);
  int ri(int a, int b) => a + (r() * (b - a + 1)).floor();
  double rf(double a, double b) => a + r() * (b - a);
  T pick<T>(List<T> a) => a[(r() * a.length).floor()];

  final edge = ri(0, 3);
  final tilt = t.tilt ? rf(-9, 9) : 0.0;
  final em = edge == 0
      ? Emitter(x: 96, y: ri(220, 680).toDouble(), a: _norm360(tilt))
      : edge == 1
          ? Emitter(x: W - 96, y: ri(220, 680).toDouble(), a: _norm360(180 + tilt))
          : edge == 2
              ? Emitter(x: ri(220, 680).toDouble(), y: 96, a: _norm360(90 + tilt))
              : Emitter(x: ri(220, 680).toDouble(), y: W - 96, a: _norm360(270 + tilt));

  final l = Level(
    id: 'e$n',
    gen: true,
    n: n,
    name: '${pick(genA)} ${pick(genB)}',
    emitters: [em],
  );

  // arena öğeleri çeşitlilik için olasılıklı
  final nWalls = t.walls > 0 ? ri(0, t.walls) : 0;
  final nWells = (t.wells > 0 && r() < 0.7) ? t.wells : 0;

  // duvarlar — yayıcının ilk 160px'ini kapatmasın
  for (var k = 0; k < nWalls; k++) {
    for (var a = 0; a < 14; a++) {
      final ln = ri(200, 470).toDouble();
      final horiz = r() < 0.5;
      final w = horiz
          ? [r() < 0.5 ? FRAME.toDouble() : W - FRAME - ln, ri(250, 650).toDouble(), ln, 24.0]
          : [ri(250, 650).toDouble(), r() < 0.5 ? FRAME.toDouble() : W - FRAME - ln, 24.0, ln];
      final cx = w[0] + w[2] / 2 - em.x, cy = w[1] + w[3] / 2 - em.y;
      if (math.sqrt(cx * cx + cy * cy) < 150) continue;
      final ca = math.cos(em.a * DEG), sa = math.sin(em.a * DEG);
      var bad = false;
      for (var d = 0; d <= 160; d += 20) {
        if (!bad && inWall([w], em.x + ca * d, em.y + sa * d, 22)) bad = true;
      }
      if (bad) continue;
      l.walls.add(w);
      break;
    }
  }
  // kuyular
  for (var k = 0; k < nWells; k++) {
    for (var a = 0; a < 16; a++) {
      final x = ri(300, 600).toDouble(), y = ri(300, 600).toDouble();
      final rr = ri(105, 130).toDouble();
      if (math.sqrt((x - em.x) * (x - em.x) + (y - em.y) * (y - em.y)) < 230 ||
          inWall(l.walls, x, y, rr) ||
          inWell(l.wells, x, y, rr)) {
        continue;
      }
      l.wells.add(Well(x: x, y: y, r: rr, rh: 21, core: 32, g: rf(2.8, 3.6)));
      break;
    }
  }
  // sabit prizma: ışığı baştan ayrıştırır
  if (t.block && r() < 0.6) {
    final sp = genSpots(genProbe(l, const [], const [], true, true).path, l, const [], em, 0)
        .where((s) => math.sqrt((s.x - em.x) * (s.x - em.x) + (s.y - em.y) * (s.y - em.y)) < 330)
        .toList();
    if (sp.isNotEmpty) {
      final s = pick(sp);
      l.blocks.add(Block(
        kind: 'prism',
        x: s.x,
        y: s.y,
        side: 92,
        a: _r1(_norm360(math.atan2(s.dy, s.dx) / DEG + (r() < 0.5 ? -1 : 1) * rf(60, 110))),
      ));
    }
  }

  // parçaları ışın yoluna zincirle: her parça bir öncekinin açtığı yola konur
  final pieces = <Piece>[];
  List<Spot> fresh(List<Spot> list, List<Spot>? old) => old == null
      ? list
      : list
          .where((s) => old.every((o) => math.sqrt((s.x - o.x) * (s.x - o.x) + (s.y - o.y) * (s.y - o.y)) > 45))
          .toList();
  List<Spot>? prevSpots;
  final order = List<String>.from(t.set); // tür kümesi sabit, sıra karışık
  for (var i = order.length - 1; i > 0; i--) {
    final j = (r() * (i + 1)).floor();
    final tmp = order[i];
    order[i] = order[j];
    order[j] = tmp;
  }
  // mercek dağılmış ışığa baksın
  order.sort((a, b) => (a == 'lens' ? 1 : 0) - (b == 'lens' ? 1 : 0));

  for (var i = 0; i < t.pieces; i++) {
    final now = genSpots(genProbe(l, pieces, const [], true, true).path, l, pieces, em, 130);
    if (now.isEmpty) return null;
    // önceki parça yeni bir yol açmadıysa zincir kopuktur: ucuzken bırak
    final cand = fresh(now, prevSpots);
    if (cand.isEmpty) return null;
    Spot? bs;
    var bd = -1.0;
    for (var k = 0; k < 10; k++) {
      final s = pick(cand);
      var d = math.sqrt((s.x - em.x) * (s.x - em.x) + (s.y - em.y) * (s.y - em.y));
      for (final p in pieces) {
        d = math.min(d, math.sqrt((s.x - p.x) * (s.x - p.x) + (s.y - p.y) * (s.y - p.y)));
      }
      if (d > bd) {
        bd = d;
        bs = s;
      }
    }
    prevSpots = now;
    pieces.add(genPiece(order[i], bs!, r));
  }

  // algılayıcı adayları: son parçanın açtığı yolu yeğle
  final all = genSpots(genProbe(l, pieces, const [], true, true).path, l, pieces, em, 95);
  final fr = fresh(all, prevSpots);
  final cands = (fr.isNotEmpty ? fr : all).where((s) => !inWell(l.wells, s.x, s.y, 6)).toList();
  if (cands.isEmpty) return null;
  final sel = <Spot>[];
  for (var k = 0; k < cands.length * 2 && sel.length < 28; k++) {
    final c = cands[(r() * cands.length).floor()];
    if (sel.every((s) => math.sqrt((s.x - c.x) * (s.x - c.x) + (s.y - c.y) * (s.y - c.y)) > 150)) {
      sel.add(c);
    }
  }
  if (sel.isEmpty) return null;

  final asT = sel.map((c) => Target(x: c.x, y: c.y, kind: 'white', need: 1)).toList();
  final withP = genProbe(l, pieces, asT, false, true).ts;
  final noP = genProbe(l, const [], asT, false, true).ts; // bedava algılayıcıları ayıkla
  // her parça tek tek çıkarılıp bakılır: hangi aday hangi parçaya bağlı?
  final subP = <List<Target>>[];
  for (var i = 0; i < pieces.length; i++) {
    final sub = [
      for (var j = 0; j < pieces.length; j++)
        if (j != i) pieces[j]
    ];
    subP.add(genProbe(l, sub, asT, false, true).ts);
  }

  final good = <_Cand>[];
  final preferColor = t.color && (pieces.any((p) => p.type == 'prism') || l.blocks.isNotEmpty);
  for (var k = 0; k < withP.length; k++) {
    final tot = withP[k].total;
    if (noP[k].total > 0.3 * tot) continue; // parçalar olmadan da aydınlanıyor
    final dep = <int>[];
    // ucuz ön filtre; kesin güvenceyi aşağıdaki gereksizlik denetimi verir
    for (var i = 0; i < pieces.length; i++) {
      if (subP[i][k].total < 0.85 * tot) dep.add(i);
    }
    if (dep.isEmpty) continue;
    final cl = genClassify(withP[k].bins, preferColor, r, genCoarseScale);
    if (cl != null) {
      good.add(_Cand(sel[k].x.roundToDouble(), sel[k].y.roundToDouble(), cl.kind, cl.need, tot, dep));
    }
  }
  if (good.isEmpty) return null;
  // önce çok parçaya bağlı, sonra en parlak adaylar
  good.sort((a, b) => a.dep.length != b.dep.length ? b.dep.length - a.dep.length : (b.raw - a.raw).sign.toInt());

  final chosen = <_Cand>[];
  for (final g in good) {
    if (chosen.length >= t.targets) break;
    if (chosen.every((c) => math.sqrt((c.x - g.x) * (c.x - g.x) + (c.y - g.y) * (c.y - g.y)) > 155)) {
      chosen.add(g);
    }
  }
  // her parça en az bir algılayıcıya bağlı görünsün
  final cover = <int>{};
  for (final c in chosen) {
    cover.addAll(c.dep);
  }
  if (cover.length < pieces.length) return null;

  l.targets = chosen.map((c) => Target(x: c.x, y: c.y, kind: c.kind, need: c.need)).toList();
  l.sol = pieces.map((p) => Piece(type: p.type, x: p.x.roundToDouble(), y: p.y.roundToDouble(), a: p.a)).toList();

  /* --- ön eleme: kaba demetle, ucuz ---
     Eşikler genClassify'dan zaten kaba birimde geliyor; tekrar ölçeklenmemeli. */
  if (!genSolved(genProbe(l, l.sol, l.targets, false, true).ts)) return null;
  if (genSolved(genProbe(l, const [], l.targets, false, true).ts)) return null;
  for (var i = l.sol.length - 1; i >= 0 && l.sol.length > 1; i--) {
    final sub = [
      for (var j = 0; j < l.sol.length; j++)
        if (j != i) l.sol[j]
    ];
    if (genSolved(genProbe(l, sub, l.targets, false, true).ts)) l.sol = sub;
  }
  if (l.sol.length < pieces.length) return null;

  /* --- son onay: gerçek demetle --- */
  // eşikleri son parça kümesiyle yeniden ölç: 1.55x pay her bölümde aynı olsun
  final fin = genProbe(l, l.sol, l.targets, false).ts;
  for (var k = 0; k < l.targets.length; k++) {
    final tg = l.targets[k];
    final raw = rawFor(fin[k].bins, tg.kind);
    if (!(raw > 0)) return null;
    tg.need = _r1(raw / 1.55);
    if (tg.need! < needFloor(tg.kind)) return null;
  }
  if (!genSolved(genProbe(l, l.sol, l.targets, false).ts)) return null;
  if (genSolved(genProbe(l, const [], l.targets, false).ts)) return null;
  // kesin güvence: nihai eşiklerle, gerçek demette hiçbir parça çıkarılamamalı
  for (var i = 0; i < l.sol.length; i++) {
    final sub = [
      for (var j = 0; j < l.sol.length; j++)
        if (j != i) l.sol[j]
    ];
    if (genSolved(genProbe(l, sub, l.targets, false).ts)) return null;
  }
  var pass = 0;
  for (var k = 0; k < 5; k++) {
    final jit = l.sol
        .map((p) => Piece(type: p.type, x: p.x + rf(-4, 4), y: p.y + rf(-4, 4), a: p.a + rf(-1.6, 1.6)))
        .toList();
    if (genSolved(genProbe(l, jit, l.targets, false).ts)) pass++;
  }
  if (pass < 3) return null;

  for (final p in l.sol) {
    l.inv[p.type] = (l.inv[p.type] ?? 0) + 1;
  }
  // envanter tam gereken kadar: fazladan parça ancak dükkândan alınır
  l.par = l.sol.length;
  l.desc = '${l.par} parça · ${l.targets.length} algılayıcı';
  l.tip = genTip(l);
  // parça sayısı zorluğu belirler, sonra hedef sayısı, sonra dayanıklılık
  l.score = l.sol.length * 10 + l.targets.length * 4 + pass;
  return l;
}

/// Üreteç hiç sonuç vermezse: elle doğrulanmış köşe dönüşü, eşiği ölçülerek.
Level genFixed(int n) {
  final l = Level(
    id: 'e$n',
    gen: true,
    n: n,
    name: 'köşe',
    desc: '1 parça · 1 algılayıcı',
    tip: 'aynanın turuncu tutamacıyla açıyı ayarla',
    inv: {'mirror': 1},
    par: 1,
    emitters: [Emitter(x: 96, y: 720, a: 0)],
    targets: [Target(x: 740, y: 230, kind: 'white', need: 4)],
    sol: [Piece(type: 'mirror', x: 740, y: 720, a: 225)],
  );
  final m = genProbe(l, l.sol, l.targets, false).ts[0];
  final raw = rawFor(m.bins, 'white');
  if (raw > 0.1) l.targets[0].need = math.max(1, _r1(raw / 1.55));
  l.score = 0;
  return l;
}

/// Deneme sayısı SABİT, süreye bağlı değil: aynı numara her cihazda aynı
/// bölümü vermeli. Süre bütçesi kullanılsaydı yavaş bir telefon başka bölüm
/// üretirdi ve "günün bölümü herkese aynı" sözü tutmazdı.
const int triesPerRung = 110;

Level searchLevel(int n, int seed, Tier base) {
  final ideal = base.pieces * 10 + base.targets * 4 + 4;
  final ladder = genLadder(base);
  Level? best;
  var step = 0;
  var done = false;
  double Function() rng() => mulberry(_u32(seed + _imul(++step, 2246822519)));
  for (var r = 0; r < ladder.length && !done; r++) {
    // kademedeki tüm denemeler yapılır ve EN İYİ sonuç saklanır
    for (var k = 0; k < triesPerRung; k++) {
      final c = genTry(n, rng(), ladder[r]);
      if (c != null && (best == null || c.score > best!.score)) best = c;
      if (best != null && best!.score >= ideal) {
        done = true;
        break;
      }
    }
    if (best != null) break; // bulduysak daha kolay kademeye inme
  }
  return best ?? genFixed(n);
}

final Map<int, Level> endlessCache = {};

Level endlessLevel(int n) =>
    endlessCache[n] ??= searchLevel(n, _u32(_imul(n, 2654435761) ^ 0x9e3779b9), genTier(n));

/* ---------- günlük bölüm ----------
   Tarihten tohumlanır: aynı gün herkese aynı bölüm gelir.
   Seri yok, sayaç yok, kaçırınca kaybedilen bir şey yok. */

String todayKey([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

int dayIndex([DateTime? now]) {
  final d = now ?? DateTime.now();
  return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
}

Level? _dailyCache;
String _dailyKey = '';

Level dailyLevel() {
  final key = todayKey();
  final c = _dailyCache;
  if (c != null && _dailyKey == key) return c;
  final di = dayIndex();
  final l = searchLevel(di, _u32(_imul(di, 2654435761) ^ 0x85ebca6b), genTier(10 + di % 16));
  l.id = 'd$key';
  l.key = key;
  l.name = 'günün bölümü';
  _dailyCache = l;
  _dailyKey = key;
  return l;
}
