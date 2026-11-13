import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'progress.dart';

/// İlerlemenin diske yazılması. Model (Progress) Flutter'dan bağımsız kalsın
/// diye ayrı tutulur; böylece ekonomi mantığı saf Dart testleriyle sınanabilir.
const String _key = 'tayf.progress';

Future<Progress> loadProgress() async {
  try {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_key);
    if (s == null) return Progress();
    return Progress.fromJson(jsonDecode(s) as Map<String, dynamic>);
  } catch (_) {
    return Progress();
  }
}

Future<void> saveProgress(Progress p) async {
  try {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(p.toJson()));
  } catch (_) {
    // kayıt başarısızsa oyun yine de oynanabilir
  }
}
