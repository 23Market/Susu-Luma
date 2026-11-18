// ignore: deprecated_member_use -- Flutter 3.50 prefers material_ui; keep the SDK-wide import until the project migrates.
import 'package:flutter/material.dart';
import 'models.dart';
import 'screens/auth.dart';
import 'screens/buyer.dart';
import 'screens/supplier.dart';
import 'store.dart';
import 'ui.dart';

void main() => runApp(SusuLumaApp(store: AppStore()));

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
    return switch (store.role) {
      null => const SignInScreen(),
      Role.buyer => const BuyerShell(),
      Role.supplier => const SupplierShell(),
    };
  }
}
