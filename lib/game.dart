import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'audio.dart';
import 'engine.dart';
import 'generator.dart';
import 'levels.dart';
import 'progress.dart';
import 'storage.dart';
import 'render.dart';
import 'ui.dart';

/// Tek ilerleme: 1..6 elle tasarlanmış, 7 ve sonrası üretilen. -1 = günün bölümü.
const int dailyIndex = -1;
bool isGen(int i) => i >= levels.length;
Level levelAt(int i) => i == dailyIndex
    ? dailyLevel()
    : isGen(i)
        ? endlessLevel(i + 1)
        : levels[i];
String levelId(int i) => i == dailyIndex
    ? 'd${todayKey()}'
    : isGen(i)
        ? 'e${i + 1}'
        : levels[i].id;

/// Bölüm süresi: parça sayısı zorluğu belirler — kolay 80, orta 100, zor 120 sn.
double levelTime(Level l) {
  final p = l.par;
  return p <= 1 ? 80 : (p == 2 ? 100 : 120);
}

enum Sheet { none, menu, levels, shop, how, noLife, solved }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;

  Progress p = Progress();
  late Audio snd;
  bool _ready = false;
  double _rotAcc = 0;  // 2,5 derecede bir tıkırtı

  int li = 0;
  late Level level;
  List<Piece> pieces = [];
  Map<String, int> inv = {};
  List<Target> targets = [];
  List<Well> wells = [];
  Piece? sel;
  bool dirty = true, solvedFlag = false;
  double hold = 0, t = 0, hp = 1, hpMax = 1, flash = 0;
  String flashTxt = '', flashSub = '';
  int hintIdx = -1;
  double hintT = 0;
  final List<int> hintSeen = [];

  Sheet sheet = Sheet.none;
  bool generating = false;

  // çözüldü kutusu verisi
  int _used = 0, _par = 0, _earned = 0;
  bool _isPar = false;
  String _foot = '';

  Piece? _drag;
  bool _rotating = false;
  double _rotOff = 0;
  final GlobalKey _boardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    level = levels[0];
    _boot();
    _ticker = createTicker(_tick)..start();
  }

  Future<void> _boot() async {
    p = await loadProgress();
    snd = Audio(on: p.sound);
    p.refreshLives(DateTime.now().millisecondsSinceEpoch);
    // menü arkasındaki sahne kilitli bölüm olmasın
    final resume = p.last;
    _load(resume >= 0 && resume < levels.length && resume <= p.maxOpen ? resume : 0, record: false);
    if (!mounted) return;
    setState(() {
      _ready = true;
      sheet = Sheet.menu;
    });
  }

  @override
  void dispose() {
    snd.dispose();
    _ticker.dispose();
    super.dispose();
  }

  bool get _blocked => sheet != Sheet.none;

  void _load(int i, {bool record = true}) {
    li = i;
    level = levelAt(i);
    pieces = [];
    inv = Map<String, int>.from(level.inv);
    targets = level.targets.map((x) => x.copy()).toList();
    wells = level.wells.map((w) => w.copy()).toList();
    sel = null;
    hold = 0;
    solvedFlag = false;
    hintIdx = -1;
    hintT = 0;
    hintSeen.clear();
    hpMax = levelTime(level);
    hp = hpMax;
    flash = 0;
    dirty = true;
    if (record && i != dailyIndex) {
      p.last = i;
      saveProgress(p);
    }
  }

  /// Kilidi gözetip bölüme geçer; üretilmesi gerekiyorsa kısa bir bekleme gösterir.
  Future<void> _go(int i) async {
    if (i != dailyIndex && i > p.maxOpen) {
      setState(() {
        flash = 1.6;
        flashTxt = 'BÖLÜM KİLİTLİ';
        flashSub = 'önce önceki bölümü bitir';
        sheet = Sheet.none;
      });
      return;
    }
    final needsGen = i == dailyIndex || (isGen(i) && !endlessCache.containsKey(i + 1));
    if (needsGen) {
      setState(() {
        generating = true;
        sheet = Sheet.none;
      });
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    setState(() {
      _load(i);
      generating = false;
      sheet = Sheet.none;
      if (p.lives <= 0) sheet = Sheet.noLife;
    });
  }

  void _tick(Duration now) {
    if (!_ready) return;
    final dt = _lastTick == Duration.zero ? 0.016 : math.min(0.05, (now - _lastTick).inMicroseconds / 1e6);
    _lastTick = now;
    t += dt;

    if (dirty) {
      trace(buildScene(level, pieces, targets, wells));
      evalTargets(targets);
      dirty = false;
    }

    var all = targets.isNotEmpty;
    for (final tg in targets) {
      final goal = math.min(1.0, tg.fill);
      tg.charge += (goal - tg.charge) * (1 - math.exp(-dt * (goal > tg.charge ? 3.2 : 5)));
      if (goal >= 1 && tg.charge > 0.985) tg.charge = 1;
      if (tg.fill < 1) all = false;
    }
    if (all && _drag == null && !_blocked) {
      hold += dt;
      if (hold >= 1.2 && !solvedFlag) {
        _onSolved();
        snd.solved();
      }
    } else if (!all) {
      hold = 0;
    }
    // can barı: menü açıkken ve bölüm çözülünce durur
    if (!solvedFlag && !_blocked && !generating) {
      hp -= dt;
      if (hp <= 0) _timeOut();
    }
    snd.updateTargets(targets);
    if (flash > 0) flash -= dt;
    if (hintT > 0) hintT -= dt;
    // canlar gerçek zamanda dolar
    if (p.refreshLives(DateTime.now().millisecondsSinceEpoch) > 0) {
      saveProgress(p);
      if (sheet == Sheet.noLife && p.lives > 0) {
        sheet = Sheet.none;
        hp = hpMax;
      }
    }
    setState(() {});
  }

  /// Süre bitti: bir can gider, parçalar envantere döner, bölüm baştan başlar.
  void _timeOut() {
    for (final q in pieces) {
      inv[q.type] = (inv[q.type] ?? 0) + 1;
    }
    pieces = [];
    sel = null;
    hold = 0;
    hp = hpMax;
    flash = 2;
    flashTxt = 'SÜRE DOLDU';
    flashSub = 'bölüm baştan başladı';
    dirty = true;
    p.spendLife(DateTime.now().millisecondsSinceEpoch);
    saveProgress(p);
    if (p.lives <= 0) sheet = Sheet.noLife;
  }

  void _onSolved() {
    solvedFlag = true;
    final id = levelId(li);
    _used = pieces.length;
    _par = level.par;
    _isPar = _used <= _par;
    // ödül yalnız ilk tamamlamada: aynı bölümü tekrar oynayarak para biriktirilmesin
    final wasCleared =
        li == dailyIndex ? p.daily == level.key : (isGen(li) ? p.best >= li + 1 : p.solved.containsKey(id));
    final hadPar = p.par.containsKey(id);
    _earned = 0;
    if (!wasCleared) _earned += li == dailyIndex ? coinDaily : coinClear;
    if (_isPar && !hadPar) _earned += coinPar;
    p.coins += _earned;
    if (li == dailyIndex) {
      p.daily = level.key;
    } else {
      if (!isGen(li)) p.solved[id] = 1;
      p.best = math.max(p.best, li + 1);
    }
    if (_isPar) p.par[id] = 1;
    _foot = li == dailyIndex
        ? 'GÜNÜN BÖLÜMÜ   ·   ${level.key}   ·   ${p.coins} ◈'
        : '${li + 1}. BÖLÜM TAMAMLANDI   ·   EN İLERİ ${p.best}   ·   ${p.coins} ◈';
    saveProgress(p);
    sheet = Sheet.solved;
  }

  void _skip() {
    if (li == dailyIndex) {
      _go(p.last >= 0 ? p.last : 0);
      return;
    }
    if (solvedFlag) {
      _go(li + 1);
      return;
    }
    if (!p.buy(skipPrice)) {
      setState(() {
        flash = 1.6;
        flashTxt = 'ATLAMAK İÇİN $skipPrice ◈';
        flashSub = 'bölüm bitirince $coinClear ◈ kazanırsın';
      });
      return;
    }
    p.best = math.max(p.best, li + 1); // atlanan bölüm açılır
    saveProgress(p);
    _go(li + 1);
  }

  void _buy(String what) {
    setState(() {
      switch (what) {
        case 'hint':
          if (p.buy(hintPrice)) p.hints++;
          break;
        case 'time':
          if (p.buy(timePrice)) {
            hp += timeBonus;
            hpMax = math.max(hpMax, hp);
          }
          break;
        default:
          if (p.buy(piecePrice)) inv[what] = (inv[what] ?? 0) + 1;
      }
      saveProgress(p);
    });
  }

  void _buyLife() {
    setState(() {
      if (!p.buy(lifePrice)) return;
      p.lives++;
      saveProgress(p);
      sheet = Sheet.none;
      hp = hpMax;
    });
  }

  /* ---------------- etkileşim ---------------- */

  Offset _toLogical(Offset local) {
    final box = _boardKey.currentContext!.findRenderObject() as RenderBox;
    return Offset(local.dx / (box.size.width / W), local.dy / (box.size.width / W));
  }

  double get _grab {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    return math.max(15, 20 * W / (box?.size.width ?? 600));
  }

  Offset _handlePos(Piece q) => Offset(q.x + math.cos(q.a * DEG) * 56, q.y + math.sin(q.a * DEG) * 56);

  void _down(Offset local) {
    snd.ensure();
    if (_blocked) return;
    final pt = _toLogical(local);
    final s = sel;
    if (s != null && (pt - _handlePos(s)).distance < _grab) {
      _drag = s;
      _rotating = true;
      _rotOff = s.a - math.atan2(pt.dy - s.y, pt.dx - s.x) / DEG;
      return;
    }
    Piece? best;
    var bd = math.max(44.0, _grab);
    for (final q in pieces) {
      final d = (pt - Offset(q.x, q.y)).distance;
      if (d < bd) {
        bd = d;
        best = q;
      }
    }
    if (best != null) {
      setState(() => sel = best);
      _drag = best;
      _rotating = false;
    }
  }

  void _move(Offset local) {
    final d = _drag;
    if (d == null) return;
    final pt = _toLogical(local);
    if (_rotating) {
      final a = math.atan2(pt.dy - d.y, pt.dx - d.x) / DEG + _rotOff;
      final na = ((((a % 360) + 360) % 360) * 10).round() / 10;
      _tickRot(na - d.a);
      d.a = na;
    } else {
      d.x = pt.dx.clamp(FRAME + 8.0, W - FRAME - 8.0);
      d.y = pt.dy.clamp(FRAME + 8.0, W - FRAME - 8.0);
    }
    dirty = true;
    hold = 0;
  }

  void _addFromDock(String type) {
    if ((inv[type] ?? 0) <= 0 || _blocked) return;
    setState(() {
      inv[type] = inv[type]! - 1;
      final q = Piece(type: type, x: W / 2, y: W / 2, a: defAngle[type]!);
      pieces.add(q);
      sel = q;
      dirty = true;
    });
    snd.pickUp();
  }

  void _removeSelected() {
    final q = sel;
    if (q == null) return;
    setState(() {
      pieces.remove(q);
      inv[q.type] = (inv[q.type] ?? 0) + 1;
      sel = null;
      dirty = true;
    });
    snd.putDown();
  }

  void _nudge(double dx, double dy) {
    final q = sel;
    if (q == null) return;
    setState(() {
      q.x = (q.x + dx).clamp(FRAME + 8.0, W - FRAME - 8.0);
      q.y = (q.y + dy).clamp(FRAME + 8.0, W - FRAME - 8.0);
      dirty = true;
      hold = 0;
    });
  }

  void _rot(double d) {
    final q = sel;
    if (q == null) return;
    setState(() {
      q.a = (((((q.a + d) % 360) + 360) % 360) * 10).round() / 10;
      _tickRot(d);
      dirty = true;
      hold = 0;
    });
  }

  /// Her 2,5 derecede bir tıkırtı — web sürümündeki geri bildirimin aynısı.
  void _tickRot(double delta) {
    var d = delta.abs() % 360;
    if (d > 180) d = 360 - d;
    _rotAcc += d;
    while (_rotAcc >= 2.5) {
      _rotAcc -= 2.5;
      snd.click();
    }
  }

  /// İpucu tek parça gösterir ve her hak farklı bir parçayı açar.
  void _hint() {
    final pend = <int>[];
    for (var i = 0; i < level.sol.length; i++) {
      final s = level.sol[i];
      final found = pieces.any((q) =>
          q.type == s.type &&
          (Offset(q.x, q.y) - Offset(s.x, s.y)).distance < 34 &&
          (((q.a - s.a + 540) % 360) - 180).abs() > 171);
      if (!found) pend.add(i);
    }
    if (pend.isEmpty) return;
    final fresh = pend.where((i) => !hintSeen.contains(i)).toList();
    setState(() {
      if (fresh.isEmpty) {
        hintIdx = pend.first; // bu parça için zaten ödendi
      } else {
        if (p.hints <= 0) {
          sheet = Sheet.shop;
          return;
        }
        p.hints--;
        saveProgress(p);
        hintIdx = fresh.first;
        hintSeen.add(fresh.first);
      }
      hintT = 5;
      snd.hint();
    });
  }

  /* ---------------- arayüz ---------------- */

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(backgroundColor: bgColor, body: SizedBox.shrink());
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(children: [
          LayoutBuilder(builder: (ctx, box) {
            final side = math.max(120.0, math.min(box.maxWidth - 12, box.maxHeight - 250));
            return Column(children: [
              _hud(),
              SizedBox(
                width: side,
                height: side,
                child: Listener(
                  onPointerDown: (e) => _down(e.localPosition),
                  onPointerMove: (e) => _move(e.localPosition),
                  onPointerUp: (_) {
                    _drag = null;
                    _rotating = false;
                  },
                  child: CustomPaint(
                    key: _boardKey,
                    size: Size(side, side),
                    painter: BoardPainter(
                      level: level,
                      pieces: pieces,
                      targets: targets,
                      wells: wells,
                      selected: sel,
                      time: t,
                      hp: hp,
                      hpMax: hpMax,
                      hintIdx: hintIdx >= 0 ? hintIdx : null,
                      hintT: hintT,
                      flash: flash,
                      flashTxt: flashTxt,
                      flashSub: flashSub,
                      hold: hold,
                      solved: solvedFlag,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _dock(),
              _pad(),
            ]);
          }),
          if (generating)
            Container(
              color: const Color(0xD1020406),
              child: const Center(
                child: Text('BÖLÜM ÜRETİLİYOR',
                    style: TextStyle(color: tealColor, fontSize: 12, letterSpacing: 5, fontFamily: 'monospace')),
              ),
            ),
          if (sheet != Sheet.none)
            Container(color: const Color(0xB8020406), child: SingleChildScrollView(child: _sheet())),
        ]),
      ),
    );
  }

  Widget _sheet() {
    switch (sheet) {
      case Sheet.menu:
        return MenuSheet(
          p: p,
          onPlay: () => _go(p.last >= 0 ? p.last : 0),
          onDaily: () => _go(dailyIndex),
          onLevels: () => setState(() => sheet = Sheet.levels),
          onShop: () => setState(() => sheet = Sheet.shop),
          onHow: () => setState(() => sheet = Sheet.how),
          onSound: () => setState(() {
            p.sound = !p.sound;
            snd.setOn(p.sound);
            saveProgress(p);
          }),
        );
      case Sheet.levels:
        return LevelGrid(
          p: p,
          current: li,
          onPick: (i) => _go(i),
          onClose: () => setState(() => sheet = Sheet.menu),
        );
      case Sheet.shop:
        return ShopSheet(
          p: p,
          hp: hp,
          onBuy: _buy,
          onClose: () => setState(() => sheet = Sheet.none),
        );
      case Sheet.how:
        return HowSheet(onClose: () => setState(() => sheet = Sheet.menu));
      case Sheet.noLife:
        return NoLifeSheet(
          p: p,
          wait: p.lifeWait(DateTime.now().millisecondsSinceEpoch),
          onBuy: _buyLife,
          onMenu: () => setState(() => sheet = Sheet.menu),
        );
      case Sheet.solved:
        return SolvedSheet(
          used: _used,
          par: _par,
          earned: _earned,
          coins: p.coins,
          isPar: _isPar,
          daily: li == dailyIndex,
          foot: _foot,
          onReplay: () => setState(() {
            _load(li);
            sheet = Sheet.none;
          }),
          onNext: () => _go(li == dailyIndex ? (p.last >= 0 ? p.last : 0) : li + 1),
        );
      case Sheet.none:
        return const SizedBox.shrink();
    }
  }

  Widget _hud() {
    final label = li == dailyIndex
        ? 'GÜNLÜK · ${level.key}'
        : '${(li + 1).toString().padLeft(2, '0')} · ${level.name}';
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: inkColor, fontSize: 13, fontFamily: 'monospace')),
        ),
        Text('♥ ${p.lives}',
            style: const TextStyle(color: Color(0xFFFF6A56), fontSize: 12, fontFamily: 'monospace')),
        const SizedBox(width: 8),
        Text('${p.coins} ◈', style: TextStyle(color: amberColor, fontSize: 12, fontFamily: 'monospace')),
        const SizedBox(width: 8),
        tayfButton('↺', () => setState(() => _load(li)), pad: 6),
        const SizedBox(width: 4),
        tayfButton('◌ ${p.hints}', _hint, pad: 6, dim: p.hints <= 0),
        const SizedBox(width: 4),
        tayfButton('⏭ $skipPrice◈', _skip, pad: 6, dim: p.coins < skipPrice && !solvedFlag),
        const SizedBox(width: 4),
        tayfButton('☰', () => setState(() => sheet = Sheet.menu), pad: 6),
      ]),
    );
  }

  Widget _dock() {
    final types = ['prism', 'mirror', 'lens'].where(inv.containsKey).toList();
    return SizedBox(
      height: 78,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final ty in types)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: InkWell(
              onTap: () => _addFromDock(ty),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(border: Border.all(color: const Color(0x80BEE1EB)), color: Colors.black),
                child: Opacity(
                  opacity: (inv[ty] ?? 0) > 0 ? 1 : 0.32,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${inv[ty] ?? 0}',
                        style: TextStyle(color: amberColor, fontSize: 18, fontFamily: 'monospace')),
                    Text(pieceName[ty]!,
                        style: const TextStyle(color: dimColor, fontSize: 10, fontFamily: 'monospace')),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  /// Dokunmatik ince ayar: gereken hassasiyet parmakla tutturulamıyor.
  Widget _pad() {
    final on = sel != null;
    return Opacity(
      opacity: on ? 1 : 0.3,
      child: IgnorePointer(
        ignoring: !on,
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _pb('↺ 1°', () => _rot(-1)),
            _pb('↺ 0.1°', () => _rot(-0.1)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(border: Border.all(color: const Color(0x80BEE1EB)), color: Colors.black),
              child: Text(on ? '${sel!.a.toStringAsFixed(1)}°' : '—',
                  style: TextStyle(color: amberColor, fontSize: 13, fontFamily: 'monospace')),
            ),
            _pb('0.1° ↻', () => _rot(0.1)),
            _pb('1° ↻', () => _rot(1)),
          ]),
          const SizedBox(height: 5),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _pb('◀', () => _nudge(-1, 0)),
            _pb('▲', () => _nudge(0, -1)),
            _pb('▼', () => _nudge(0, 1)),
            _pb('▶', () => _nudge(1, 0)),
            _pb('geri al ✕', _removeSelected),
          ]),
        ]),
      ),
    );
  }

  Widget _pb(String s, VoidCallback f) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: tayfButton(s, f, pad: 10));
}
