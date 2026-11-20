import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/main.dart';
import 'package:susu_luma/screens/buyer.dart' show categories;
import 'package:susu_luma/screens/luma_home.dart';
import 'package:susu_luma/store.dart';
import 'package:susu_luma/ui.dart';

class _FakeSpeaker implements HomeSpeaker {
  final spoken = <String>[];
  int stops = 0;
  Object? failWith;
  Completer<void>? holdOpen;

  @override
  Future<void> speak(String text) async {
    if (failWith != null) throw failWith!;
    spoken.add(text);
    await holdOpen?.future;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class _Tap {
  int? tab;
  String? category;
  int calls = 0;
  void call(int t, {String? category}) {
    tab = t;
    this.category = category;
    calls++;
  }
}

Future<void> _pump(WidgetTester tester, _FakeSpeaker speaker, _Tap tap) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(StoreScope(
      store: AppStore(clock: () => DateTime(2026, 11, 18)),
      child: MaterialApp(
          home: Scaffold(body: LumaHome(onTab: tap.call, speaker: speaker)))));
}

void main() {
  group('Luma home (guided start)', () {
    testWidgets('shows language switch, listen, find, categories and actions',
        (tester) async {
      await _pump(tester, _FakeSpeaker(), _Tap());
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Krio'), findsOneWidget);
      expect(find.text('Listen'), findsOneWidget);
      expect(find.text('Find products'), findsOneWidget);
      expect(find.text('Choose a category'), findsOneWidget);
      for (final t in ['BUILDING', 'FARMING', 'TOOLS', 'FOOD']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.text('ASK FOR\nPRICE'), findsOneWidget);
      expect(find.text('SELL AN\nITEM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each picture tile opens Discover on a real category',
        (tester) async {
      final tap = _Tap();
      await _pump(tester, _FakeSpeaker(), tap);
      const expected = {
        'BUILDING': 'Construction',
        'FARMING': 'Agriculture',
        'TOOLS': 'Equipment & Machinery',
        'FOOD': 'Food & Beverage',
      };
      for (final e in expected.entries) {
        await tester.tap(find.text(e.key));
        await tester.pump();
        expect(tap.tab, 1);
        expect(tap.category, e.value);
        expect(categories, contains(e.value));
      }
    });

    testWidgets('Find products and Ask for price go to Discover',
        (tester) async {
      final tap = _Tap();
      await _pump(tester, _FakeSpeaker(), tap);
      await tester.tap(find.text('Find products'));
      await tester.pump();
      expect([tap.tab, tap.category], [1, null]);
      await tester.tap(find.text('ASK FOR\nPRICE'));
      await tester.pump();
      expect(tap.tab, 1);
      expect(find.text('Choose a product, then tap Request quote.'),
          findsOneWidget);
    });

    testWidgets('Sell an item explains the supplier account requirement',
        (tester) async {
      final tap = _Tap();
      await _pump(tester, _FakeSpeaker(), tap);
      await tester.tap(find.text('SELL AN\nITEM'));
      await tester.pump();
      expect(find.text('Listing products needs a supplier business account.'),
          findsOneWidget);
      expect(tap.calls, 0, reason: 'does not navigate or create anything');
    });

    testWidgets(
        'Listen reads the English guide, Krio switch reads the Krio one',
        (tester) async {
      final speaker = _FakeSpeaker();
      await _pump(tester, speaker, _Tap());
      await tester.tap(find.text('Listen'));
      await tester.pumpAndSettle();
      expect(speaker.spoken, [lumaGuideEnglish]);
      await tester.tap(find.text('Krio'));
      await tester.pump();
      await tester.tap(find.text('Listen'));
      await tester.pumpAndSettle();
      expect(speaker.spoken, [lumaGuideEnglish, lumaGuideKrio]);
    });

    testWidgets('Listen becomes Stop while speaking and stops on tap',
        (tester) async {
      final speaker = _FakeSpeaker()..holdOpen = Completer<void>();
      await _pump(tester, speaker, _Tap());
      await tester.tap(find.text('Listen'));
      await tester.pump();
      expect(find.text('Stop'), findsOneWidget);
      await tester.tap(find.text('Stop'));
      await tester.pump();
      expect(speaker.stops, 1);
      expect(find.text('Listen'), findsOneWidget);
      speaker.holdOpen!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Listen'), findsOneWidget);
    });

    testWidgets('audio failure is reported, not thrown', (tester) async {
      final speaker = _FakeSpeaker()..failWith = StateError('no engine');
      await _pump(tester, speaker, _Tap());
      await tester.tap(find.text('Listen'));
      await tester.pumpAndSettle();
      expect(find.text('Audio guidance is unavailable on this device.'),
          findsOneWidget);
      expect(find.text('Listen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Luma home inside the buyer app', () {
    testWidgets('buyer lands on the Luma home and tiles filter Discover',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          SusuLumaApp(store: AppStore(clock: () => DateTime(2026, 11, 18))));
      await tester.tap(find.text('Continue as buyer'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a category'), findsOneWidget);
      await tester.tap(find.text('FARMING'));
      await tester.pumpAndSettle();
      final chip = tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Agriculture'));
      expect(chip.selected, isTrue);
      expect(find.text('Fresh Cocoa Beans'), findsOneWidget);
      expect(find.text('Portland Cement 50 kg'), findsNothing);
    });
  });
}
