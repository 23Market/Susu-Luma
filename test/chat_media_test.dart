import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/backend/errors.dart';
import 'package:susu_luma/backend/mappers.dart';
import 'package:susu_luma/chat_media.dart';
import 'package:susu_luma/main.dart';
import 'package:susu_luma/models.dart';
import 'package:susu_luma/store.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

Attachment _photo({int? size, String mime = 'image/png'}) => Attachment(
    kind: AttachmentKind.image,
    mime: mime,
    sizeBytes: size ?? _png.length,
    bytes: _png);

Attachment _voice({int seconds = 3, int size = 9000, String? mime}) =>
    Attachment(
        kind: AttachmentKind.voice,
        mime: mime ?? 'audio/mp4',
        sizeBytes: size,
        seconds: seconds,
        bytes: Uint8List(size));

class FakeMedia implements MediaService {
  bool allowMic = true;
  Attachment? image;
  Attachment? voice;
  Object? pickError;
  final log = <String>[];
  Completer<void>? playing;

  @override
  Future<Attachment?> pickImage(ImageChoice choice) async {
    log.add('pick:${choice.name}');
    if (pickError != null) throw pickError!;
    return image;
  }

  @override
  Future<bool> startVoice() async {
    log.add('start');
    return allowMic;
  }

  @override
  Future<Attachment?> stopVoice({bool cancel = false}) async {
    log.add(cancel ? 'cancel' : 'stop');
    return cancel ? null : voice;
  }

  @override
  Future<void> play(Attachment a, {String? url}) async {
    log.add('play');
    playing = Completer<void>();
    await playing!.future;
  }

  @override
  Future<void> stopPlayback() async {
    log.add('stopPlayback');
    final p = playing;
    if (p != null && !p.isCompleted) p.complete();
  }

  @override
  Future<void> dispose() async {}
}

