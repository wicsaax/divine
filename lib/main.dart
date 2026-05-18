import 'package:flutter/material.dart';

import 'core/astrology.dart';
import 'core/bazi.dart';
import 'core/biblio.dart';
import 'core/divination.dart';
import 'core/dream.dart';
import 'core/generic.dart';
import 'core/geomancy.dart';
import 'core/horoscope.dart';
import 'core/iching.dart';
import 'core/lenormand.dart';
import 'core/maya.dart';
import 'core/numerology.dart';
import 'core/ogham.dart';
import 'core/plum.dart';
import 'core/runes.dart';
import 'core/tarot.dart';
import 'core/yesno.dart';
import 'core/ziwei.dart';
import 'i18n/strings.dart';
import 'llm/config.dart';
import 'storage/app_settings.dart';
import 'storage/prompt_store.dart';
import 'ui/screens/home_screen.dart';

void _registerEngines() {
  DivinationRegistry.register(TarotEngine());
  DivinationRegistry.register(LenormandEngine());
  DivinationRegistry.register(IChingEngine());
  DivinationRegistry.register(PlumBlossomEngine());
  DivinationRegistry.register(HoroscopeEngine());
  DivinationRegistry.register(BaziEngine());
  DivinationRegistry.register(ZiWeiEngine());
  DivinationRegistry.register(AstrologyEngine());
  DivinationRegistry.register(NumerologyEngine());
  DivinationRegistry.register(RunesEngine());
  DivinationRegistry.register(OghamEngine());
  DivinationRegistry.register(GeomancyEngine());
  DivinationRegistry.register(MayaTzolkinEngine());
  DivinationRegistry.register(BiblioEngine());
  DivinationRegistry.register(DreamEngine());
  DivinationRegistry.register(YesNoEngine());
  DivinationRegistry.register(GenericEngine());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerEngines();
  await AppSettings.instance.load();
  await PromptStore.instance.load();
  S.setLocale(AppSettings.instance.locale);
  // 同步 settings.locale ↔ S.locale
  AppSettings.instance.addListener(() {
    S.setLocale(AppSettings.instance.locale);
  });
  final config = await LLMConfigStore.load();
  runApp(DivineApp(initialConfig: config));
}

class DivineApp extends StatelessWidget {
  const DivineApp({super.key, required this.initialConfig});
  final LLMConfig initialConfig;

  @override
  Widget build(BuildContext context) {
    // 监听 AppSettings 整体变更 (主题/字号), locale 监听走 S.locale
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (ctx, _) {
        return ValueListenableBuilder<String>(
          valueListenable: S.locale,
          builder: (ctx, locale, _) {
            return MaterialApp(
              title: 'divine',
              debugShowCheckedModeBanner: false,
              themeMode: AppSettings.instance.materialThemeMode,
              theme: _buildTheme(Brightness.light),
              darkTheme: _buildTheme(Brightness.dark),
              builder: (ctx, child) {
                final scale = AppSettings.instance.fontScale;
                return MediaQuery(
                  data: MediaQuery.of(ctx).copyWith(
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                );
              },
              home: HomeScreen(config: initialConfig),
            );
          },
        );
      },
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
