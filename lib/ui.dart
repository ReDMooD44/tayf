import 'package:flutter/material.dart';
import 'engine.dart';
import 'generator.dart';
import 'levels.dart';
import 'progress.dart';
import 'render.dart';

/// Oyunun menü, liste, dükkân ve kilit ekranları.
/// Hepsi aynı koyu/monospace dilini paylaşır.

const _mono = 'monospace';

BoxDecoration _panel = BoxDecoration(
  color: const Color(0xFF0A1016),
  border: Border.all(color: const Color(0x59BEE1EB)),
);

Widget tayfButton(String label, VoidCallback? onTap, {bool dim = false, double pad = 9}) {
  return Opacity(
    opacity: dim ? 0.45 : 1,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: pad + 3, vertical: pad),
        decoration: BoxDecoration(border: Border.all(color: const Color(0x80BEE1EB)), color: Colors.black),
        child: Text(label, style: const TextStyle(color: inkColor, fontSize: 12, fontFamily: _mono)),
      ),
    ),
  );
}

Widget _spectrumBar() => Container(
      height: 4,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [
          Color(0xFF7A3CFF),
          Color(0xFF3A6BFF),
          Color(0xFF27D3FF),
          Color(0xFF3DFF8A),
          Color(0xFFFFE54A),
          Color(0xFFFF8A2A),
          Color(0xFFFF3B3B),
        ]),
      ),
    );

Widget _card({required Widget child, double maxW = 420}) => Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Container(
          decoration: _panel,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _spectrumBar(),
            Padding(padding: const EdgeInsets.fromLTRB(22, 20, 22, 18), child: child),
          ]),
        ),
      ),
    );

/* ---------------- ana menü ---------------- */

class MenuSheet extends StatelessWidget {
  final Progress p;
  final VoidCallback onPlay, onDaily, onLevels, onShop, onHow, onSound;
  const MenuSheet({
    super.key,
    required this.p,
    required this.onPlay,
    required this.onDaily,
    required this.onLevels,
    required this.onShop,
    required this.onHow,
    required this.onSound,
  });

  @override
  Widget build(BuildContext context) {
    final resume = p.last >= 0 ? p.last : 0;
    final name = resume < levels.length ? levels[resume].name : '';
    final sub = '${p.last >= 0 ? 'devam' : 'başla'} · '
        '${(resume + 1).toString().padLeft(2, '0')}${name.isEmpty ? '. bölüm' : ' $name'}';
    final pars = p.par.length;
    return _card(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('TAYF',
            style: TextStyle(color: Colors.white, fontSize: 30, letterSpacing: 12, fontFamily: _mono)),
        const SizedBox(height: 6),
        const Text('IŞIK VE OPTİK BULMACASI',
            style: TextStyle(color: dimColor, fontSize: 11, letterSpacing: 3, fontFamily: _mono)),
        const SizedBox(height: 6),
        const Text('altı elle tasarlanmış bölüm, ardından sonu olmayan bir dizi',
            textAlign: TextAlign.center,
            style: TextStyle(color: dimColor, fontSize: 10.5, fontFamily: _mono)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _big('OYNA', sub, onPlay)),
          const SizedBox(width: 9),
          Expanded(
              child: _big('GÜNLÜK',
                  p.daily == todayKey() ? 'bugünkü çözüldü ★' : 'bugüne özel bölüm', onDaily)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          tayfButton('bölümler ⊞', onLevels),
          tayfButton('dükkân ◈', onShop),
          tayfButton('nasıl oynanır ?', onHow),
          tayfButton(p.sound ? '♫ ses' : '♫ ses', onSound, dim: !p.sound),
        ]),
        const SizedBox(height: 14),
        Text(
          (p.best > 0 ? '${p.best}. BÖLÜME KADAR GELDİN' : 'İLK IŞIK SENİ BEKLİYOR') +
              (pars > 0 ? '   ·   $pars PAR' : ''),
          style: const TextStyle(color: tealColor, fontSize: 11, letterSpacing: 2, fontFamily: _mono),
        ),
      ]),
    );
  }

  Widget _big(String t, String s, VoidCallback f) => InkWell(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
          decoration: BoxDecoration(border: Border.all(color: const Color(0x80BEE1EB)), color: Colors.black),
          child: Column(children: [
            Text(t,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, letterSpacing: 4, fontFamily: _mono, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(s, textAlign: TextAlign.center, style: const TextStyle(color: dimColor, fontSize: 10, fontFamily: _mono)),
          ]),
        ),
      );
}

/* ---------------- bölüm listesi ---------------- */

class LevelGrid extends StatefulWidget {
  final Progress p;
  final int current;
  final void Function(int) onPick;
  final VoidCallback onClose;
  const LevelGrid({super.key, required this.p, required this.current, required this.onPick, required this.onClose});

  @override
  State<LevelGrid> createState() => _LevelGridState();
}

