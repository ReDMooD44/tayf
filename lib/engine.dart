import 'dart:math' as math;
import 'dart:typed_data';

/// Spektral ışın motoru — index.html'deki JS motorunun birebir Dart karşılığı.
///
/// Sayısal eşitlik için JS'teki Float32Array kullanımları Float32List ile
/// korunur: geometri (P), ışın yığını ve algılayıcı kovaları 32-bit tutulur,
/// ara hesaplar JS'teki gibi 64-bit yapılır. Bu olmadan doldurma değerleri
/// orijinalden sapar.

const int W = 900;
const double DEG = math.pi / 180;
const int FRAME = 30;
const int NW = 12;

final Float32List LAM = () {
  final l = Float32List(NW);
  for (var i = 0; i < NW; i++) {
    l[i] = 412.5 + 25 * i;
  }
  return l;
}();

Float32List cauchy(double a, double b) {
  final n = Float32List(NW);
  for (var i = 0; i < NW; i++) {
    final u = LAM[i] / 1000;
    n[i] = a + b / (u * u);
  }
  return n;
}

final Float32List nPrism = cauchy(1.40, 0.036);
final Float32List nLens = cauchy(1.46, 0.010);
final Float32List nGlass = cauchy(1.44, 0.020);

const Map<String, List<int>> bands = {
  'red': [8, 11],
  'amber': [7, 9],
  'green': [4, 6],
  'blue': [0, 3],
};

const Map<String, double> pieceSize = {'prism': 92, 'mirror': 92, 'lensH': 100, 'lensT': 24};
const Map<String, double> defAngle = {'prism': 270, 'mirror': 270, 'lens': 0};

/* ---------------- veri ---------------- */

class Well {
  double x, y, r, rh, core, g;
  double flux = 0;
  double glow = 0, phase = 0;
  Well({required this.x, required this.y, required this.r, this.rh = 21, this.core = 32, required this.g});
  Well copy() => Well(x: x, y: y, r: r, rh: rh, core: core, g: g);
}

class Target {
  double x, y;
  String kind;
  /// null ise türe göre varsayılan: beyaz 8, renkli 5 (JS'teki `t.need || …`).
  double? need;
  final Float32List bins = Float32List(NW);
  double fill = 0, total = 0, purity = 0, charge = 0;
  List<double> band = [0, 0, 0];
  List<double> rip = [];
  double ripT = 0;
  Target({required this.x, required this.y, required this.kind, this.need});
  double get needOr => need ?? (kind == 'white' ? 8 : 5);
  Target copy() => Target(x: x, y: y, kind: kind, need: need);
}

class Emitter {
  double x, y, a;
  int n;
  double w;
  int mono;
  Emitter({required this.x, required this.y, required this.a, this.n = 25, this.w = 36, this.mono = -1});
}

class Piece {
  String type;
  double x, y, a;
  bool out;
  Piece({required this.type, required this.x, required this.y, required this.a, this.out = false});
  Piece copy() => Piece(type: type, x: x, y: y, a: a, out: out);
}

class Block {
  String kind;
  double x, y, a, side, w, h;
  Block({required this.kind, required this.x, required this.y, this.a = 0, this.side = 92, this.w = 0, this.h = 0});
}

class Level {
  String id, name, desc, tip;
  Map<String, int> inv;
  int par;
  List<Emitter> emitters;
  List<Well> wells;
  List<List<double>> walls;
  List<Block> blocks;
  List<Target> targets;
  List<Piece> sol;
  bool gen;
  int n;
  String key;
  int score;
  Level({
    required this.id,
    required this.name,
    this.desc = '',
    this.tip = '',
    Map<String, int>? inv,
    this.par = 1,
    List<Emitter>? emitters,
    List<Well>? wells,
    List<List<double>>? walls,
    List<Block>? blocks,
    List<Target>? targets,
    List<Piece>? sol,
    this.gen = false,
    this.n = 0,
    this.key = '',
    this.score = 0,
  })  : inv = inv ?? {},
        emitters = emitters ?? [],
        wells = wells ?? [],
        walls = walls ?? [],
        blocks = blocks ?? [],
        targets = targets ?? [],
        sol = sol ?? [];
}

