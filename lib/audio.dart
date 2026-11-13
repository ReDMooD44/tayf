import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:audioplayers/audioplayers.dart';
import 'audio_synth.dart';
import 'engine.dart';

/// Sentezlenen tamponları çalar. Sesler açılışta bir kez üretilir
/// (bkz. audio_synth.dart); burada yalnız çalma ve ses düzeyi yönetilir.
///
/// Ses, kullanıcının ilk dokunuşuna kadar başlatılmaz: tarayıcılar ve
/// mobil işletim sistemleri sesi ancak bir etkileşimden sonra açar.
class Audio {
  SoundBank? _bank;
  bool on;
  bool _started = false;

  static const double _droneVol = 0.35;

  final AudioPlayer _drone = AudioPlayer(playerId: 'drone');
  final Map<String, AudioPlayer> _tone = {};
  final AudioPlayer _oneShot = AudioPlayer(playerId: 'oneshot');
  final AudioPlayer _clickP = AudioPlayer(playerId: 'click');

  /// Hangi algılayıcı türünden kaç tane var — ton düzeyleri buna göre.
  final Map<String, double> _level = {};

  Audio({this.on = true});

  /// Web'de audioplayers BytesSource'u yok sayıyor; orada WAV'ı veri URI'si
  /// olarak veriyoruz. Mobilde bayt kaynağı doğrudan çalışır.
  final Map<Uint8List, Source> _srcCache = {};
  Source _src(Uint8List b) => _srcCache[b] ??= kIsWeb
      ? UrlSource('data:audio/wav;base64,${base64Encode(b)}')
      : BytesSource(b);

  /// Ses düzeyi play() çağrısının içinde verilmeli: kaynak atanırken
  /// öğe yeniden kurulduğu için önceden yapılan setVolume yutuluyor.
  Future<void> _start(AudioPlayer p, Uint8List data, double vol,
      {bool loop = false}) async {
    if (loop) await p.setReleaseMode(ReleaseMode.loop);
    await p.play(_src(data), volume: vol);
    await p.setVolume(vol); // çalma başladıktan sonra pekiştir
  }

  /// İlk kullanıcı etkileşiminde çağrılır.
  Future<void> ensure() async {
    if (_started) return;
    _started = true;
    try {
      _bank ??= SoundBank.render();
      final b = _bank!;
      await _start(_drone, b.drone, on ? _droneVol : 0, loop: true);
      for (final k in b.tones.keys) {
        final p = AudioPlayer(playerId: 'tone_$k');
        await _start(p, b.tones[k]!, 0, loop: true);
        _tone[k] = p;
      }
    } catch (_) {
      // ses açılamazsa oyun sessiz oynanmaya devam eder
    }
  }

  Future<void> setOn(bool v) async {
    on = v;
    try {
      await _drone.setVolume(on ? _droneVol : 0);
      if (!on) {
        for (final p in _tone.values) {
          await p.setVolume(0);
        }
      }
    } catch (_) {}
  }

  /// Algılayıcıların doluluğuna göre rezonans tonlarını sürer.
  void updateTargets(List<Target> targets) {
    if (!_started) return;
    _level.clear();
    for (final t in targets) {
      final v = _level[t.kind] ?? 0;
      final c = t.charge;
      _level[t.kind] = v > c ? v : c;
    }
    for (final e in _tone.entries) {
      final lvl = on ? (_level[e.key] ?? 0) : 0.0;
      // güç eğrisi: dolum arttıkça ton belirginleşsin
      final vol = (lvl * lvl * 0.22).clamp(0.0, 0.22);
      try {
        e.value.setVolume(vol);
      } catch (_) {}
    }
  }

  Future<void> _shot(AudioPlayer p, Uint8List? data, double vol) async {
    if (!on || !_started || data == null) return;
    try {
      await p.stop();
      await _start(p, data, vol);
    } catch (_) {}
  }

  void click() => _shot(_clickP, _bank?.click, 0.25);
  void hint() => _shot(_oneShot, _bank?.hint, 0.5);
  void pickUp() => _shot(_oneShot, _bank?.pickUp, 0.4);
  void putDown() => _shot(_oneShot, _bank?.putDown, 0.4);
  void denied() => _shot(_oneShot, _bank?.denied, 0.5);
  void solved() => _shot(_oneShot, _bank?.solved, 0.7);

  Future<void> dispose() async {
    await _drone.dispose();
    for (final p in _tone.values) {
      await p.dispose();
    }
    await _oneShot.dispose();
    await _clickP.dispose();
  }
}
