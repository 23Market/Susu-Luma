import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Photos and voice notes inside a buyer/supplier thread.
///
/// Limits here mirror the database function `send_media_message` and the private `chat-media`
/// storage bucket. The server is the authority; this file only gives people a friendly early answer.
enum AttachmentKind { image, voice }

const maxImageBytes = 5 * 1024 * 1024;
const maxVoiceBytes = 2 * 1024 * 1024;
const maxVoiceSeconds = 60;
const imageMimes = {'image/jpeg', 'image/png', 'image/webp'};
const voiceMimes = {'audio/mp4', 'audio/webm', 'audio/ogg'};

/// Something a person tried to do with media that we can explain in plain words.
class MediaException implements Exception {
  MediaException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Attachment {
  const Attachment({
    required this.kind,
    required this.mime,
    required this.sizeBytes,
    this.seconds,
    this.bytes,
    this.path,
  });
  final AttachmentKind kind;
  final String mime;
  final int sizeBytes;

  /// Voice notes only.
  final int? seconds;

  /// Content held in memory: just picked/recorded, or demo mode (nothing is uploaded).
  final Uint8List? bytes;

  /// Private storage path in live mode: `<thread id>/<uuid>.<ext>`.
  final String? path;

  String get label => kind == AttachmentKind.image ? 'Photo' : 'Voice note';

  String get extension => switch (mime) {
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
        'audio/webm' => 'webm',
        'audio/ogg' => 'ogg',
        _ => 'm4a',
      };
}

/// Returns a message to show the person, or null when the attachment is acceptable.
String? validateAttachment(Attachment a) {
  if (a.sizeBytes <= 0) return 'That file is empty.';
  switch (a.kind) {
    case AttachmentKind.image:
      if (!imageMimes.contains(a.mime)) {
        return 'Photos must be JPEG, PNG or WebP.';
      }
      if (a.sizeBytes > maxImageBytes) {
        return 'That photo is too large. The limit is 5 MB.';
      }
    case AttachmentKind.voice:
      if (!voiceMimes.contains(a.mime)) {
        return 'That voice note format is not supported.';
      }
      final s = a.seconds ?? 0;
      if (s < 1 || s > maxVoiceSeconds) {
        return 'Voice notes can be 1 to $maxVoiceSeconds seconds long.';
      }
      if (a.sizeBytes > maxVoiceBytes) {
        return 'That voice note is too large. The limit is 2 MB.';
      }
  }
  return null;
}

/// Looks at the first bytes of a file instead of trusting its name.
String? sniffImageMime(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (b.length >= 4 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47) {
    return 'image/png';
  }
  if (b.length >= 12 &&
      b[0] == 0x52 && // R
      b[1] == 0x49 && // I
      b[2] == 0x46 && // F
      b[3] == 0x46 && // F
      b[8] == 0x57 && // W
      b[9] == 0x45 && // E
      b[10] == 0x42 && // B
      b[11] == 0x50) {
    // P
    return 'image/webp';
  }
  return null;
}

String _uuid4(Random rng) {
  final b = List<int>.generate(16, (_) => rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

/// `<thread id>/<random uuid>.<ext>`: the shape the database and storage policies require.
String newObjectPath(String threadId, Attachment a, {Random? random}) =>
    '$threadId/${_uuid4(random ?? Random.secure())}.${a.extension}';

String clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

enum ImageChoice { gallery, camera }

/// Everything that touches the phone's camera, gallery, microphone and speaker.
/// The real implementation lives in chat_media_device.dart; tests use a fake.
abstract class MediaService {
  /// Null when the person cancelled. Throws [MediaException] for unsupported files.
  Future<Attachment?> pickImage(ImageChoice choice);

  /// False when microphone permission was not granted.
  Future<bool> startVoice();

  /// Stops recording. Null when cancelled or nothing usable was captured.
  Future<Attachment?> stopVoice({bool cancel = false});

  /// Completes when playback finishes or is stopped. Uses [url] when the file is remote.
  Future<void> play(Attachment a, {String? url});
  Future<void> stopPlayback();
  Future<void> dispose();
}

class MediaScope extends InheritedWidget {
  const MediaScope({super.key, required this.service, required super.child});
  final MediaService service;
  static MediaService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MediaScope>()!.service;
  @override
  bool updateShouldNotify(MediaScope oldWidget) => service != oldWidget.service;
}
