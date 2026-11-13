import 'package:test/test.dart';
import 'package:tayf/progress.dart';

void main() {
  group('can yenilenmesi', () {
    test('dolu canla sayaç sıfırlanır', () {
      final p = Progress()
        ..lives = lifeMax
        ..lifeT = 12345;
      expect(p.refreshLives(0), 0);
      expect(p.lifeT, 0);
    });

    test('30 dakikada bir can gelir', () {
      const now = 1000000;
      final p = Progress()..lives = 2;
      p.spendLife(now); // 1 cana düşer, sayaç başlar
      expect(p.lives, 1);
      expect(p.lifeT, now + lifeMs);

      expect(p.refreshLives(now + lifeMs - 1), 0, reason: 'bir ms erken');
      expect(p.lives, 1);

      expect(p.refreshLives(now + lifeMs), 1, reason: 'tam zamanında');
      expect(p.lives, 2);
    });

    test('uzun aradan sonra toplu dolar ama tavanı aşmaz', () {
      final p = Progress()..lives = 0;
      p.spendLife(0);
      final gained = p.refreshLives(lifeMs * 99);
      expect(p.lives, lifeMax);
      expect(gained, lifeMax);
      expect(p.lifeT, 0, reason: 'dolunca sayaç durur');
    });

    test('geri alınmış saat sayacı kilitlemez', () {
      final p = Progress()..lives = 1;
      p.lifeT = 10 * lifeMs; // gelecekte çok uzak
      p.refreshLives(0);
      expect(p.lifeT, lessThanOrEqualTo(lifeMs), reason: 'sayaç makul aralığa çekilir');
    });

    test('bekleme süresi biçimi', () {
      final p = Progress()..lives = 1;
      p.lifeT = 125000; // 2:05
      expect(p.lifeWait(0), '2:05');
      p.lifeT = 0;
      expect(p.lifeWait(0), '');
    });
  });

  group('satın alma', () {
    test('parası yetmeyen alım reddedilir ve bakiye değişmez', () {
      final p = Progress()..coins = 10;
      expect(p.buy(hintPrice), isFalse);
      expect(p.coins, 10);
    });
    test('yeten alım bakiyeden düşer', () {
      final p = Progress()..coins = 100;
      expect(p.buy(hintPrice), isTrue);
      expect(p.coins, 100 - hintPrice);
    });
    test('bakiye hiç eksiye düşmez', () {
      final p = Progress()..coins = 0;
      for (final price in [hintPrice, timePrice, piecePrice, lifePrice, skipPrice]) {
        p.buy(price);
      }
      expect(p.coins, 0);
    });
  });

  group('kilit', () {
    test('yeni oyuncuda yalnız ilk bölüm açık', () {
      final p = Progress();
      expect(p.maxOpen, 0);
    });
    test('bitirilen bölüm sonrakini açar', () {
      final p = Progress()..best = 3;
      expect(p.maxOpen, 3);
    });
  });

  group('kayıt', () {
    test('json gidip geldiğinde alanlar korunur', () {
      final a = Progress()
        ..coins = 42
        ..hints = 7
        ..lives = 2
        ..lifeT = 999
        ..best = 5
        ..last = 4
        ..daily = '2026-01-02'
        ..sound = false
        ..solved['ilk'] = 1
        ..par['tayf'] = 1;
      final b = Progress.fromJson(a.toJson());
      expect(b.coins, 42);
      expect(b.hints, 7);
      expect(b.lives, 2);
      expect(b.lifeT, 999);
      expect(b.best, 5);
      expect(b.last, 4);
      expect(b.daily, '2026-01-02');
      expect(b.sound, isFalse);
      expect(b.solved['ilk'], 1);
      expect(b.par['tayf'], 1);
    });
    test('eksik alanlar varsayılana düşer', () {
      final b = Progress.fromJson({});
      expect(b.coins, 0);
      expect(b.hints, 3);
      expect(b.lives, lifeMax);
      expect(b.best, 0);
      expect(b.last, -1);
    });
  });
}