class Body {
  final Float32List p;
  final int np;
  final Float32List n;
  Body(this.p, this.np, this.n);
}

class MirrorSeg {
  final double x1, y1, x2, y2, nx, ny;
  MirrorSeg(this.x1, this.y1, this.x2, this.y2, this.nx, this.ny);
}

class Scene {
  late Float32List wallArr;
  final List<MirrorSeg> mirrors = [];
  final List<Body> bodies = [];
  List<Well> wells;
  List<Target> targets;
  List<Emitter> emitters;
  Scene(this.wells, this.targets, this.emitters);
}

/* ---------------- geometri ---------------- */

List<double> prismVerts(double x, double y, double aDeg, double side) {
  final r = side / math.sqrt(3);
  final v = <double>[];
  for (var k = 0; k < 3; k++) {
    final a = (aDeg + 120 * k) * DEG;
    v.add(x + r * math.cos(a));
    v.add(y + r * math.sin(a));
  }
  return v;
}

List<double> rectVerts(double x, double y, double w, double h, double aDeg) {
  final c = math.cos(aDeg * DEG), s = math.sin(aDeg * DEG), hw = w / 2, hh = h / 2;
  final v = <double>[];
  for (final p in [
    [-hw, -hh],
    [hw, -hh],
    [hw, hh],
    [-hw, hh]
  ]) {
    v.add(x + p[0] * c - p[1] * s);
    v.add(y + p[0] * s + p[1] * c);
  }
  return v;
}

/// Dışbükey gövde = ilkel bölgelerin kesişimi.
/// P: [tip, a, b, c, d] × np — tip 0 yarı düzlem, tip 1 disk.
Body polyBody(List<double> verts, Float32List nArr) {
  final n = verts.length ~/ 2;
  final p = Float32List(n * 5);
  double cx = 0, cy = 0;
  for (var i = 0; i < n; i++) {
    cx += verts[2 * i];
    cy += verts[2 * i + 1];
  }
  cx /= n;
  cy /= n;
  for (var i = 0; i < n; i++) {
    final ax = verts[2 * i], ay = verts[2 * i + 1];
    final j = (i + 1) % n, bx = verts[2 * j], by = verts[2 * j + 1];
    var nx = by - ay, ny = -(bx - ax);
    final l = math.sqrt(nx * nx + ny * ny) == 0 ? 1.0 : math.sqrt(nx * nx + ny * ny);
    nx /= l;
    ny /= l;
    if ((ax - cx) * nx + (ay - cy) * ny < 0) {
      nx = -nx;
      ny = -ny;
    }
    final o = i * 5;
    p[o] = 0;
    p[o + 1] = ax;
    p[o + 2] = ay;
    p[o + 3] = nx;
    p[o + 4] = ny;
  }
  return Body(p, n, nArr);
}

class LensShape {
  final double s, a, r, off, phi;
  LensShape(this.s, this.a, this.r, this.off, this.phi);
}

LensShape lensShape(double h, double t) {
  final s = t / 2, a = h / 2;
  final r = (a * a + s * s) / (2 * s);
  return LensShape(s, a, r, r - s, math.asin(a / r));
}

Body lensBody(double x, double y, double aDeg, double h, double t, Float32List nArr) {
  final g = lensShape(h, t);
  final ux = math.cos(aDeg * DEG), uy = math.sin(aDeg * DEG);
  final p = Float32List(10);
  p[0] = 1;
  p[1] = x + ux * g.off;
  p[2] = y + uy * g.off;
  p[3] = g.r;
  p[4] = 0;
  p[5] = 1;
  p[6] = x - ux * g.off;
  p[7] = y - uy * g.off;
  p[8] = g.r;
  p[9] = 0;
  return Body(p, 2, nArr);
}

