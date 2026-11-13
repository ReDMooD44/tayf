import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'engine.dart';

/// Dalga boyu → RGB (JS wlRGB ile birebir).
List<double> wlRGB(double l) {
  double r = 0, g = 0, b = 0;
  if (l < 440) {
    r = (440 - l) / 60;
    b = 1;
  } else if (l < 490) {
    g = (l - 440) / 50;
    b = 1;
  } else if (l < 510) {
    g = 1;
    b = (510 - l) / 20;
  } else if (l < 580) {
    r = (l - 510) / 70;
    g = 1;
  } else if (l < 645) {
    r = 1;
    g = (645 - l) / 65;
  } else {
    r = 1;
  }
  final f = l < 420 ? 0.3 + 0.7 * (l - 380) / 40 : 1.0;
  return [r * f, g * f, b * f];
}

/// Örnek renkleri, 12'si üst üste bindiğinde her kanalda eşit toplam versin
/// diye normalize edilir. Son öğe (indeks NW) ayrışmamış beyaz demet.
final List<Color> beamColors = () {
  final raw = <List<double>>[];
  final sum = [0.0, 0.0, 0.0];
  for (var i = 0; i < NW; i++) {
    final c = wlRGB(LAM[i]);
    raw.add(c);
    sum[0] += c[0];
    sum[1] += c[1];
    sum[2] += c[2];
  }
  const k = 3.6;
  final out = <Color>[];
  for (var i = 0; i < NW; i++) {
    int ch(int j) => (255 * math.min(1.0, raw[i][j] / sum[j] * k)).round();
    out.add(Color.fromARGB(255, ch(0), ch(1), ch(2)));
  }
  out.add(const Color(0xFFFFFFFF));
  return out;
}();

const Color bgColor = Color(0xFF05070A);
const Color inkColor = Color(0xFFDFE9EE);
const Color dimColor = Color(0xFF7D8B94);
const Color tealColor = Color(0xFF62D6C6);
const Color amberColor = Color(0xFFFFB24A);

const Map<String, Color> targetColor = {
  'white': Color(0xFFFFFFFF),
  'red': Color(0xFFFF4B3A),
  'amber': Color(0xFFFF922E),
  'green': Color(0xFF49F58A),
  'blue': Color(0xFF5B8DFF),
};

const Map<String, String> pieceName = {'prism': 'prizma', 'mirror': 'ayna', 'lens': 'mercek'};

/// Oyun tahtasını çizer. Mantıksal koordinatlar 900×900; tuval ölçeklenir.
class BoardPainter extends CustomPainter {
  final Level level;
  final List<Piece> pieces;
  final List<Target> targets;
  final List<Well> wells;
  final Piece? selected;
  final double time;
  final double hp, hpMax;
  final int? hintIdx;
  final double hintT;
  final double flash, hold;
  final String flashTxt, flashSub;
  final bool solved;