class _LevelGridState extends State<LevelGrid> {
  late int shown;
  final _sc = ScrollController();

  @override
  void initState() {
    super.initState();
    shown = (widget.p.best + 12).clamp(30, 1 << 20);
    // sonsuz akış: dibe yaklaşınca yeni bölümler eklenir
    _sc.addListener(() {
      if (_sc.position.pixels > _sc.position.maxScrollExtent - 160) {
        setState(() => shown += 18);
      }
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _card(
      maxW: 560,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('BÖLÜMLER',
              style: TextStyle(color: tealColor, fontSize: 13, letterSpacing: 5, fontFamily: _mono)),
          tayfButton('kapat ✕', widget.onClose, pad: 6),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 360,
          child: GridView.builder(
            controller: _sc,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170,
              childAspectRatio: 1.55,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: shown,
            itemBuilder: (_, i) => _tile(i),
          ),
        ),
      ]),
    );
  }

  Widget _tile(int i) {
    final gen = i >= levels.length;
    final cached = gen ? endlessCache[i + 1] : levels[i];
    final id = gen ? 'e${i + 1}' : levels[i].id;
    final done = gen ? widget.p.best >= i + 1 : widget.p.solved.containsKey(id);
    final isPar = widget.p.par.containsKey(id);
    final locked = i > widget.p.maxOpen;
    final cur = i == widget.current;
    return Opacity(
      opacity: locked ? 0.4 : 1,
      child: InkWell(
        onTap: locked ? null : () => widget.onPick(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: cur ? amberColor : const Color(0x4DBEE1EB)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text((i + 1).toString().padLeft(2, '0'),
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontFamily: _mono)),
              const SizedBox(width: 4),
              if (locked)
                const Text('⊘', style: TextStyle(color: dimColor, fontSize: 13, fontFamily: _mono))
              else if (isPar)
                Text('★', style: TextStyle(color: amberColor, fontSize: 13, fontFamily: _mono))
              else if (done)
                const Text('✓', style: TextStyle(color: tealColor, fontSize: 13, fontFamily: _mono)),
            ]),
            Text(
              locked ? 'kilitli' : (cached?.name ?? 'üretilecek'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: locked || cached == null ? dimColor : inkColor, fontSize: 11.5, fontFamily: _mono),
            ),
            Expanded(
              child: Text(
                locked ? 'önceki bölümü bitir' : (cached?.desc ?? 'girince hazırlanır'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: dimColor, fontSize: 9.5, fontFamily: _mono, height: 1.3),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/* ---------------- dükkân ---------------- */

class ShopSheet extends StatelessWidget {
  final Progress p;
  final double hp;
  final void Function(String) onBuy; // 'hint' | 'time' | 'prism' | 'mirror' | 'lens'
  final VoidCallback onClose;
  const ShopSheet(
      {super.key, required this.p, required this.hp, required this.onBuy, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('DÜKKÂN',
            style: TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 9, fontFamily: _mono)),
        const SizedBox(height: 6),
        Text('${p.hints} İPUCU HAKKI   ·   ${hp.ceil()} SN SÜRE',
            style: const TextStyle(color: dimColor, fontSize: 11, letterSpacing: 2, fontFamily: _mono)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          tayfButton('İPUCU +1 · $hintPrice ◈', () => onBuy('hint'), dim: p.coins < hintPrice),
          tayfButton('SÜRE +${timeBonus.toInt()} SN · $timePrice ◈', () => onBuy('time'),
              dim: p.coins < timePrice),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (final t in ['prism', 'mirror', 'lens'])
            tayfButton('${pieceName[t]} +1 · $piecePrice ◈', () => onBuy(t), dim: p.coins < piecePrice),
        ]),
        const SizedBox(height: 14),
        tayfButton('KAPAT', onClose),
        const SizedBox(height: 12),
        Text('${p.coins} ◈   ·   bölüm başına $coinClear ◈, par ile $coinPar ◈ daha',
            textAlign: TextAlign.center,
            style: const TextStyle(color: tealColor, fontSize: 10.5, fontFamily: _mono)),
      ]),
    );
  }
}

/* ---------------- can bitti ---------------- */

class NoLifeSheet extends StatelessWidget {
  final Progress p;
  final String wait;
  final VoidCallback onBuy, onMenu;
  const NoLifeSheet(
      {super.key, required this.p, required this.wait, required this.onBuy, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('CAN BİTTİ',
            style: TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 9, fontFamily: _mono)),
        const SizedBox(height: 8),
        Text('SONRAKİ CAN   $wait',
            style: const TextStyle(color: dimColor, fontSize: 12, letterSpacing: 2, fontFamily: _mono)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
          tayfButton('CAN AL · $lifePrice ◈', onBuy, dim: p.coins < lifePrice),
          tayfButton('MENÜ', onMenu),
        ]),
        const SizedBox(height: 12),
        Text('${p.coins} ◈   ·   her 30 dakikada bir can',
            style: const TextStyle(color: tealColor, fontSize: 10.5, fontFamily: _mono)),
      ]),
    );
  }
}