MirrorSeg mirrorGeom(double x, double y, double aDeg, double len) {
  final nx = math.cos(aDeg * DEG), ny = math.sin(aDeg * DEG);
  final tx = -ny, ty = nx, h = len / 2;
  return MirrorSeg(x - tx * h, y - ty * h, x + tx * h, y + ty * h, nx, ny);
}

Scene buildScene(Level l, List<Piece> pieces, List<Target> targets, List<Well> wells) {
  final sc = Scene(wells, targets, l.emitters);
  final walls = <double>[];
  void addWall(double x, double y, double w, double h) {
    walls.addAll([x, y, x + w, y + h]);
  }

  addWall(0, 0, W.toDouble(), FRAME.toDouble());
  addWall(0, (W - FRAME).toDouble(), W.toDouble(), FRAME.toDouble());
  addWall(0, 0, FRAME.toDouble(), W.toDouble());
  addWall((W - FRAME).toDouble(), 0, FRAME.toDouble(), W.toDouble());
  for (final w in l.walls) {
    addWall(w[0], w[1], w[2], w[3]);
  }
  for (final b in l.blocks) {
    if (b.kind == 'prism') {
      sc.bodies.add(polyBody(prismVerts(b.x, b.y, b.a, b.side), nPrism));
    } else {
      sc.bodies.add(polyBody(rectVerts(b.x, b.y, b.w, b.h, b.a), nGlass));
    }
  }
  for (final p in pieces) {
    if (p.out) continue;
    if (p.type == 'mirror') {
      sc.mirrors.add(mirrorGeom(p.x, p.y, p.a, pieceSize['mirror']!));
    } else if (p.type == 'prism') {
      sc.bodies.add(polyBody(prismVerts(p.x, p.y, p.a, pieceSize['prism']!), nPrism));
    } else if (p.type == 'lens') {
      sc.bodies.add(lensBody(p.x, p.y, p.a, pieceSize['lensH']!, pieceSize['lensT']!, nLens));
    }
  }
  sc.wallArr = Float32List.fromList(walls);
  return sc;
}

/* ---------------- motor ---------------- */

const int NLEV = 10;
const int nBucket = (NW + 1) * NLEV;

class Bucket {
  Float32List d = Float32List(1024);
  int n = 0;
}

final List<Bucket> buckets = List.generate(nBucket, (_) => Bucket());
int _segTotal = 0;
const int maxSeg = 140000;

const int rs = 8, stackCap = 8192;
final Float32List _stack = Float32List(rs * stackCap);
int _sp = 0;

void _pushRay(double x, double y, double dx, double dy, double wl, double i, double med, double depth) {
  if (_sp >= stackCap) return;
  final o = _sp * rs;
  _stack[o] = x;
  _stack[o + 1] = y;
  _stack[o + 2] = dx;
  _stack[o + 3] = dy;
  _stack[o + 4] = wl;
  _stack[o + 5] = i;
  _stack[o + 6] = med;
  _stack[o + 7] = depth;
  _sp++;
}

const double step = 4, mini = 0.012;
const int maxDepth = 6, tRad = 20;
const int hWall = 1, hMirror = 2, hBody = 3, hWell = 4;

double _biTin = 0, _biTout = 0;
int _biPin = -1, _biPout = -1;
double _hT = 0;
int _hType = 0, _hIdx = -1, _hPrim = -1;
double _nX = 0, _nY = 0, _rDx = 0, _rDy = 0, _rR = 0;
bool _rTIR = false;
int _curMask = 0;
List<Target> _curTargets = const [];
List<double>? pathRec;

