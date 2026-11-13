import 'package:test/test.dart';
import 'package:tayf/engine.dart';
import 'package:tayf/levels.dart';

/// JS motorundan ölçülmüş referans doldurma değerleri.
/// Dart portu bu sayıları tutturmazsa fizik birebir taşınmamış demektir.
const Map<String, List<double>> jsFills = {
  'ilk': [3.13],
  'tayf': [4.25, 1.61],
  'odak': [1.82],
  'tir': [2.17],
  'goz': [2.38, 1.98],
  'ikiz': [1.56],
};

void main() {
  group('ışın motoru JS ile eşleşiyor', () {
    for (final l in levels) {
      test('${l.id}: çözüm doldurmaları', () {
        final ts = simulate(l, l.sol);
        final want = jsFills[l.id]!;
        expect(ts.length, want.length, reason: 'algılayıcı sayısı');
        for (var i = 0; i < want.length; i++) {
          expect(ts[i].fill, closeTo(want[i], 0.01),
              reason: '${l.id} algılayıcı $i (${ts[i].kind}) '
                  'dart=${ts[i].fill.toStringAsFixed(3)} js=${want[i]}');
        }
      });

      test('${l.id}: boş tahtada çözülmüyor', () {
        expect(solved(simulate(l, const [])), isFalse);
      });

      test('${l.id}: her parça gerekli', () {
        for (var i = 0; i < l.sol.length; i++) {
          final sub = [
            for (var j = 0; j < l.sol.length; j++)
              if (j != i) l.sol[j]
          ];
          expect(solved(simulate(l, sub)), isFalse,
              reason: '${l.sol[i].type} çıkarılınca hâlâ çözülüyor');
        }
      });

      test('${l.id}: envanter çözüme yetiyor ve par doğru', () {
        final need = <String, int>{};
        for (final p in l.sol) {
          need[p.type] = (need[p.type] ?? 0) + 1;
        }
        need.forEach((k, v) => expect(l.inv[k] ?? 0, greaterThanOrEqualTo(v)));
        expect(l.par, l.sol.length);
      });
    }
  });

  test('Cauchy kırılma indisleri', () {
    // kırmızı uç ~1.476, mor uç ~1.612
    expect(nPrism[NW - 1], closeTo(1.476, 0.01));
    expect(nPrism[0], closeTo(1.612, 0.01));
  });
}
