import 'package:test/test.dart';
import 'package:tayf/engine.dart';
import 'package:tayf/generator.dart';

/// Üretilen her bölüm şu güvenceleri sağlamalı:
///  • kayıtlı çözüm gerçekten çözüyor
///  • boş tahtada çözülmüyor
///  • hiçbir parça gereksiz değil
///  • envanter tam gereken kadar, par = çözüm uzunluğu
///  • eşikler tabanın altına düşmüyor
void checkLevel(Level l, {required String label}) {
  final ts = genProbe(l, l.sol, l.targets, false).ts;
  expect(genSolved(ts), isTrue, reason: '$label: çözüm çözmüyor');
  expect(genSolved(genProbe(l, const [], l.targets, false).ts), isFalse,
      reason: '$label: boş tahtada çözülüyor');
  for (var i = 0; i < l.sol.length; i++) {
    final sub = [
      for (var j = 0; j < l.sol.length; j++)
        if (j != i) l.sol[j]
    ];
    expect(genSolved(genProbe(l, sub, l.targets, false).ts), isFalse,
        reason: '$label: ${l.sol[i].type} gereksiz');
  }
  final need = <String, int>{};
  for (final p in l.sol) {
    need[p.type] = (need[p.type] ?? 0) + 1;
  }
  expect(l.inv.length, need.length, reason: '$label: envanterde fazla tür');
  need.forEach((k, v) => expect(l.inv[k], v, reason: '$label: $k sayısı'));
  expect(l.par, l.sol.length, reason: '$label: par');
  for (final t in l.targets) {
    expect(t.need!, greaterThanOrEqualTo(needFloor(t.kind)), reason: '$label: eşik tabanı');
  }
  expect(l.targets, isNotEmpty, reason: '$label: hedef yok');
}

void main() {
  group('tohumlu rastgelelik', () {
    test('mulberry aynı tohumda aynı diziyi verir', () {
      final a = mulberry(12345);
      final b = mulberry(12345);
      for (var i = 0; i < 50; i++) {
        expect(a(), b());
      }
    });
    test('değerler [0,1) aralığında', () {
      final r = mulberry(7);
      for (var i = 0; i < 500; i++) {
        final v = r();
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThan(1));
      }
    });
  });

  group('üretilen bölümler geçerli', () {
    for (final n in [7, 8, 9, 10, 12, 14, 16, 18, 20, 22]) {
      test('bölüm $n', () {
        final l = endlessLevel(n);
        checkLevel(l, label: 'bölüm $n');
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  });

  test('aynı numara aynı bölümü verir', () {
    final a = endlessLevel(11);
    final sigA = '${a.name}|${a.sol.map((p) => '${p.type}${p.x},${p.y},${p.a}').join()}|'
        '${a.targets.map((t) => '${t.kind}${t.x},${t.y},${t.need}').join()}';
    endlessCache.clear();
    final b = endlessLevel(11);
    final sigB = '${b.name}|${b.sol.map((p) => '${p.type}${p.x},${p.y},${p.a}').join()}|'
        '${b.targets.map((t) => '${t.kind}${t.x},${t.y},${t.need}').join()}';
    expect(sigB, sigA);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('zorluk geri düşmüyor: parça sayısı hep >= 2', () {
    for (var n = 7; n <= 20; n++) {
      expect(endlessLevel(n).par, greaterThanOrEqualTo(2), reason: 'bölüm $n');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('günün bölümü geçerli', () {
    checkLevel(dailyLevel(), label: 'günlük');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
