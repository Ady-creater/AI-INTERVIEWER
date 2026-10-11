import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class MicService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micstreamSubscription;

  Future<void> startMicrophone(Function(Uint8List) onData) async {
    try {
      var status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint("Microphone permission denied");
        return;
      }

      debugPrint("Initializing microphone stream capturing");
      final audioStream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      // final hardwareAudioStream = audioStream.asBroadcastStream();

      _micstreamSubscription = audioStream.listen(
        (data) => Future.microtask(() => onData(data)),
        // onDone: () => stopMicrophone(),
        onError: (err) =>
            debugPrint('Microphone hardware driver tracking error: $err'),
      );
    } catch (e) {
      debugPrint("Error starting microphone: $e");
      await stopMicrophone();
    }
  }

  Future<void> stopMicrophone() async {
    await _micstreamSubscription?.cancel();
    _micstreamSubscription = null;
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
  }

  Future<void> dispose() async {
    await _micstreamSubscription?.cancel();
    await _audioRecorder.dispose();
  }
}
