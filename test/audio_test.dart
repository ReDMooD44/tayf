import 'dart:math' as math;
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:tayf/audio_synth.dart';

double _peak(Float32List b) {
  var m = 0.0;
  for (final v in b) {
    if (v.abs() > m) m = v.abs();
  }
  return m;
}

double _rms(Float32List b) {
  var s = 0.0;
  for (final v in b) {
    s += v * v;
  }
  return math.sqrt(s / b.length);
}

String _ascii(Uint8List b, int off, int len) =>
    String.fromCharCodes(b.sublist(off, off + len));

void main() {
  group('sentez', () {
    test('uğultu döngüye uygun ve sessiz değil', () {
      final d = renderDrone();
      expect(d.length, (droneLoopSec * sampleRate).round());
      expect(_peak(d), lessThanOrEqualTo(1.0), reason: 'kırpılma yok');
      expect(_rms(d), greaterThan(0.02), reason: 'ses var');
      // döngü dikişi: son örnekler ile ilk örnekler birbirine yakın olmalı
      final head = d.sublist(0, 64), tail = d.sublist(d.length - 64);
      var diff = 0.0;
      for (var i = 0; i < 64; i++) {
        diff += (head[i] - tail[i]).abs();
      }
      expect(diff / 64, lessThan(0.25), reason: 'döngü başı/sonu kopuk');
    });

    test('her renk için ton üretilir', () {
      for (final k in toneHz.keys) {
        final t = renderTone(k);
        expect(t.length, (toneLoopSec * sampleRate).round(), reason: k);
        expect(_peak(t), closeTo(0.5, 0.01), reason: '$k tepe');
        expect(_rms(t), greaterThan(0.05), reason: '$k sessiz');
      }
    });

    test('ton frekansları tam sayı — dikişsiz döngü için şart', () {
      for (final e in toneHz.entries) {
        for (final f in e.value) {
          expect(f, f.round(), reason: '${e.key} $f');
        }
      }
    });

    test('tıkırtı kısa ve sönümlü', () {
      final c = renderClick();
      expect(c.length, (0.012 * sampleRate).round());
      final firstHalf = _rms(Float32List.fromList(c.sublist(0, c.length ~/ 2)));
      final lastHalf = _rms(Float32List.fromList(c.sublist(c.length ~/ 2)));
      expect(firstHalf, greaterThan(lastHalf * 2), reason: 'sönmüyor');
    });

    test('tıkırtı tohumlu: aynı sonucu verir', () {
      final a = renderClick(7), b = renderClick(7);
      for (var i = 0; i < a.length; i++) {
        expect(a[i], b[i]);
      }
    });

    test('blip süresi ve zarfı', () {
      final b = renderBlip(660, 880, 0.12);
      expect(b.length, ((0.12 + 0.08) * sampleRate).round());
      expect(_peak(b), closeTo(0.5, 0.01));
      expect(b[0].abs(), lessThan(0.01), reason: 'ataksız başlamalı');
    });

    test('çözüldü arpeji uzun ve kırpılmıyor', () {
      final s = renderSolved();
      expect(s.length, greaterThan(3 * sampleRate));
      expect(_peak(s), closeTo(0.85, 0.01));
      // yankı kuyruğu: son saniyede hâlâ ses olmalı
      final tail = Float32List.fromList(s.sublist(s.length - sampleRate));
      expect(_rms(tail), greaterThan(0.0005), reason: 'kuyruk yok');
    });
  });

  group('WAV paketleme', () {
    test('başlık geçerli', () {
      final w = wavBytes(Float32List(100));
      expect(_ascii(w, 0, 4), 'RIFF');
      expect(_ascii(w, 8, 4), 'WAVE');
      expect(_ascii(w, 12, 4), 'fmt ');
      expect(_ascii(w, 36, 4), 'data');
      final bd = ByteData.sublistView(w);
      expect(bd.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(bd.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(bd.getUint32(24, Endian.little), sampleRate);
      expect(bd.getUint16(34, Endian.little), 16, reason: 'bit derinliği');
      expect(bd.getUint32(40, Endian.little), 200, reason: 'veri boyu');
      expect(w.length, 44 + 200);
    });

    test('örnekler doğru ölçeklenir ve kırpılır', () {
      final src = Float32List.fromList([0, 1, -1, 2, -2, 0.5]);
      final w = wavBytes(src);
      final bd = ByteData.sublistView(w);
      expect(bd.getInt16(44, Endian.little), 0);
      expect(bd.getInt16(46, Endian.little), 32767);
      expect(bd.getInt16(48, Endian.little), -32767);
      expect(bd.getInt16(50, Endian.little), 32767, reason: 'üstü kırpılmalı');
      expect(bd.getInt16(52, Endian.little), -32767, reason: 'altı kırpılmalı');
      expect(bd.getInt16(54, Endian.little), (0.5 * 32767).round());
    });
  });

  test('ses bankası eksiksiz üretilir', () {
    final b = SoundBank.render();
    expect(b.drone.length, greaterThan(44));
    expect(b.tones.length, toneHz.length);
    for (final e in b.tones.entries) {
      expect(_ascii(e.value, 0, 4), 'RIFF', reason: e.key);
    }
    for (final w in [b.click, b.solved, b.pickUp, b.putDown, b.denied, b.hint]) {
      expect(_ascii(w, 0, 4), 'RIFF');
      expect(w.length, greaterThan(44));
    }
  });
}