bool _bodyInterval(Float32List p, int np, double ox, double oy, double dx, double dy) {
  double tin = -1e30, tout = 1e30;
  int pin = -1, pout = -1;
  for (var i = 0; i < np; i++) {
    final o = i * 5;
    if (p[o] == 0) {
      final nx = p[o + 3], ny = p[o + 4];
      final a = (ox - p[o + 1]) * nx + (oy - p[o + 2]) * ny;
      final b = dx * nx + dy * ny;
      if (b > 1e-12) {
        final t = -a / b;
        if (t < tout) {
          tout = t;
          pout = i;
        }
      } else if (b < -1e-12) {
        final t = -a / b;
        if (t > tin) {
          tin = t;
          pin = i;
        }
      } else if (a > 0) {
        return false;
      }
    } else {
      final fx = ox - p[o + 1], fy = oy - p[o + 2], r = p[o + 3];
      final b = fx * dx + fy * dy;
      final c = fx * fx + fy * fy - r * r;
      final d = b * b - c;
      if (d <= 0) return false;
      final s = math.sqrt(d), t0 = -b - s, t1 = -b + s;
      if (t0 > tin) {
        tin = t0;
        pin = i;
      }
      if (t1 < tout) {
        tout = t1;
        pout = i;
      }
    }
  }
  _biTin = tin;
  _biTout = tout;
  _biPin = pin;
  _biPout = pout;
  return tin < tout;
}

void _primNormal(Float32List p, int i, double x, double y) {
  final o = i * 5;
  if (p[o] == 0) {
    _nX = p[o + 3];
    _nY = p[o + 4];
  } else {
    _nX = (x - p[o + 1]) / p[o + 3];
    _nY = (y - p[o + 2]) / p[o + 3];
  }
}

/// Snell + Fresnel. (nx,ny) gelen tarafa bakan birim normal (d·n < 0).
void _refract(double dx, double dy, double nx, double ny, double n1, double n2) {
  final cosi = -(dx * nx + dy * ny);
  final eta = n1 / n2;
  final k = 1 - eta * eta * (1 - cosi * cosi);
  if (k < 0) {
    _rTIR = true;
    return;
  }
  final cost = math.sqrt(k), q = eta * cosi - cost;
  _rDx = eta * dx + q * nx;
  _rDy = eta * dy + q * ny;
  var l = math.sqrt(_rDx * _rDx + _rDy * _rDy);
  if (l == 0) l = 1;
  _rDx /= l;
  _rDy /= l;
  final rsf = (n1 * cosi - n2 * cost) / (n1 * cosi + n2 * cost);
  final rpf = (n1 * cost - n2 * cosi) / (n1 * cost + n2 * cosi);
  _rR = 0.5 * (rsf * rsf + rpf * rpf);
  _rTIR = false;
}

double _wallHit(Float32List wa, double ox, double oy, double dx, double dy, double tmax) {
  var best = tmax;
  for (var i = 0; i < wa.length; i += 4) {
    double t0 = -1e30, t1 = 1e30;
    if (dx > 1e-12 || dx < -1e-12) {
      var a = (wa[i] - ox) / dx, b = (wa[i + 2] - ox) / dx;
      if (a > b) {
        final c = a;
        a = b;
        b = c;
      }
      t0 = a;
      t1 = b;
    } else if (ox < wa[i] || ox > wa[i + 2]) {
      continue;
    }
    if (dy > 1e-12 || dy < -1e-12) {
      var a = (wa[i + 1] - oy) / dy, b = (wa[i + 3] - oy) / dy;
      if (a > b) {
        final c = a;
        a = b;
        b = c;
      }
      if (a > t0) t0 = a;
      if (b < t1) t1 = b;
    } else if (oy < wa[i + 1] || oy > wa[i + 3]) {
      continue;
    }
    if (t0 > t1 || t1 < 0) continue;
    final t = t0 > 0 ? t0 : 0.0;
    if (t < best) best = t;
  }
  return best;
}