  BoardPainter({
    required this.level,
    required this.pieces,
    required this.targets,
    required this.wells,
    required this.selected,
    required this.time,
    required this.hp,
    required this.hpMax,
    this.hintIdx,
    this.hintT = 0,
    this.flash = 0,
    this.flashTxt = '',
    this.flashSub = '',
    this.hold = 0,
    this.solved = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / W;
    canvas.save();
    canvas.scale(s, s);

    _bg(canvas);
    for (final w in wells) {
      _well(canvas, w);
    }
    _beams(canvas);
    for (final b in level.blocks) {
      if (b.kind == 'prism') _prism(canvas, b.x, b.y, b.a, b.side, true, 1);
    }
    for (final e in level.emitters) {
      _emitter(canvas, e);
    }
    for (final t in targets) {
      _target(canvas, t);
    }
    for (final p in pieces) {
      if (!p.out) _piece(canvas, p, 1);
    }
    final hi = hintIdx;
    if (hintT > 0 && hi != null && hi < level.sol.length) {
      final a = (hintT / 0.6).clamp(0.0, 1.0) * (0.55 + 0.25 * math.sin(time * 7));
      _piece(canvas, level.sol[hi], a);
      _ring(canvas, level.sol[hi], a);
    }
    final sel = selected;
    if (sel != null && !sel.out) _gizmo(canvas, sel);
    _timeBar(canvas);

    if (hold > 0 && !solved) {
      // hepsi dolu: kilitlenme sayacı
      final u = (hold / 1.2).clamp(0.0, 1.0);
      const bw = 150.0;
      final bx = W / 2 - bw / 2, by = W - FRAME - 26.0;
      canvas.drawRect(Rect.fromLTWH(bx - 6, by - 13, bw + 12, 26), Paint()..color = const Color(0xCC030507));
      canvas.drawRect(Rect.fromLTWH(bx, by + 3, bw, 3), Paint()..color = tealColor.withValues(alpha: 0.22));
      canvas.drawRect(Rect.fromLTWH(bx, by + 3, bw * u, 3), Paint()..color = tealColor);
      _label(canvas, 'KİLİTLENİYOR', W / 2, by - 4, tealColor, 11);
    }
    if (flash > 0 && flashTxt.isNotEmpty) {
      final a = (flash / 0.6).clamp(0.0, 1.0);
      _plain(canvas, flashTxt, W / 2, W / 2 - 40, const Color(0xFFFF4B3A).withValues(alpha: a), 24);
      if (flashSub.isNotEmpty) {
        _plain(canvas, flashSub, W / 2, W / 2 - 12, inkColor.withValues(alpha: a * 0.8), 12);
      }
    }

    canvas.restore();
  }

  void _bg(Canvas c) {
    final r = Rect.fromLTWH(0, 0, W.toDouble(), W.toDouble());
    c.drawRect(r, Paint()..color = bgColor);
    c.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(W / 2, W / 2),
          640,
          [const Color(0xFF0D1620), bgColor],
          [0.0, 1.0],
        ),
    );
    // ızgara
    final g = Paint()
      ..color = const Color(0x12BEE1EB)
      ..strokeWidth = 1;
    for (var i = FRAME; i <= W - FRAME; i += 60) {
      c.drawLine(Offset(i.toDouble(), FRAME.toDouble()), Offset(i.toDouble(), (W - FRAME).toDouble()), g);
      c.drawLine(Offset(FRAME.toDouble(), i.toDouble()), Offset((W - FRAME).toDouble(), i.toDouble()), g);
    }
    // çerçeve ve duvarlar
    _wall(c, 0, 0, W.toDouble(), FRAME.toDouble());
    _wall(c, 0, (W - FRAME).toDouble(), W.toDouble(), FRAME.toDouble());
    _wall(c, 0, FRAME.toDouble(), FRAME.toDouble(), (W - 2 * FRAME).toDouble());
    _wall(c, (W - FRAME).toDouble(), FRAME.toDouble(), FRAME.toDouble(), (W - 2 * FRAME).toDouble());
    for (final w in level.walls) {
      _wall(c, w[0], w[1], w[2], w[3]);
    }
  }

  void _wall(Canvas c, double x, double y, double w, double h) {
    final r = Rect.fromLTWH(x, y, w, h);
    c.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x, y),
            Offset(x, y + h),
            [const Color(0xFF1C2731), const Color(0xFF10171E)],
          ));
    c.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x33BEE1EB));
  }

  /// Işınlar: motorun kovalarından, toplamalı karışımla.
  void _beams(Canvas c) {
    c.saveLayer(Rect.fromLTWH(0, 0, W.toDouble(), W.toDouble()), Paint());
    for (var col = 0; col <= NW; col++) {
      final white = col == NW;
      for (var lv = 0; lv < NLEV; lv++) {
        final b = buckets[col * NLEV + lv];
        if (b.n == 0) continue;
        final path = Path();
        double px = double.nan, py = double.nan;
        for (var j = 0; j < b.n; j += 4) {
          if (b.d[j] != px || b.d[j + 1] != py) path.moveTo(b.d[j], b.d[j + 1]);
          path.lineTo(px = b.d[j + 2], py = b.d[j + 3]);
        }
        final a = (lv + 0.35) / NLEV;
        final base = beamColors[col];
        final glow = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..blendMode = BlendMode.plus
          ..strokeWidth = 5
          ..color = base.withValues(alpha: a * (white ? 0.22 : 0.13));
        c.drawPath(path, glow);
        final core = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..blendMode = BlendMode.plus
          ..strokeWidth = 1.7
          ..color = base.withValues(alpha: math.min(1.0, a * (white ? 1.0 : 0.62)));
        c.drawPath(path, core);
      }
    }
    c.restore();
  }

  void _emitter(Canvas c, Emitter e) {
    c.save();
    c.translate(e.x, e.y);
    c.rotate(e.a * DEG);
    final r = Rect.fromLTWH(-26, -18, 34, 36);
    c.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, -24),
            const Offset(0, 24),
            [const Color(0xFF28343D), const Color(0xFF131B22)],
          ));
    c.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0x66BEE1EB));
    final pulse = 0.75 + 0.25 * math.sin(time * 2.2);
    c.drawRect(
        Rect.fromLTWH(6, -16, 4, 32), Paint()..color = Colors.white.withValues(alpha: pulse));
    c.restore();
  }

  void _target(Canvas c, Target t) {
    final col = targetColor[t.kind]!;
    final ch = t.charge;
    final full = t.fill >= 1;
    // hale
    c.drawCircle(
        Offset(t.x, t.y),
        40,
        Paint()
          ..shader = ui.Gradient.radial(Offset(t.x, t.y), 40, [
            col.withValues(alpha: 0.10 + 0.5 * ch),
            col.withValues(alpha: 0),
          ]));
    c.drawCircle(Offset(t.x, t.y), 19, Paint()..color = const Color(0xC7030507));
    c.drawCircle(
        Offset(t.x, t.y),
        21,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = col.withValues(alpha: 0.38));
    // doluluk yayı
    if (ch > 0.004) {
      c.drawArc(
          Rect.fromCircle(center: Offset(t.x, t.y), radius: 21),
          -math.pi / 2,
          2 * math.pi * math.min(1.0, ch),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.6
            ..color = col);
    }
    if (full) {
      c.drawCircle(
          Offset(t.x, t.y),
          30.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = col.withValues(alpha: 0.55 + 0.35 * math.sin(time * 4)));
    }
    // çekirdek altıgen
    final rr = 8 + (full ? 1.5 * math.sin(time * 6) : 0);
    final p = Path();
    for (var k = 0; k < 6; k++) {
      final a = k * math.pi / 3 + time * 0.4 * (0.2 + ch);
      final x = t.x + math.cos(a) * rr, y = t.y + math.sin(a) * rr;
      k == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    p.close();
    c.drawPath(p, Paint()..color = col.withValues(alpha: 0.18 + 0.8 * ch));
    c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = col.withValues(alpha: 0.95));
    // neden dolmadı
    if (!full && t.total > 0) {
      final impure = t.kind != 'white' && t.purity < 0.55;
      final txt = impure ? 'karışık' : '${(t.fill.clamp(0.0, 1.0) * 100).round()}%';
      _label(c, txt, t.x, t.y + 40, impure ? amberColor : col, 13);
    }
  }

  void _well(Canvas c, Well w) {
    c.drawCircle(
        Offset(w.x, w.y),
        w.r,
        Paint()
          ..shader = ui.Gradient.radial(Offset(w.x, w.y), w.r, [
            const Color(0x33101A33),
            const Color(0x00000000),
          ]));
    c.drawCircle(
        Offset(w.x, w.y),
        w.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x334F7FBF));
    c.drawCircle(Offset(w.x, w.y), w.core, Paint()..color = Colors.black);
    c.drawCircle(
        Offset(w.x, w.y),
        w.core,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x99AFC9E8));
  }

  void _piece(Canvas c, Piece p, double alpha) {
    switch (p.type) {
      case 'prism':
        _prism(c, p.x, p.y, p.a, pieceSize['prism']!, false, alpha);
        break;
      case 'mirror':
        _mirror(c, p.x, p.y, p.a, pieceSize['mirror']!, alpha);
        break;
      case 'lens':
        _lens(c, p.x, p.y, p.a, alpha);
        break;
    }
  }

  void _prism(Canvas c, double x, double y, double a, double side, bool fixed, double alpha) {
    final v = prismVerts(x, y, a, side);
    final p = Path()
      ..moveTo(v[0], v[1])
      ..lineTo(v[2], v[3])
      ..lineTo(v[4], v[5])
      ..close();
    c.drawPath(p, Paint()..color = const Color(0xFFAAE1FF).withValues(alpha: 0.14 * alpha));
    c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFEAF6FA).withValues(alpha: (fixed ? 0.75 : 1) * alpha));
  }

  void _mirror(Canvas c, double x, double y, double a, double len, double alpha) {
    c.save();
    c.translate(x, y);
    c.rotate(a * DEG);
    final h = len / 2;
    // arka gövde (ışığı durdurur)
    c.drawRect(Rect.fromLTWH(0, -h, 7, len),
        Paint()..color = const Color(0xFF1C2832).withValues(alpha: alpha));
    c.drawRect(
        Rect.fromLTWH(0, -h, 7, len),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF96C3D7).withValues(alpha: 0.6 * alpha));
    // yansıtıcı yüz
    c.drawLine(
        Offset(0, -h),
        Offset(0, h),
        Paint()
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFF0FAFF).withValues(alpha: alpha));
    c.restore();
  }

  void _lens(Canvas c, double x, double y, double a, double alpha) {
    final g = lensShape(pieceSize['lensH']!, pieceSize['lensT']!);
    c.save();
    c.translate(x, y);
    c.rotate(a * DEG);
    final p = Path()
      ..addArc(Rect.fromCircle(center: Offset(-g.off, 0), radius: g.r), -g.phi, 2 * g.phi)
      ..arcTo(Rect.fromCircle(center: Offset(g.off, 0), radius: g.r), math.pi - g.phi, 2 * g.phi, false)
      ..close();
    c.drawPath(p, Paint()..color = const Color(0xFFAAE1FF).withValues(alpha: 0.2 * alpha));
    c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFFEAF6FA).withValues(alpha: alpha));
    c.restore();
  }

  void _ring(Canvas c, Piece s, double a) {
    final p = Path();
    const r = 56.0;
    for (var k = 0; k < 40; k++) {
      final t0 = k / 40 * 2 * math.pi, t1 = (k + 0.5) / 40 * 2 * math.pi;
      p.moveTo(s.x + math.cos(t0) * r, s.y + math.sin(t0) * r);
      p.lineTo(s.x + math.cos(t1) * r, s.y + math.sin(t1) * r);
    }
    c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = amberColor.withValues(alpha: a));
    _label(c, '${pieceName[s.type]} ${s.a.toStringAsFixed(1)}°', s.x, s.y + 74,
        amberColor.withValues(alpha: math.min(1.0, a + 0.2)), 12);
  }

  void _gizmo(Canvas c, Piece p) {
    const r = 56.0;
    final a = p.a * DEG;
    final hx = p.x + math.cos(a) * r, hy = p.y + math.sin(a) * r;
    c.drawCircle(
        Offset(p.x, p.y),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFD2EEF5).withValues(alpha: 0.8));
    c.drawLine(
        Offset(p.x, p.y),
        Offset(hx, hy),
        Paint()
          ..strokeWidth = 1
          ..color = amberColor.withValues(alpha: 0.75));
    c.drawCircle(Offset(hx, hy), 6.5, Paint()..color = amberColor);
    c.drawCircle(Offset(hx, hy), 2.2, Paint()..color = bgColor);
    final ty = p.y - r - 18 < FRAME + 10 ? p.y + r + 20 : p.y - r - 18;
    _label(c, '${p.a.toStringAsFixed(1)}°', p.x, ty, inkColor, 15);
  }

  void _timeBar(Canvas c) {
    final u = (hp / hpMax).clamp(0.0, 1.0);
    const x0 = FRAME + 12.0;
    final bw = W - 2 * (FRAME + 12.0);
    const y0 = FRAME + 12.0;
    final col = u > 0.4 ? tealColor : (u > 0.18 ? amberColor : const Color(0xFFFF4B3A));
    c.drawRect(Rect.fromLTWH(x0, y0, bw, 5), Paint()..color = const Color(0x8C030507));
    c.drawRect(Rect.fromLTWH(x0, y0, bw * u, 5), Paint()..color = col);
    _label(c, '${hp.ceil()} sn', x0 + bw - 24, y0 + 14, col, 12);
    if (level.par > 0) {
      _label(c, 'par ${level.par} parça', x0 + 40, y0 + 14, amberColor.withValues(alpha: 0.85), 12);
    }
  }

  /// Arkalıksız, ortalanmış yazı.
  void _plain(Canvas c, String s, double x, double y, Color col, double size) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(color: col, fontSize: size, fontFamily: 'monospace', fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  void _label(Canvas c, String s, double x, double y, Color col, double size) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(color: col, fontSize: size, fontFamily: 'monospace', fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = Rect.fromCenter(center: Offset(x, y), width: tp.width + 10, height: tp.height + 4);
    c.drawRect(r, Paint()..color = const Color(0xD1030507));
    tp.paint(c, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}
