import 'package:flutter/material.dart';

import 'core/astrology.dart';
import 'core/bazi.dart';
import 'core/biblio.dart';
import 'core/divination.dart';
import 'core/generic.dart';
import 'core/iching.dart';
import 'core/lenormand.dart';
import 'core/numerology.dart';
import 'core/ogham.dart';
import 'core/plum.dart';
import 'core/runes.dart';
import 'core/tarot.dart';
import 'core/yesno.dart';
import 'core/ziwei.dart';
import 'llm/config.dart';
import 'ui/screens/home_screen.dart';

void _registerEngines() {
  // 顺序决定首页展示顺序; 把最常用/最有视觉感的放前面
  DivinationRegistry.register(TarotEngine());
  DivinationRegistry.register(LenormandEngine());
  DivinationRegistry.register(IChingEngine());
  DivinationRegistry.register(PlumBlossomEngine());
  DivinationRegistry.register(BaziEngine());
  DivinationRegistry.register(ZiWeiEngine());
  DivinationRegistry.register(AstrologyEngine());
  DivinationRegistry.register(NumerologyEngine());
  DivinationRegistry.register(RunesEngine());
  DivinationRegistry.register(OghamEngine());
  DivinationRegistry.register(BiblioEngine());
  DivinationRegistry.register(YesNoEngine());
  DivinationRegistry.register(GenericEngine());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerEngines();
  final config = await LLMConfigStore.load();
  runApp(DivineApp(initialConfig: config));
}

class DivineApp extends StatelessWidget {
  const DivineApp({super.key, required this.initialConfig});
  final LLMConfig initialConfig;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'divine',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: HomeScreen(config: initialConfig),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6B5B95),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