void _findHit(Scene sc, double ox, double oy, double dx, double dy, double tmax, bool wellsToo) {
  var best = tmax;
  var type = 0, idx = -1, prim = -1;
  final wa = sc.wallArr;
  for (var i = 0; i < wa.length; i += 4) {
    double t0 = -1e30, t1 = 1e30;
    if (dx > 1e-12 || dx < -1e-12) {
      var a = (wa[i] - ox) / dx, b = (wa[i + 2] - ox) / dx;
      if (a > b) {
        final c = a;
        a = b;
        b = c;
      }
      t0 = a;
      t1 = b;
    } else if (ox < wa[i] || ox > wa[i + 2]) {
      continue;
    }
    if (dy > 1e-12 || dy < -1e-12) {
      var a = (wa[i + 1] - oy) / dy, b = (wa[i + 3] - oy) / dy;
      if (a > b) {
        final c = a;
        a = b;
        b = c;
      }
      if (a > t0) t0 = a;
      if (b < t1) t1 = b;
    } else if (oy < wa[i + 1] || oy > wa[i + 3]) {
      continue;
    }
    if (t0 > t1 || t1 < 0) continue;
    final t = t0 > 0 ? t0 : 0.0;
    if (t < best) {
      best = t;
      type = hWall;
      idx = i;
    }
  }
  for (var i = 0; i < sc.mirrors.length; i++) {
    final m = sc.mirrors[i];
    final ex = m.x2 - m.x1, ey = m.y2 - m.y1;
    final den = dx * ey - dy * ex;
    if (den > -1e-10 && den < 1e-10) continue;
    final ax = m.x1 - ox, ay = m.y1 - oy;
    final t = (ax * ey - ay * ex) / den, s = (ax * dy - ay * dx) / den;
    if (t > 1e-4 && t < best && s >= 0 && s <= 1) {
      best = t;
      type = hMirror;
      idx = i;
    }
  }
  for (var i = 0; i < sc.bodies.length; i++) {
    final b = sc.bodies[i];
    if (_bodyInterval(b.p, b.np, ox, oy, dx, dy) && _biTin > 1e-6 && _biTin < best) {
      best = _biTin;
      type = hBody;
      idx = i;
      prim = _biPin;
    }
  }
  if (wellsToo) {
    for (var i = 0; i < sc.wells.length; i++) {
      final w = sc.wells[i];
      final fx = ox - w.x, fy = oy - w.y;
      final c = fx * fx + fy * fy - w.r * w.r;
      if (c <= 0) continue;
      final b = fx * dx + fy * dy, d = b * b - c;
      if (d <= 0) continue;
      final t = -b - math.sqrt(d);
      if (t > 1e-6 && t < best) {
        best = t;
        type = hWell;
        idx = i;
      }
    }
  }
  _hT = best;
  _hType = type;
  _hIdx = idx;
  _hPrim = prim;
}

void _addSeg(double x1, double y1, double x2, double y2, double wl, double i) {
  final ts = _curTargets;
  for (var k = 0; k < ts.length; k++) {
    final bit = 1 << k;
    if (_curMask & bit != 0) continue;
    final t = ts[k];
    final ex = x2 - x1, ey = y2 - y1;
    final l2 = ex * ex + ey * ey;
    var u = l2 > 0 ? ((t.x - x1) * ex + (t.y - y1) * ey) / l2 : 0.0;
    u = u < 0 ? 0 : (u > 1 ? 1 : u);
    final qx = x1 + ex * u - t.x, qy = y1 + ey * u - t.y;
    if (qx * qx + qy * qy <= tRad * tRad) {
      _curMask |= bit;
      if (wl < 0) {
        for (var j = 0; j < NW; j++) {
          t.bins[j] += i;
        }
      } else {
        t.bins[wl.toInt()] += i;
      }
    }
  }
  final pr = pathRec;
  if (pr != null && i >= 0.1 && pr.length < 16000) {
    pr.addAll([x1, y1, x2, y2, i]);
  }
  if (i < 0.004 || _segTotal >= maxSeg) return;
  var lev = (math.pow(i > 1 ? 1.0 : i, 0.85) * NLEV).toInt();
  if (lev >= NLEV) lev = NLEV - 1;
  final b = buckets[(wl < 0 ? NW : wl.toInt()) * NLEV + lev];
  if (b.n + 4 > b.d.length) {
    final nd = Float32List(b.d.length * 2);
    nd.setAll(0, b.d);
    b.d = nd;
  }
  b.d[b.n] = x1;
  b.d[b.n + 1] = y1;
  b.d[b.n + 2] = x2;
  b.d[b.n + 3] = y2;
  b.n += 4;
  _segTotal++;
}

