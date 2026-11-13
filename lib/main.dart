import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game.dart';
import 'render.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const TayfApp());
}

class TayfApp extends StatelessWidget {
  const TayfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TAYF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgColor,
        fontFamily: 'monospace',
      ),
      home: const GameScreen(),
    );
  }
}
