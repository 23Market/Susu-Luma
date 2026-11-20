import 'dart:async';

// ignore: deprecated_member_use -- Flutter 3.50 prefers material_ui; keep the SDK-wide import until the project migrates.
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models.dart';
import '../ui.dart';

const _sun = Color(0xFFFFD54F);

/// Audio guide for the home screen. English is the official text. The Krio
/// script is a first draft carried over from the original Luma home page and
/// must be reviewed by Krio speakers before any pilot use.
const lumaGuideEnglish =
    'Tap Find products, or choose a picture for building, farming, tools, '
    'or food. Tap Ask for price to request a quote. '
    'Tap Sell an item to list a product.';
const lumaGuideKrio =
    'Tap di Find products button, or tap wan picture for wetin yu de look for. '
    'Tap Ask for price for ask wan seller how much. '
    'Tap Sell an item for put you business pan Luma.';

/// Reads text aloud. Kept behind an interface so tests need no platform plugin.
abstract class HomeSpeaker {
  Future<void> speak(String text);
  Future<void> stop();
}

class TtsHomeSpeaker implements HomeSpeaker {
  final FlutterTts _tts = FlutterTts();

  @override
  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.42);
    await _tts.setVolume(1);
    try {
      await _tts.awaitSpeakCompletion(true);
    } on Object {
      // Not supported on every platform; the Stop button still works.
    }
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

class _Tile {
  const _Tile(this.label, this.category, this.icon, this.background);
  final String label, category;
  final IconData icon;
  final Color background;
}

/// Picture tiles. Categories must exist in the buyer taxonomy (`categories`).
const _tiles = [
  _Tile('BUILDING', 'Construction', Icons.foundation_rounded, _sun),
  _Tile('FARMING', 'Agriculture', Icons.eco_rounded, Color(0xFFD9EEE1)),
  _Tile('TOOLS', 'Equipment & Machinery', Icons.handyman_rounded,
      Color(0xFFFAD9D6)),
  _Tile('FOOD', 'Food & Beverage', Icons.rice_bowl_rounded, Color(0xFFFFE9A9)),
];

/// Guided-start home screen (Variation C): big pictures, audio help, three
/// obvious actions. English is the official language; Krio is audio only.
class LumaHome extends StatefulWidget {
  const LumaHome({super.key, required this.onTab, this.speaker});
  final void Function(int, {String? category}) onTab;
  final HomeSpeaker? speaker;
  @override
  State<LumaHome> createState() => _LumaHomeState();
}

class _LumaHomeState extends State<LumaHome> {
  HomeSpeaker? _speaker;
  bool _krio = false, _speaking = false;

  // Created on first use so the platform plugin is never touched until needed.
  HomeSpeaker get _voice => _speaker ??= widget.speaker ?? TtsHomeSpeaker();

  @override
  void dispose() {
    final s = _speaker;
    if (s != null) unawaited(s.stop().catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _toggleGuide() async {
    if (_speaking) {
      try {
        await _voice.stop();
      } on Object {
        // Nothing to stop.
      }
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    try {
      await _voice.speak(_krio ? lumaGuideKrio : lumaGuideEnglish);
    } on Object {
      if (mounted) {
        notice(context, 'Audio guidance is unavailable on this device.');
      }
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final quoted =
        store.myRfqs.where((r) => r.status == RfqStatus.quoted).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: [
        Row(children: [
          Expanded(
              child: SegmentedButton<bool>(
                  segments: const [
                ButtonSegment(value: false, label: Text('English')),
                ButtonSegment(value: true, label: Text('Krio')),
              ],
                  selected: {
                _krio
              },
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _krio = s.first))),
          const SizedBox(width: 10),
          FilledButton.icon(
              onPressed: _toggleGuide,
              icon: Icon(
                  _speaking ? Icons.stop_rounded : Icons.volume_up_rounded),
              label: Text(_speaking ? 'Stop' : 'Listen')),
        ]),
        const SizedBox(height: 16),
        Semantics(
          button: true,
          label: 'Find products',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => widget.onTab(1),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              constraints: const BoxConstraints(minHeight: 76),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                  color: const Color(0xFFE7F2EC),
                  borderRadius: BorderRadius.circular(22)),
              child: const Row(children: [
                CircleAvatar(
                    radius: 24,
                    backgroundColor: green,
                    child: Icon(Icons.search_rounded,
                        color: Colors.white, size: 28)),
                SizedBox(width: 14),
                Expanded(
                    child: Text('Find products',
                        style: TextStyle(
                            color: ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800))),
                Icon(Icons.arrow_forward_rounded, color: green),
              ]),
            ),
          ),
        ),
        if (quoted > 0)
          AppCard(
              margin: const EdgeInsets.only(top: 14),
              onTap: () => widget.onTab(2),
              child: Row(children: [
                const Icon(Icons.notifications_active_outlined, color: green),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        '$quoted RFQ${quoted == 1 ? ' has' : 's have'} quotes waiting for your decision',
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                const Icon(Icons.chevron_right_rounded, color: muted)
              ])),
        const SizedBox(height: 20),
        const Text('Choose a category',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 20, color: ink)),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth > 640;
            return GridView.count(
              crossAxisCount: wide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: wide ? 1.1 : 1.28,
              children: [
                for (final t in _tiles)
                  _TileButton(t,
                      onTap: () => widget.onTab(1, category: t.category)),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _ActionButton(
                  label: 'ASK FOR\nPRICE',
                  icon: Icons.request_quote_rounded,
                  color: green,
                  foreground: Colors.white,
                  onTap: () {
                    widget.onTab(1);
                    notice(
                        context, 'Choose a product, then tap Request quote.');
                  })),
          const SizedBox(width: 12),
          Expanded(
              child: _ActionButton(
                  label: 'SELL AN\nITEM',
                  icon: Icons.storefront_rounded,
                  color: _sun,
                  foreground: green,
                  onTap: () => notice(context,
                      'Listing products needs a supplier business account.'))),
        ]),
        const Disclaimer(
            'Prototype notice: listings and supplier details are illustrative sample data, not live offers.'),
      ],
    );
  }
}

class _TileButton extends StatelessWidget {
  const _TileButton(this.tile, {required this.onTap});
  final _Tile tile;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tile.label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: tile.background,
                borderRadius: BorderRadius.circular(22)),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(tile.icon, color: green, size: 48),
              const SizedBox(height: 9),
              Text(tile.label,
                  style: const TextStyle(
                      color: green,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .4)),
            ]),
          ),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.foreground,
      required this.onTap});
  final String label;
  final IconData icon;
  final Color color, foreground;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label.replaceAll('\n', ' '),
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            height: 104,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Icon(icon, color: foreground, size: 36),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: foreground,
                          fontSize: 17,
                          height: 1.1,
                          fontWeight: FontWeight.w900))),
            ]),
          ),
        ),
      );
}
