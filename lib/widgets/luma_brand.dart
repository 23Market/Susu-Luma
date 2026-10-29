import 'package:flutter/material.dart';

abstract final class LumaBrandAssets {
  static const primary = 'assets/branding/luma-primary.png';
  static const stall = 'assets/branding/luma-stall.png';
}

class LumaBrand extends StatelessWidget {
  const LumaBrand({
    super.key,
    this.compact = false,
    this.height = 48,
    this.fit = BoxFit.contain,
  });

  final bool compact;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Semantics(
        label: compact
            ? 'Luma marketplace emblem'
            : 'Luma Industrial Marketplace Sierra Leone',
        image: true,
        child: ExcludeSemantics(
          child: Image.asset(
            compact ? LumaBrandAssets.stall : LumaBrandAssets.primary,
            height: height,
            fit: fit,
            filterQuality: FilterQuality.high,
          ),
        ),
      );
}
