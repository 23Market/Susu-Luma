// ignore: deprecated_member_use -- Flutter 3.50 prefers material_ui; keep the SDK-wide import until the project migrates.
import 'package:flutter/material.dart';
import 'backend/config.dart';
import 'backend/live_store.dart';
import 'backend/remote_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'models.dart';
import 'screens/auth.dart';
import 'screens/buyer.dart';
import 'screens/supplier.dart';
import 'store.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppStore store;
  if (BackendConfig.isConfigured) {
    await Supabase.initialize(
        url: BackendConfig.url, publishableKey: BackendConfig.publishableKey);
    final live = LiveAppStore(SupabaseApi(Supabase.instance.client));
    try {
      await live.restore();
    } catch (_) {
      // Offline or expired session: fall through to the sign-in screen.
    }
    store = live;
  } else {
    store = AppStore(); // clearly labelled demo mode on sample data
  }
  runApp(SusuLumaApp(store: store));
}

class SusuLumaApp extends StatelessWidget {
  const SusuLumaApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => StoreScope(
        store: store,
        child: MaterialApp(
          title: 'Susu Luma',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: canvas,
            colorScheme: ColorScheme.fromSeed(seedColor: green),
            appBarTheme: const AppBarTheme(
                backgroundColor: canvas,
                foregroundColor: ink,
                scrolledUnderElevation: 0),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          home: const _Root(),
        ),
      );
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return switch (store.phase) {
      AuthPhase.signedOut =>
        store.isLive ? const LiveSignInScreen() : const SignInScreen(),
      AuthPhase.needsOrganization => const CreateBusinessScreen(),
      AuthPhase.ready => store.role == Role.supplier
          ? const SupplierShell()
          : const BuyerShell(),
    };
  }
}
