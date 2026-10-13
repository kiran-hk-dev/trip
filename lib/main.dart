import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../data/supabase_service.dart';
import '../router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Demo mode never touches the network, so Supabase stays uninitialised.
  if (!AppConfig.demoMode) {
    try {
      await SupabaseService.initialise();
      SupabaseService.instance.startConnectivityWatch();
    } catch (err) {
      // A misconfigured build must still run so the problem is visible rather
      // than a black screen. The router redirects to an explanatory screen.
      debugPrint('Supabase initialisation failed: $err');
    }
  }

  final ProviderContainer container = ProviderContainer();
  attachRouterAuth(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TripSplitApp(),
    ),
  );
}

class TripSplitApp extends StatelessWidget {
  const TripSplitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (BuildContext context, Widget? child) {
        // Clamp text scaling so a 2x accessibility setting cannot break the
        // dense money tables, while still honouring the user's preference up
        // to that limit.
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.4,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
