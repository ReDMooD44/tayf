import 'dart:math' as math;
import 'dart:typed_data';

/// Prosedürel ses sentezi — harici dosya yok, her şey burada üretilir.
///
/// Web sürümü Web Audio grafiğiyle gerçek zamanlı çalıyordu; Flutter'da
/// karşılığı olmadığı için sesler açılışta PCM olarak hesaplanıp WAV
/// tamponlarına yazılır, sonra döngüyle veya tek atışla çalınır.
///
/// Bu dosya saf Dart: Flutter'a bağlı değil, testlerle sınanabilir.

const int sampleRate = 44100;

/// Döngü uzunluğu. Tüm uğultu frekansları bu sürede tam sayıda çevrim
/// tamamlar, böylece döngü başı ile sonu arasında tıklama olmaz.
const double droneLoopSec = 10;

/// Hedef tonu döngüsü (1 sn): frekanslar tam sayı Hz seçilir ki dikişsiz dönsün.
const double toneLoopSec = 1;

const Map<String, List<int>> toneHz = {
  'white': [440, 554, 659],
  'red': [277],
  'amber': [330],
  'green': [415],
  'blue': [494],
};

/// Tohumlu gürültü: testler yinelenebilir olsun diye.
class _Rnd {
  int _s;
  _Rnd(this._s);
  double next() {
    _s = (_s * 1103515245 + 12345) & 0x7FFFFFFF;
    return _s / 0x7FFFFFFF * 2 - 1;
  }
}

/// Tek kutuplu alçak geçiren.
class _LP {
  double _y = 0;
  double process(double x, double cut) {
    final a = 1 - math.exp(-2 * math.pi * cut / sampleRate);
    _y += a * (x - _y);
    return _y;
  }
}

/// Tek kutuplu yüksek geçiren (alçak geçirenin tümleyeni).
class _HP {
  final _lp = _LP();
  double process(double x, double cut) => x - _lp.process(x, cut);
}

double _tri(double phase) {
  final p = phase % 1.0;
  return p < 0.5 ? (4 * p - 1) : (3 - 4 * p);
}

/// Geri beslemeli gecikme — yankı yerine geçer, kuyruğu sese katar.
void _reverb(Float32List b, {double delaySec = 0.34, double fb = 0.36, double wet = 0.42}) {
  final d = (delaySec * sampleRate).round();
  if (d <= 0 || d >= b.length) return;
  final lp = _LP();
  for (var i = d; i < b.length; i++) {
    final echo = lp.process(b[i - d], 2400);
    b[i] += echo * fb * wet;
  }
}

void _normalize(Float32List b, double peak) {
  var mx = 0.0;
  for (final v in b) {
    final a = v.abs();
    if (a > mx) mx = a;
  }
  if (mx <= 1e-9) return;
  final k = peak / mx;
  for (var i = 0; i < b.length; i++) {
    b[i] *= k;
  }
}

/// Ortam uğultusu — döngüye uygun, alçak geçirenden geçmiş birkaç osilatör.
Float32List renderDrone() {
  final n = (droneLoopSec * sampleRate).round();
  final out = Float32List(n);
  final lp = _LP();
  // [frekans, kazanç, üçgen mi]
  const voices = [
    [98.0, 0.6, 1.0],
    [146.8, 0.5, 0.0],
    [49.0, 0.5, 0.0],
    [196.4, 0.12, 1.0],
  ];
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    var s = 0.0;
    for (final v in voices) {
      final ph = v[0] * t;
      s += (v[2] == 1.0 ? _tri(ph) : math.sin(2 * math.pi * ph)) * v[1];
    }
    // süzgeç kesimi yavaşça salınır (döngüde tam 1 çevrim)
    final cut = 320 + 120 * math.sin(2 * math.pi * t / droneLoopSec);
    var y = lp.process(s, cut);
    // genlik de çok yavaş nefes alır (tam 2 çevrim)
    y *= 1 + 0.035 * math.sin(4 * math.pi * t / droneLoopSec);
    out[i] = y;
  }
  _normalize(out, 0.45);
  return out;
}

/// Hedef rezonans tonu — renk başına sinüs yığını, döngüye uygun.
Float32List renderTone(String kind) {
  final hz = toneHz[kind] ?? toneHz['white']!;
  final n = (toneLoopSec * sampleRate).round();
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    var s = 0.0;
    for (final f in hz) {
      s += math.sin(2 * math.pi * f * t);
      s += _tri(2 * f * t) * 0.18; // üst harmonik
    }
    out[i] = s / hz.length;
  }
  _normalize(out, 0.5);
  return out;
}

