
/// Ekonomi sabitleri — web sürümüyle aynı.
const int coinClear = 10, coinPar = 10, coinDaily = 25;
const int hintPrice = 30, timePrice = 20, piecePrice = 25, lifePrice = 25, skipPrice = 30;
const double timeBonus = 45;
const int lifeMax = 5;
const int lifeMs = 30 * 60 * 1000; // 30 dakikada bir can

/// Kalıcı ilerleme. Canlar zaman damgasından hesaplanır, böylece oyun
/// kapalıyken de dolar.
class Progress {
  Map<String, int> solved = {};
  Map<String, int> par = {};
  int last = -1;
  int best = 0;
  bool sound = true;
  String daily = '';
  int coins = 0;
  int hints = 3;
  int lives = lifeMax;
  int lifeT = 0; // sonraki canın dolacağı an (epoch ms); 0 = dolu

  /// Oynanabilir en büyük indeks: bölümler sırayla açılır.
  int get maxOpen => best;

  /// Geçen süreye göre canları doldurur. Saf: `now` dışarıdan verilir.
  /// Kazanılan can sayısını döndürür.
  int refreshLives(int now) {
    if (lives >= lifeMax) {
      lifeT = 0;
      return 0;
    }
    if (lifeT == 0 || lifeT > now + lifeMs) lifeT = now + lifeMs;
    var gained = 0;
    while (lives < lifeMax && now >= lifeT) {
      lives++;
      gained++;
      lifeT = lives >= lifeMax ? 0 : lifeT + lifeMs;
    }
    return gained;
  }

  /// Sonraki cana kalan süre, "d:ss" biçiminde. Dolu ise boş metin.
  String lifeWait(int now) {
    if (lifeT == 0) return '';
    final ms = (lifeT - now).clamp(0, 1 << 40);
    final m = ms ~/ 60000, s = (ms ~/ 1000) % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Bir can harcar ve yenilenme sayacını başlatır.
  void spendLife(int now) {
    if (lives > 0) lives--;
    if (lifeT == 0) lifeT = now + lifeMs;
  }

  bool buy(int price) {
    if (coins < price) return false;
    coins -= price;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'solved': solved,
        'par': par,
        'last': last,
        'best': best,
        'sound': sound,
        'daily': daily,
        'coins': coins,
        'hints': hints,
        'lives': lives,
        'lifeT': lifeT,
      };

  static Progress fromJson(Map<String, dynamic> j) {
    final p = Progress();
    p.solved = Map<String, int>.from(j['solved'] as Map? ?? {});
    p.par = Map<String, int>.from(j['par'] as Map? ?? {});
    p.last = (j['last'] as num?)?.toInt() ?? -1;
    p.best = (j['best'] as num?)?.toInt() ?? 0;
    p.sound = j['sound'] as bool? ?? true;
    p.daily = j['daily'] as String? ?? '';
    p.coins = (j['coins'] as num?)?.toInt() ?? 0;
    p.hints = (j['hints'] as num?)?.toInt() ?? 3;
    p.lives = (j['lives'] as num?)?.toInt() ?? lifeMax;
    p.lifeT = (j['lifeT'] as num?)?.toInt() ?? 0;
    return p;
  }

}
