import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/router/app_router.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/core/theme/theme_mode_provider.dart';

/// The one locale the product supports. `PRODUCT.md` scopes Meu Auto to Brazil,
/// so this is a constant rather than a setting.
const ptBr = Locale('pt', 'BR');

void main() {
  ensurePtBrFormatting();
  runApp(const ProviderScope(child: MeuAutoApp()));
}

class MeuAutoApp extends ConsumerWidget {
  const MeuAutoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    return MaterialApp.router(
      title: 'Meu Auto',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // pt-BR is the only locale in scope, so it is pinned rather than left to
      // the device. Without these delegates every Material widget the app does
      // not write itself — date pickers above all — renders in English.
      locale: ptBr,
      supportedLocales: const [ptBr],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
