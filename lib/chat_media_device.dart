import 'dart:async';
import 'dart:io' show File;
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'chat_media.dart';

/// Real camera, gallery, microphone and speaker. Plugins are created on first use so that merely
/// opening the app (or running widget tests) never touches a platform channel.
class DeviceMediaService implements MediaService {
  ImagePicker? _pickerInstance;
  AudioRecorder? _recorderInstance;
  AudioPlayer? _playerInstance;
  DateTime? _startedAt;
  String? _recordingPath;

  ImagePicker get _picker => _pickerInstance ??= ImagePicker();
  AudioRecorder get _recorder => _recorderInstance ??= AudioRecorder();
  AudioPlayer get _player => _playerInstance ??= AudioPlayer();

  @override
  Future<Attachment?> pickImage(ImageChoice choice) async {
    // Downscale and recompress on the phone: mobile data is expensive and slow.
    final file = await _picker.pickImage(
      source: choice == ImageChoice.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final mime = sniffImageMime(bytes);
    if (mime == null) throw MediaException('Photos must be JPEG, PNG or WebP.');
    return Attachment(
      kind: AttachmentKind.image,
      mime: mime,
      sizeBytes: bytes.length,
      bytes: bytes,
    );
  }

  @override
  Future<bool> startVoice() async {
    if (!await _recorder.hasPermission()) return false;
    String path = '';
    if (!kIsWeb) {
      final dir = await getTemporaryDirectory();
      path =
          '${dir.path}/luma_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
    }
    // Small mono voice quality: about 4 KB per second on phones.
    const phone = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 32000,
      sampleRate: 16000,
      numChannels: 1,
    );
    const browser = RecordConfig(encoder: AudioEncoder.opus);
    await _recorder.start(kIsWeb ? browser : phone, path: path);
    _startedAt = DateTime.now();
    _recordingPath = path;
    return true;
  }

  @override
  Future<Attachment?> stopVoice({bool cancel = false}) async {
    final started = _startedAt;
    final tempPath = _recordingPath;
    _startedAt = null;
    _recordingPath = null;
    if (cancel) {
      await _recorder.cancel();
      return null;
    }
    final path = await _recorder.stop();
    if (path == null || started == null) return null;
    final bytes = await XFile(path).readAsBytes();
    if (!kIsWeb && tempPath != null && tempPath.isNotEmpty) {
      try {
        await File(tempPath)
            .delete(); // do not leave voice files in the app cache
      } on Object {
        // Best effort only.
      }
    }
    final secs = (DateTime.now().difference(started).inMilliseconds / 1000)
        .round()
        .clamp(1, maxVoiceSeconds);
    return Attachment(
      kind: AttachmentKind.voice,
      mime: kIsWeb ? 'audio/webm' : 'audio/mp4',
      sizeBytes: bytes.length,
      seconds: max(1, secs),
      bytes: bytes,
    );
  }

  @override
  Future<void> play(Attachment a, {String? url}) async {
    final Source source =
        url != null ? UrlSource(url) : BytesSource(a.bytes!, mimeType: a.mime);
    await _player.stop();
    final done = _player.onPlayerStateChanged.firstWhere(
      (s) => s == PlayerState.completed || s == PlayerState.stopped,
    );
    await _player.play(source);
    await done;
  }

  @override
  Future<void> stopPlayback() async {
    await _playerInstance?.stop();
  }

  @override
  Future<void> dispose() async {
    await _recorderInstance?.dispose();
    await _playerInstance?.dispose();
  }
}
