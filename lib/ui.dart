// ignore: deprecated_member_use -- Flutter 3.50 prefers material_ui; keep the SDK-wide import until the project migrates.
import 'package:flutter/material.dart';
import 'backend/errors.dart';
import 'models.dart';
import 'store.dart';

const green = Color(0xFF176B50);
const ink = Color(0xFF17251F);
const muted = Color(0xFF68766F);
const canvas = Color(0xFFF5F7F4);
const line = Color(0xFFE7ECE8);

class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);
  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

Future<T?> guarded<T>(BuildContext context, Future<T> Function() op) async {
  try {
    return await op();
  } catch (e) {
    if (context.mounted) notice(context, friendlyError(e));
    return null;
  }
}

void notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, [this.subtitle, Key? key]) : super(key: key);
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
              header: true,
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 25, color: ink))),
          if (subtitle != null)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle!, style: const TextStyle(color: muted))),
        ]),
      );
}

class AppCard extends StatelessWidget {
  const AppCard(
      {super.key,
      required this.child,
      this.onTap,
      this.margin = const EdgeInsets.only(bottom: 12)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets margin;
  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: line)),
        child: Material(
            color: Colors.transparent,
            child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child:
                    Padding(padding: const EdgeInsets.all(14), child: child))),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.text, {super.key, this.tone = ChipTone.neutral});
  final String text;
  final ChipTone tone;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      ChipTone.good => (const Color(0xFFD9EFE4), const Color(0xFF0D503B)),
      ChipTone.warn => (const Color(0xFFFBEFCF), const Color(0xFF7A5600)),
      ChipTone.bad => (const Color(0xFFF8DAD7), const Color(0xFF8C1D16)),
      ChipTone.neutral => (const Color(0xFFE9EEEA), const Color(0xFF33423B)),
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text,
            style: TextStyle(
                color: fg, fontSize: 11, fontWeight: FontWeight.w700)));
  }
}

enum ChipTone { good, warn, bad, neutral }

ChipTone rfqTone(RfqStatus s) => switch (s) {
      RfqStatus.accepted => ChipTone.good,
      RfqStatus.cancelled => ChipTone.bad,
      RfqStatus.quoted => ChipTone.warn,
      _ => ChipTone.neutral
    };
ChipTone orderTone(OrderStatus s) => switch (s) {
      OrderStatus.delivered || OrderStatus.confirmed => ChipTone.good,
      OrderStatus.disputed || OrderStatus.cancelled => ChipTone.bad,
      OrderStatus.awaitingSellerConfirmation => ChipTone.warn,
      _ => ChipTone.neutral
    };

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.text,
      this.actionLabel,
      this.onAction});
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(children: [
          Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5EEE6),
                  borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, color: green, size: 29)),
          const SizedBox(height: 14),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted)),
          if (actionLabel != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                    onPressed: onAction, child: Text(actionLabel!))),
        ]),
      );
}

/// A product photo (or the category icon when the product has none), cropped to fill its box.
class ProductPhoto extends StatelessWidget {
  const ProductPhoto(this.product,
      {super.key,
      this.width,
      required this.height,
      this.radius = 13,
      this.iconSize = 32});
  final Product product;
  final double? width, height;
  final double radius, iconSize;
  @override
  Widget build(BuildContext context) {
    final p = product;
    return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
            width: width,
            height: height,
            color: p.color,
            child: p.photo == null
                ? Icon(p.icon, color: green, size: iconSize)
                : Image.asset(p.photo!,
                    fit: BoxFit.cover,
                    semanticLabel: p.name,
                    errorBuilder: (_, __, ___) =>
                        Icon(p.icon, color: green, size: iconSize))));
  }
}

class Disclaimer extends StatelessWidget {
  const Disclaimer(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(text,
          style: const TextStyle(fontSize: 11, color: muted, height: 1.45)));
}

/// Standard payment disclosure shown wherever an order total appears.
const paymentNotice =
    'Payment is arranged directly between buyer and supplier outside Susu Luma. Status stays "pending unverified" until confirmed by authorised staff with external evidence. No escrow, wallet or buyer-protection service is provided.';

class LabelValue extends StatelessWidget {
  const LabelValue(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(color: muted, fontSize: 12))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}
