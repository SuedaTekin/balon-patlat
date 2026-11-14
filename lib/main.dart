import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads.dart';
import 'audio.dart';
import 'billing.dart';
import 'cloud/cloud.dart';
import 'home.dart';
import 'progress.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Progress.load();
  await Cloud.init();
  await Sfx.init();
  Sfx.playMusic('menu');
  Billing.init();
  Ads.init();
  runApp(const BalonApp());
}

class BalonApp extends StatelessWidget {
  const BalonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balon Patlat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: LP.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: LP.ruby,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeShell(),
    );
  }
}