Future<AppStore> _openChat(WidgetTester tester, FakeMedia media) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = AppStore(clock: () => DateTime(2026, 11, 20));
  await tester.pumpWidget(SusuLumaApp(store: store, media: media));
  await tester.tap(find.text('Continue as buyer'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Messages').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Freetown Building Supply'));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  group('limits and validation', () {
    test('accepts a normal photo and a normal voice note', () {
      expect(validateAttachment(_photo()), isNull);
      expect(validateAttachment(_voice()), isNull);
    });

    test('refuses oversize, empty and unsupported files', () {
      expect(validateAttachment(_photo(size: maxImageBytes + 1)),
          contains('5 MB'));
      expect(validateAttachment(_photo(size: 0)), contains('empty'));
      expect(validateAttachment(_photo(mime: 'image/gif')),
          contains('JPEG, PNG or WebP'));
      expect(validateAttachment(_voice(size: maxVoiceBytes + 1)),
          contains('2 MB'));
      expect(validateAttachment(_voice(mime: 'video/mp4')),
          contains('not supported'));
    });

    test('voice notes must be 1 to 60 seconds', () {
      expect(validateAttachment(_voice(seconds: 0)), contains('1 to 60'));
      expect(validateAttachment(_voice(seconds: 61)), contains('1 to 60'));
      expect(validateAttachment(_voice(seconds: 60)), isNull);
      expect(validateAttachment(_voice(seconds: 1)), isNull);
    });

    test('file type is read from the bytes, not the file name', () {
      expect(sniffImageMime(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
          'image/jpeg');
      expect(sniffImageMime(_png), 'image/png');
      expect(
          sniffImageMime(Uint8List.fromList(
              [...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits])),
          'image/webp');
      expect(
          sniffImageMime(Uint8List.fromList('GIF89a....'.codeUnits)), isNull);
      expect(sniffImageMime(Uint8List(0)), isNull);
    });

    test('storage paths match the shape the database requires', () {
      const thread = '3f1c2b4a-0d5e-4f6a-8b7c-9d0e1f2a3b4c';
      // Same pattern as send_media_message in 20261120000100_chat_media.sql.
      final sql = RegExp('^$thread/'
          r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
          r'\.(jpg|png|webp|m4a|webm|ogg)$');
      final rng = Random(1);
      for (final a in [
        _photo(mime: 'image/jpeg'),
        _photo(),
        _photo(mime: 'image/webp'),
        _voice(),
        _voice(mime: 'audio/webm'),
        _voice(mime: 'audio/ogg'),
      ]) {
        final p = newObjectPath(thread, a, random: rng);
        expect(sql.hasMatch(p), isTrue, reason: p);
      }
      expect(newObjectPath(thread, _photo(), random: Random(1)),
          isNot(newObjectPath(thread, _photo(), random: Random(2))));
    });

    test('durations read like a clock', () {
      expect(clock(0), '0:00');
      expect(clock(7), '0:07');
      expect(clock(60), '1:00');
    });

    test('friendly messages for media problems', () {
      expect(friendlyError(MediaException('Too big')), 'Too big');
      expect(friendlyError(Exception('media_invalid')), contains('5 MB'));
      expect(friendlyError(Exception('media_not_uploaded')),
          contains('did not finish uploading'));
    });
  });

  group('messages', () {
    test('an attachment-only message previews as Photo or Voice note', () {
      final at = DateTime(2026, 11, 20);
      expect(ChatMessage(Role.buyer, '', at, attachment: _photo()).preview,
          'Photo');
      expect(ChatMessage(Role.buyer, '', at, attachment: _voice()).preview,
          'Voice note');
      expect(ChatMessage(Role.buyer, 'Hello', at).preview, 'Hello');
      expect(ChatMessage(Role.buyer, 'Look', at, attachment: _photo()).preview,
          'Look');
    });

    test('server rows map to attachments and keep metadata only', () {
      final t = mapThread({
        'id': 'thr-1',
        'subject': 'Cement',
        'buyer_organization_id': 'org-1',
        'supplier_organization_id': 'sup-1',
        'messages': [
          {
            'sender_organization_id': 'sup-1',
            'body': '',
            'created_at': '2026-11-12T00:00:00Z',
            'attachment_kind': 'voice',
            'attachment_path': 'thr-1/a.m4a',
            'attachment_mime': 'audio/mp4',
            'attachment_bytes': 4800,
            'attachment_seconds': 12
          },
          {
            'sender_organization_id': 'org-1',
            'body': 'Site photo',
            'created_at': '2026-11-13T00:00:00Z',
            'attachment_kind': 'image',
            'attachment_path': 'thr-1/b.jpg',
            'attachment_mime': 'image/jpeg',
            'attachment_bytes': 180000,
            'attachment_seconds': null
          },
          {
            'sender_organization_id': 'org-1',
            'body': 'Plain text',
            'created_at': '2026-11-14T00:00:00Z'
          }
        ]
      }, orgNames: const {});
      final voice = t.messages[0].attachment!;
      expect(voice.kind, AttachmentKind.voice);
      expect(voice.seconds, 12);
      expect(voice.path, 'thr-1/a.m4a');
      expect(voice.bytes, isNull, reason: 'files are fetched on demand');
      expect(t.messages[0].from, Role.supplier);
      expect(t.messages[1].attachment!.kind, AttachmentKind.image);
      expect(t.messages[1].text, 'Site photo');
      expect(t.messages[2].attachment, isNull);
    });

    test('demo store adds the attachment as the current persona', () async {
      final s = AppStore(clock: () => DateTime(2026, 11, 20));
      s.role = Role.buyer;
      final thread = s.threads.first;
      final before = thread.messages.length;
      await s.sendAttachment(thread, _photo(), caption: ' Site ');
      expect(thread.messages.length, before + 1);
      expect(thread.messages.last.from, Role.buyer);
      expect(thread.messages.last.text, 'Site');
      expect(thread.messages.last.attachment!.kind, AttachmentKind.image);
    });

    test('demo store refuses an invalid attachment', () async {
      final s = AppStore();
      s.role = Role.buyer;
      final thread = s.threads.first;
      final before = thread.messages.length;
      await expectLater(s.sendAttachment(thread, _voice(seconds: 90)),
          throwsA(isA<MediaException>()));
      expect(thread.messages.length, before);
    });
  });

  group('chat screen', () {
    testWidgets('sending a photo shows it in the chat and the list',
        (tester) async {
      final media = FakeMedia()..image = _photo();
      final store = await _openChat(tester, media);
      await tester.tap(find.byTooltip('Send a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
      expect(media.log, ['pick:gallery']);
      expect(find.byType(Image), findsOneWidget);
      final last = store.threads.first.messages.last;
      expect(last.attachment!.kind, AttachmentKind.image);
      expect(last.from, Role.buyer);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Photo'), findsOneWidget);
    });

    testWidgets('camera option is offered', (tester) async {
      final media = FakeMedia()..image = _photo();
      await _openChat(tester, media);
      await tester.tap(find.byTooltip('Send a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();
      expect(media.log, ['pick:camera']);
    });

    testWidgets('cancelling the picker sends nothing', (tester) async {
      final media = FakeMedia();
      final store = await _openChat(tester, media);
      final before = store.threads.first.messages.length;
      await tester.tap(find.byTooltip('Send a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
      expect(store.threads.first.messages.length, before);
    });

    testWidgets('an unsupported file is explained, not sent', (tester) async {
      final media = FakeMedia()
        ..pickError = MediaException('Photos must be JPEG, PNG or WebP.');
      final store = await _openChat(tester, media);
      final before = store.threads.first.messages.length;
      await tester.tap(find.byTooltip('Send a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
      expect(find.text('Photos must be JPEG, PNG or WebP.'), findsOneWidget);
      expect(store.threads.first.messages.length, before);
    });

    testWidgets('an oversize photo is refused before sending', (tester) async {
      final media = FakeMedia()..image = _photo(size: maxImageBytes + 1);
      final store = await _openChat(tester, media);
      final before = store.threads.first.messages.length;
      await tester.tap(find.byTooltip('Send a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
      expect(find.text('That photo is too large. The limit is 5 MB.'),
          findsOneWidget);
      expect(store.threads.first.messages.length, before);
    });

    testWidgets('record, watch the timer, then send a voice note',
        (tester) async {
      final media = FakeMedia()..voice = _voice(seconds: 3);
      final store = await _openChat(tester, media);
      await tester.tap(find.byTooltip('Record voice note'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Recording 0:00 / 1:00'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Recording 0:03 / 1:00'), findsOneWidget);
      await tester.tap(find.byTooltip('Send voice note'));
      await tester.pumpAndSettle();
      expect(media.log, ['start', 'stop']);
      expect(find.text('Voice note · 0:03'), findsOneWidget);
      expect(find.text('Recording 0:03 / 1:00'), findsNothing);
      final last = store.threads.first.messages.last;
      expect(last.attachment!.kind, AttachmentKind.voice);
      expect(last.attachment!.seconds, 3);
    });

    testWidgets('cancelling a recording sends nothing', (tester) async {
      final media = FakeMedia()..voice = _voice();
      final store = await _openChat(tester, media);
      final before = store.threads.first.messages.length;
      await tester.tap(find.byTooltip('Record voice note'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byTooltip('Cancel recording'));
      await tester.pumpAndSettle();
      expect(media.log, ['start', 'cancel']);
      expect(store.threads.first.messages.length, before);
      expect(find.byTooltip('Record voice note'), findsOneWidget);
    });

    testWidgets(
        'without microphone permission the person is told how to fix it',
        (tester) async {
      final media = FakeMedia()..allowMic = false;
      await _openChat(tester, media);
      await tester.tap(find.byTooltip('Record voice note'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Allow microphone access to record voice notes.'),
          findsOneWidget);
      expect(find.text('Recording 0:00 / 1:00'), findsNothing);
    });

    testWidgets('recording stops and sends by itself at 60 seconds',
        (tester) async {
      final media = FakeMedia()..voice = _voice(seconds: 60);
      final store = await _openChat(tester, media);
      final before = store.threads.first.messages.length;
      await tester.tap(find.byTooltip('Record voice note'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(media.log, ['start', 'stop']);
      expect(store.threads.first.messages.length, before + 1);
      expect(find.text('Voice note · 1:00'), findsOneWidget);
    });

    testWidgets('a voice note plays and can be stopped', (tester) async {
      final media = FakeMedia()..voice = _voice(seconds: 5);
      await _openChat(tester, media);
      await tester.tap(find.byTooltip('Record voice note'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byTooltip('Send voice note'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Play voice note'));
      await tester.pumpAndSettle();
      expect(media.log.last, 'play');
      expect(find.byTooltip('Stop voice note'), findsOneWidget);
      await tester.tap(find.byTooltip('Stop voice note'));
      await tester.pumpAndSettle();
      expect(media.log.last, 'stopPlayback');
      expect(find.byTooltip('Play voice note'), findsOneWidget);
    });

    testWidgets('text messages still work and the input stays a single field',
        (tester) async {
      final store = await _openChat(tester, FakeMedia());
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Can you deliver Monday?');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Can you deliver Monday?'), findsOneWidget);
      expect(store.threads.first.messages.last.attachment, isNull);
    });
  });
}
