import 'dart:async';

// ignore: deprecated_member_use -- Flutter 3.50 prefers material_ui; keep the SDK-wide import until the project migrates.
import 'package:flutter/material.dart';
import '../chat_media.dart';
import '../models.dart';
import '../ui.dart';

/// Message input: photo, text, voice note and send. Voice notes work like WhatsApp: tap the
/// microphone to record, then send or cancel. Recording stops by itself at 60 seconds.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSendText,
    required this.onAttachment,
  });
  final TextEditingController controller;
  final VoidCallback onSendText;
  final Future<void> Function(Attachment) onAttachment;
  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  bool _recording = false, _busy = false;
  int _secs = 0;
  Timer? _tick;
  MediaService? _media;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaScope.of(context);
  }

  @override
  void dispose() {
    _tick?.cancel();
    final media = _media;
    if (_recording && media != null) {
      unawaited(
          media.stopVoice(cancel: true).then((_) {}, onError: (Object _) {}));
    }
    unawaited(media?.stopPlayback().then((_) {}, onError: (Object _) {}));
    super.dispose();
  }

  Future<void> _submit(Attachment a) async {
    final problem = validateAttachment(a);
    if (problem != null) {
      notice(context, problem);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onAttachment(a);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPhoto() async {
    final choice = await showModalBottomSheet<ImageChoice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageChoice.gallery)),
          ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageChoice.camera)),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      final a = await _media!.pickImage(choice);
      if (a == null || !mounted) return;
      await _submit(a);
    } on MediaException catch (e) {
      if (mounted) notice(context, e.message);
    } on Object {
      if (mounted) notice(context, 'Photos are not available on this device.');
    }
  }

  Future<void> _startRecording() async {
    try {
      final ok = await _media!.startVoice();
      if (!mounted) return;
      if (!ok) {
        notice(context, 'Allow microphone access to record voice notes.');
        return;
      }
    } on Object {
      if (mounted) {
        notice(context, 'Voice notes are not available on this device.');
      }
      return;
    }
    setState(() {
      _recording = true;
      _secs = 0;
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secs++);
      if (_secs >= maxVoiceSeconds) unawaited(_finishRecording());
    });
  }

  Future<void> _finishRecording({bool cancel = false}) async {
    if (!_recording) return;
    _tick?.cancel();
    setState(() => _recording = false);
    try {
      final a = await _media!.stopVoice(cancel: cancel);
      if (a == null || !mounted) return;
      await _submit(a);
    } on Object {
      if (mounted) notice(context, 'The voice note could not be saved.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _recording ? _recordingBar() : _inputBar();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: child,
      ),
    );
  }

  Widget _recordingBar() => Row(children: [
        IconButton(
            tooltip: 'Cancel recording',
            onPressed: () => _finishRecording(cancel: true),
            icon: const Icon(Icons.delete_outline_rounded)),
        const SizedBox(width: 4),
        const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
                'Recording ${clock(_secs)} / ${clock(maxVoiceSeconds)}',
                style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton.filled(
            tooltip: 'Send voice note',
            onPressed: _finishRecording,
            icon: const Icon(Icons.send_rounded)),
      ]);

  Widget _inputBar() => Row(children: [
        IconButton(
            tooltip: 'Send a photo',
            onPressed: _busy ? null : _pickPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined)),
        Expanded(
            child: TextField(
                controller: widget.controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => widget.onSendText(),
                decoration: const InputDecoration(hintText: 'Write a message'))),
        IconButton(
            tooltip: 'Record voice note',
            onPressed: _busy ? null : _startRecording,
            icon: const Icon(Icons.mic_none_rounded)),
        IconButton.filled(
            tooltip: 'Send',
            onPressed: widget.onSendText,
            icon: const Icon(Icons.send_rounded)),
      ]);
}

/// The content of one chat bubble: optional photo or voice note, then the optional caption.
class MessageBody extends StatelessWidget {
  const MessageBody({super.key, required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;
  @override
  Widget build(BuildContext context) {
    final a = message.attachment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (a != null) AttachmentView(attachment: a, mine: mine),
        if (message.text.isNotEmpty)
          Padding(
              padding: EdgeInsets.only(top: a == null ? 0 : 6),
              child: Text(message.text,
                  style: TextStyle(color: mine ? Colors.white : ink))),
      ],
    );
  }
}

class AttachmentView extends StatefulWidget {
  const AttachmentView(
      {super.key, required this.attachment, required this.mine});
  final Attachment attachment;
  final bool mine;
  @override
  State<AttachmentView> createState() => _AttachmentViewState();
}

class _AttachmentViewState extends State<AttachmentView> {
  bool _playing = false;
  Future<String>? _url;

  Attachment get _a => widget.attachment;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_a.kind == AttachmentKind.image && _a.bytes == null) {
      _url ??= StoreScope.of(context).mediaUrl(_a);
    }
  }

  Future<void> _togglePlay() async {
    final media = MediaScope.of(context);
    final store = StoreScope.of(context);
    if (_playing) {
      await media.stopPlayback();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    try {
      final url = _a.bytes == null ? await store.mediaUrl(_a) : null;
      await media.play(_a, url: url);
    } on Object {
      if (mounted) notice(context, 'This voice note could not be played.');
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  void _openPhoto(Widget image) => showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: Stack(children: [
            InteractiveViewer(child: image),
            Positioned(
                right: 4,
                top: 4,
                child: IconButton.filled(
                    tooltip: 'Close photo',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) =>
      _a.kind == AttachmentKind.image ? _photo() : _voice();

  Widget _photo() {
    const broken = SizedBox(
        width: 200,
        height: 120,
        child: Center(child: Icon(Icons.broken_image_outlined, color: muted)));
    Widget photoOf(Widget image) => Semantics(
        image: true,
        label: 'Photo',
        child: GestureDetector(
            onTap: () => _openPhoto(image),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(12), child: image)));
    final bytes = _a.bytes;
    if (bytes != null) {
      return photoOf(Image.memory(bytes,
          width: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => broken));
    }
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        if (snap.hasError) return broken;
        if (!snap.hasData) {
          return const SizedBox(
              width: 200,
              height: 120,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return photoOf(Image.network(snap.data!,
            width: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => broken));
      },
    );
  }

  Widget _voice() {
    final fg = widget.mine ? Colors.white : ink;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
          tooltip: _playing ? 'Stop voice note' : 'Play voice note',
          onPressed: _togglePlay,
          color: fg,
          icon: Icon(
              _playing ? Icons.stop_circle_outlined : Icons.play_circle_outline,
              size: 34)),
      Text('Voice note · ${clock(_a.seconds ?? 0)}',
          style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
    ]);
  }
}