/* ---------------- nasıl oynanır ---------------- */

class HowSheet extends StatelessWidget {
  final VoidCallback onClose;
  const HowSheet({super.key, required this.onClose});

  static const _rows = [
    ['AMAÇ', ''],
    ['algılayıcı', 'her halkayı ışıkla doldur; 1,2 saniye dolu kalınca bölüm çözülür'],
    ['beyaz halka', 'sıcak, orta ve soğuk bantları aynı anda ister'],
    ['renkli halka', 'saf renk ister — beyaz ışık onu doldurmaz'],
    ['süre', 'üstteki bar erir; bitince bir can gider ve bölüm baştan başlar'],
    ['can ♥', '5 can; her 30 dakikada bir yenilenir, parayla da alınır'],
    ['parça', 'envanterde tam gereken kadar var; fazlası dükkândan alınır ama par\'ı bozar'],
    ['ipucu', 'bir parçanın yerini gösterir, hakkın azalır; biterse parayla alınır'],
    ['para', 'ilk kez bitirdiğin bölüm 10 ◈, par ile 10 ◈ daha, günlük 25 ◈'],
    ['sıra', 'bölümler sırayla açılır; atlamak 30 ◈'],
    ['PARÇALAR', ''],
    ['prizma', 'beyaz ışığı tayfına ayırır; dik girerse tam yansıma yapar'],
    ['ayna', 'yalnızca ön yüzü yansıtır, arkası ışığı durdurur'],
    ['mercek', 'dağılmış renkleri yeniden beyazda toplar'],
    ['DENETİM', ''],
    ['sürükle', 'alttan al, tahtaya bırak'],
    ['tutamaç', 'turuncu nokta parçayı döndürür; uzağa çekersen daha ince ayar'],
    ['◀ ▲ ▼ ▶', '1 px kaydırır'],
    ['↺ 0.1°', 'ince açı ayarı'],
  ];

  @override
  Widget build(BuildContext context) {
    return _card(
      maxW: 520,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('NASIL OYNANIR',
              style: TextStyle(color: tealColor, fontSize: 13, letterSpacing: 5, fontFamily: _mono)),
          tayfButton('kapat ✕', onClose, pad: 6),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 330,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in _rows)
                  if (r[1].isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Text(r[0],
                          style: TextStyle(color: amberColor, fontSize: 10, letterSpacing: 3, fontFamily: _mono)),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(
                          width: 92,
                          child: Text(r[0],
                              style: const TextStyle(color: tealColor, fontSize: 11.5, fontFamily: _mono)),
                        ),
                        Expanded(
                          child: Text(r[1],
                              style: const TextStyle(
                                  color: inkColor, fontSize: 11.5, fontFamily: _mono, height: 1.4)),
                        ),
                      ]),
                    ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

/* ---------------- çözüldü ---------------- */

class SolvedSheet extends StatelessWidget {
  final int used, par, earned, coins;
  final bool isPar, daily;
  final String foot;
  final VoidCallback onReplay, onNext;
  const SolvedSheet({
    super.key,
    required this.used,
    required this.par,
    required this.earned,
    required this.coins,
    required this.isPar,
    required this.daily,
    required this.foot,
    required this.onReplay,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('ÇÖZÜLDÜ',
            style: TextStyle(color: Colors.white, fontSize: 26, letterSpacing: 10, fontFamily: _mono)),
        const SizedBox(height: 8),
        Text('$used PARÇA KULLANILDI   ·   HEDEF $par',
            style: const TextStyle(color: dimColor, fontSize: 11, letterSpacing: 2, fontFamily: _mono)),
        const SizedBox(height: 6),
        Text(isPar ? '★  PAR' : '$par PARÇAYLA DA ÇÖZÜLÜYOR',
            style: TextStyle(
                color: isPar ? amberColor : dimColor,
                fontSize: isPar ? 13 : 11,
                letterSpacing: 2,
                fontFamily: _mono)),
        const SizedBox(height: 6),
        SizedBox(
          height: 18,
          child: Text(earned > 0 ? '+$earned ◈' : '',
              style: const TextStyle(color: tealColor, fontSize: 13, letterSpacing: 2, fontFamily: _mono)),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
          tayfButton('TEKRAR', onReplay),
          tayfButton(daily ? 'BÖLÜMLERE DÖN' : 'SONRAKİ BÖLÜM', onNext),
        ]),
        const SizedBox(height: 12),
        Text(foot, textAlign: TextAlign.center,
            style: const TextStyle(color: tealColor, fontSize: 10.5, letterSpacing: 1.5, fontFamily: _mono)),
      ]),
    );
  }
}
