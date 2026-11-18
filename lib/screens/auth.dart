// ignore: deprecated_member_use -- Flutter 3.50 prefers material_ui; keep the SDK-wide import until the project migrates.
import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../ui.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 24),
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: green, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.storefront_rounded,
                  color: Colors.white, size: 28)),
          const SizedBox(height: 18),
          const Text('susu luma',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  letterSpacing: -1,
                  color: ink)),
          const SizedBox(height: 6),
          const Text(
              'Source and sell across Sierra Leone — request quotes, agree orders and track delivery.',
              style: TextStyle(color: muted, height: 1.4)),
          const SizedBox(height: 28),
          const Text('Prototype sign-in',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Choose a demo persona. No account or password is needed.',
              style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 12),
          _persona(Icons.shopping_bag_outlined, 'Continue as buyer',
              buyerBusiness.name, () => store.signIn(Role.buyer)),
          _persona(
              Icons.local_shipping_outlined,
              'Continue as supplier',
              store.supplier(supplierSelf).name,
              () => store.signIn(Role.supplier)),
          const Disclaimer(
              'Sample data only. Susu Luma is a marketplace and does not sell the listed products. No payments, escrow or wallet services are enabled. Real sign-in and verification arrive with the secure backend.'),
        ]),
      ),
    );
  }

  Widget _persona(
          IconData icon, String title, String subtitle, VoidCallback onTap) =>
      AppCard(
        onTap: onTap,
        child: Row(children: [
          Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5EEE6),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: green)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(subtitle,
                    style: const TextStyle(color: muted, fontSize: 12))
              ])),
          const Icon(Icons.chevron_right_rounded, color: muted),
        ]),
      );
}
