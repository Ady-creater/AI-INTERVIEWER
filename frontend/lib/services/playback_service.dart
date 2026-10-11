import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

class PlaybackService {
  static const int _sampleRate = 24000;
  final SoLoud _soloud = SoLoud.instance;
  AudioSource? _audioSource;
  SoundHandle? _soundHandle;
  bool _isInitialized = false;
  Future<AudioSource>? _initialization;
  Future<void> _chunkQueue = Future<void>.value();

  Future<AudioSource> initPlayer() {
    if (_isInitialized && _audioSource != null) {
      return Future.value(_audioSource!);
    }

    return _initialization ??= _initializePlayer();
  }

  Future<AudioSource> _initializePlayer() async {
    try {
      await _initSoloud();

      final source = _soloud.setBufferStream(
        maxBufferSizeBytes: 16 * 1024 * 1024,
        bufferingType: BufferingType.released,
        bufferingTimeNeeds: 0.1,
        sampleRate: _sampleRate,
        channels: Channels.mono,
        format: BufferType.s16le,
      );
      _audioSource = source;
      _soundHandle = _soloud.play(source);
      _isInitialized = true;
      return source;
    } finally {
      _initialization = null;
    }
  }

  Future<void> _initSoloud() async {
    if (_soloud.isInitialized) return;
    for (var attempt = 0; attempt < 50; attempt++) {
      try {
        await _soloud.init(
          sampleRate: _sampleRate,
          channels: Channels.mono,
          bufferSize: 2048,
        );
        return;
      } on TypeError {
        if (attempt == 49) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> startPlayerBuffer() async {
    await initPlayer();
    final handle = _soundHandle;
    if (handle != null && _soloud.getIsValidVoiceHandle(handle)) {
      _soloud.setPause(handle, false);
    }
  }

  Future<void> playChunk(Uint8List chunk) async {
    if (chunk.isEmpty) {
      return;
    }

    final source = await initPlayer();
    final queuedWrite = _chunkQueue.then((_) {
      if (_isInitialized && identical(_audioSource, source)) {
        _soloud.addAudioDataStream(source, chunk);
      }
    });
    _chunkQueue = queuedWrite.catchError((_) {});
    await queuedWrite;
  }

  Future<void> stopPlayer() async {
    await _chunkQueue;
    final handle = _soundHandle;
    final source = _audioSource;
    if (handle != null && _soloud.isInitialized) {
      await _soloud.stop(handle);
    }
    if (source != null && _soloud.isInitialized) {
      await _soloud.disposeSource(source);
    }
    _isInitialized = false;
    _soundHandle = null;
    _audioSource = null;
    _initialization = null;
    _chunkQueue = Future<void>.value();
  }

  Future<void> dispose() async {
    await stopPlayer();
    if (_soloud.isInitialized) {
      _soloud.deinit();
    }
    _isInitialized = false;
  }
}