void trace(Scene sc) {
  for (var i = 0; i < nBucket; i++) {
    buckets[i].n = 0;
  }
  _segTotal = 0;
  _sp = 0;
  _curTargets = sc.targets;
  for (final t in sc.targets) {
    t.bins.fillRange(0, NW, 0);
  }
  for (final w in sc.wells) {
    w.flux = 0;
  }
  for (final e in sc.emitters) {
    final ca = math.cos(e.a * DEG), sa = math.sin(e.a * DEG);
    final n = e.n, w = e.w;
    for (var k = n - 1; k >= 0; k--) {
      final off = (k / (n - 1) - 0.5) * w;
      _pushRay(e.x + ca * 26 - sa * off, e.y + sa * 26 + ca * off, ca, sa, e.mono.toDouble(), 1, -1, 0);
    }
  }
  var guard = 0;
  while (_sp > 0 && guard++ < 30000) {
    _sp--;
    final o = _sp * rs;
    _runRay(sc, _stack[o], _stack[o + 1], _stack[o + 2], _stack[o + 3], _stack[o + 4], _stack[o + 5], _stack[o + 6],
        _stack[o + 7]);
  }
}

void _runRay(Scene sc, double x, double y, double dx, double dy, double wl, double i, double med, double depth) {
  _curMask = 0;
  final bodies = sc.bodies, wells = sc.wells;
  var prevWell = -1, bounces = 0;
  for (var it = 0; it < 1400; it++) {
    if (med >= 0) {
      /* --- cam içinde: çıkış yüzeyini bul --- */
      final mi = med.toInt();
      if (mi >= bodies.length) return;
      final b = bodies[mi];
      if (!_bodyInterval(b.p, b.np, x, y, dx, dy)) return;
      var t = _biTout;
      if (t < 0) t = 0;
      if (t > 4000) return;
      final pout = _biPout;
      final tw = _wallHit(sc.wallArr, x, y, dx, dy, t);
      if (tw < t) {
        _addSeg(x, y, x + dx * tw, y + dy * tw, wl, i);
        return; // cam duvarın içine taşmışsa ışık soğurulur
      }
      final hx = x + dx * t, hy = y + dy * t;
      _addSeg(x, y, hx, hy, wl, i);
      _primNormal(b.p, pout, hx, hy);
      _refract(dx, dy, -_nX, -_nY, b.n[wl.toInt()], 1);
      x = hx;
      y = hy;
      final dn = dx * _nX + dy * _nY;
      if (_rTIR) {
        dx -= 2 * dn * _nX;
        dy -= 2 * dn * _nY;
        if (++bounces > 48) return;
        continue;
      }
      if (i * _rR > mini && depth < maxDepth) {
        _pushRay(x, y, dx - 2 * dn * _nX, dy - 2 * dn * _nY, wl, i * _rR, med, depth + 1);
      }
      i *= 1 - _rR;
      dx = _rDx;
      dy = _rDy;
      med = -1;
      continue;
    }
    /* --- havada --- */
    var wi = -1;
    for (var k = 0; k < wells.length; k++) {
      final w = wells[k];
      final rx = x - w.x, ry = y - w.y;
      if (rx * rx + ry * ry < w.r * w.r) {
        wi = k;
        break;
      }
    }
    if (wi >= 0 && wi != prevWell) wells[wi].flux += i * (wl < 0 ? NW : 1);
    prevWell = wi;
    final tmax = wi >= 0 ? step : 4000.0;
    _findHit(sc, x, y, dx, dy, tmax, wi < 0);
    final hx = x + dx * _hT, hy = y + dy * _hT;
    _addSeg(x, y, hx, hy, wl, i);
    x = hx;
    y = hy;
    if (_hType == 0) {
      if (wi < 0) return;
      // kütleçekimsel adım: dv/ds = -G r / (r² + ε²)^1.3
      final w = wells[wi];
      final rx = x - w.x, ry = y - w.y;
      final r2 = rx * rx + ry * ry;
      if (r2 < w.rh * w.rh) return; // olay ufku
      final f = w.g / math.pow(r2 + 64, 1.3) * step;
      dx -= f * rx;
      dy -= f * ry;
      final l = math.sqrt(dx * dx + dy * dy);
      dx /= l;
      dy /= l;
      continue;
    }
    if (_hType == hWall) return;
    if (_hType == hWell) {
      x += dx * 0.02;
      y += dy * 0.02;
      continue;
    }
    if (_hType == hMirror) {
      final m = sc.mirrors[_hIdx];
      final dn = dx * m.nx + dy * m.ny;
      if (dn >= 0) return; // arka yüz soğurur
      dx -= 2 * dn * m.nx;
      dy -= 2 * dn * m.ny;
      if (++bounces > 48) return;
      continue;
    }
    /* --- cam gövdeye giriş --- */
    final b = bodies[_hIdx];
    _primNormal(b.p, _hPrim, x, y);
    final dn = dx * _nX + dy * _nY;
    if (wl < 0) {
      // beyaz demet 12 dalga boyuna ayrışır
      double rAvg = 0;
      for (var k = NW - 1; k >= 0; k--) {
        _refract(dx, dy, _nX, _nY, 1, b.n[k]);
        rAvg += _rR;
        _pushRay(x, y, _rDx, _rDy, k.toDouble(), i * (1 - _rR), _hIdx.toDouble(), depth);
      }
      rAvg /= NW;
      if (i * rAvg > mini && depth < maxDepth) {
        _pushRay(x, y, dx - 2 * dn * _nX, dy - 2 * dn * _nY, -1, i * rAvg, -1, depth + 1);
      }
      return;
    }
    _refract(dx, dy, _nX, _nY, 1, b.n[wl.toInt()]);
    if (i * _rR > mini && depth < maxDepth) {
      _pushRay(x, y, dx - 2 * dn * _nX, dy - 2 * dn * _nY, wl, i * _rR, -1, depth + 1);
    }
    i *= 1 - _rR;
    dx = _rDx;
    dy = _rDy;
    med = _hIdx.toDouble();
  }
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

void evalTargets(List<Target> ts) {
  for (final t in ts) {
    final b = t.bins;
    double tot = 0;
    for (var i = 0; i < NW; i++) {
      tot += b[i];
    }
    t.total = tot;
    if (t.kind == 'white') {
      final need = t.needOr;
      final cool = (b[0] + b[1] + b[2] + b[3]) / 4;
      final mid = (b[4] + b[5] + b[6]) / 3;
      final warm = (b[7] + b[8] + b[9] + b[10] + b[11]) / 5;
      t.band = [warm / need, mid / need, cool / need];
      t.fill = math.min(cool, math.min(mid, warm)) / need;
    } else {
      final bd = bands[t.kind]!;
      double s = 0;
      for (var i = bd[0]; i <= bd[1]; i++) {
        s += b[i];
      }
      final avg = s / (bd[1] - bd[0] + 1);
      t.purity = tot > 0 ? s / tot : 0;
      final energy = avg / t.needOr;
      t.fill = energy * _clamp01((t.purity - 0.36) / 0.2);
    }
  }
}

/// Bölümü verilen parçalarla simüle eder; doldurmaları hesaplanmış
/// algılayıcı kopyalarını döndürür.
List<Target> simulate(Level l, List<Piece> pieces, {bool record = false}) {
  final ts = l.targets.map((t) => t.copy()).toList();
  final ws = l.wells.map((w) => w.copy()).toList();
  pathRec = record ? <double>[] : null;
  trace(buildScene(l, pieces, ts, ws));
  evalTargets(ts);
  return ts;
}

bool solved(List<Target> ts) => ts.isNotEmpty && ts.every((t) => t.fill >= 1);