/// Döndürme tıkırtısı — 12 ms yüksek geçiren gürültü darbesi.
Float32List renderClick([int seed = 7]) {
  final n = (0.012 * sampleRate).round();
  final out = Float32List(n);
  final r = _Rnd(seed);
  final hp = _HP();
  for (var i = 0; i < n; i++) {
    final env = math.exp(-i / sampleRate / 0.0025);
    out[i] = hp.process(r.next(), 3200) * env;
  }
  _normalize(out, 0.5);
  return out;
}

/// Arayüz sesi — frekansı kayan kısa sinüs.
Float32List renderBlip(double f0, double f1, double dur) {
  final n = ((dur + 0.08) * sampleRate).round();
  final out = Float32List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final k = (t / dur).clamp(0.0, 1.0);
    final f = f0 * math.pow(f1 / f0, k); // üstel kayma
    phase += f / sampleRate;
    double env;
    if (t < 0.008) {
      env = t / 0.008;
    } else {
      env = math.exp(-(t - 0.008) / (dur * 0.7 + 0.05));
    }
    out[i] = math.sin(2 * math.pi * phase) * env;
  }
  _normalize(out, 0.5);
  return out;
}

/// FM çan — çözüm arpejinin tek notası.
void _bell(Float32List b, double f, double t0, double vel) {
  final start = (t0 * sampleRate).round();
  final len = (2.8 * sampleRate).round();
  var phase = 0.0;
  for (var i = 0; i < len; i++) {
    final j = start + i;
    if (j < 0 || j >= b.length) continue;
    final t = i / sampleRate;
    // modülasyon derinliği hızla söner
    final idx = f * 2.2 * math.exp(-t / 0.32) + f * 0.05;
    final mod = math.sin(2 * math.pi * f * 3.01 * t) * idx;
    phase += (f + mod) / sampleRate;
    final env = t < 0.006 ? t / 0.006 : math.exp(-(t - 0.006) / 0.55);
    b[j] += math.sin(2 * math.pi * phase) * env * vel;
  }
}

/// Çözüldü arpeji — E maj9, yankılı.
Float32List renderSolved() {
  const notes = [329.63, 415.3, 493.88, 622.25, 739.99, 987.77];
  final dur = 0.115 * notes.length + 3.0;
  final out = Float32List((dur * sampleRate).round());
  for (var i = 0; i < notes.length; i++) {
    _bell(out, notes[i], i * 0.115, 0.13);
  }
  _bell(out, 164.81, 0, 0.1);
  _bell(out, 1318.5, notes.length * 0.115 + 0.1, 0.07);
  _reverb(out);
  _normalize(out, 0.85);
  return out;
}

/// 16-bit mono WAV baytları.
Uint8List wavBytes(Float32List mono, {int rate = sampleRate}) {
  final n = mono.length;
  final dataBytes = n * 2;
  final b = ByteData(44 + dataBytes);
  void ascii(int off, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  b.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  b.setUint32(16, 16, Endian.little); // PCM blok boyu
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little); // bayt/sn
  b.setUint16(32, 2, Endian.little); // blok hizası
  b.setUint16(34, 16, Endian.little); // bit
  ascii(36, 'data');
  b.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < n; i++) {
    final v = (mono[i].clamp(-1.0, 1.0) * 32767).round();
    b.setInt16(44 + i * 2, v, Endian.little);
  }
  return b.buffer.asUint8List();
}

/// Oyunun kullandığı tüm sesler, bir kez üretilir.
class SoundBank {
  final Uint8List drone;
  final Map<String, Uint8List> tones;
  final Uint8List click;
  final Uint8List solved;
  final Uint8List pickUp, putDown, denied, hint;

  SoundBank._({
    required this.drone,
    required this.tones,
    required this.click,
    required this.solved,
    required this.pickUp,
    required this.putDown,
    required this.denied,
    required this.hint,
  });

  static SoundBank render() => SoundBank._(
        drone: wavBytes(renderDrone()),
        tones: {for (final k in toneHz.keys) k: wavBytes(renderTone(k))},
        click: wavBytes(renderClick()),
        solved: wavBytes(renderSolved()),
        pickUp: wavBytes(renderBlip(420, 560, 0.05)),
        putDown: wavBytes(renderBlip(360, 240, 0.07)),
        denied: wavBytes(renderBlip(300, 200, 0.09)),
        hint: wavBytes(renderBlip(660, 880, 0.12)),
      );
}
