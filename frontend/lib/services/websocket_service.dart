import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

class WebsocketService {
  WebSocketChannel? _channel;
  StreamController<Uint8List>? _audioController;
  StreamSubscription<void>? _messageSubscription;
  Timer? _heartbeatTimer;
  Timer? _pongTimeout;
  String? _connectedUrl;
  bool _isConnecting = false;
  bool get isConnected => _channel != null;
  DateTime? _lastPong;

  Stream<Uint8List> get incomingAudioStream =>
      _audioController?.stream ?? const Stream.empty();

  Future<void> connect(String url) async {
    if (_isConnecting) return;
    if (_channel != null) {
      await disconnect();
    };

    _isConnecting = true;
    try {
      final controller = StreamController<Uint8List>.new();
      final channel = WebSocketChannel.connect(Uri.parse(url));

      _audioController = controller;
      _channel = channel;
      _connectedUrl = url;

      await channel.ready;
      _lastPong = DateTime.now();
      _startHeartbeat();

      _messageSubscription = channel.stream.listen(
        (data) {
          final currentController = _audioController;
          if (currentController == null || currentController.isClosed) return;

          if (data is Uint8List) {
            currentController.add(data);
            return;
          }

          if (data is List<int>) {
            currentController.add(Uint8List.fromList(data));
            return;
          }

          if (data is String) {
            try {
              final decoded = jsonDecode(data);
              if (decoded is! Map<String, dynamic>) return;

              final type = decoded['type'];
              if (type == 'ping') {
                final currentChannel = _channel;
                if (currentChannel != null) {
                  currentChannel.sink.add(jsonEncode({'type': 'pong'}));
                }
                return;
              }

              if (type == 'pong') {
                _lastPong = DateTime.now();
                _pongTimeout?.cancel();
                return;
              }

              final audioValue = decoded['audio'];
              if (audioValue is String) {
                final audioBytes = base64Decode(audioValue);
                if (audioBytes.isNotEmpty) {
                  currentController.add(Uint8List.fromList(audioBytes));
                }
              } else if (decoded['error'] != null) {
                debugPrint('WebSocket server error: ${decoded['error']}');
              }
            } catch (_) {
              // Ignore non-audio JSON messages.
            }
          }
        },
        onError: (Object error) async {
          debugPrint('WebSocket error: $error');
          await disconnect();
        },
        onDone: () async {
          debugPrint('WebSocket closed');
          await disconnect();
        },
        cancelOnError: true,
      );
    } finally {
      _isConnecting = false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final channel = _channel;
      if (channel == null) return;

      channel.sink.add(jsonEncode({'type': 'ping'}));

      _pongTimeout?.cancel();
      _pongTimeout = Timer(const Duration(seconds: 10), () {
        final lastPong = _lastPong;
        if (lastPong == null ||
            DateTime.now().difference(lastPong) > const Duration(seconds: 25)) {
          unawaited(disconnect());
        }
      });
    });
  }

  Future<void> sendSetup(Map<String, dynamic>? payload) async {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode(payload));
  }

  void sendAudioChunk(Uint8List chunk) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode({'audio': base64Encode(chunk)}));
    } catch (e) {
      debugPrint('Send failed, closing: $e');
      unawaited(disconnect());
    } 
  }

  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _pongTimeout?.cancel();
    _pongTimeout = null;

    await _messageSubscription?.cancel();
    _messageSubscription = null;

    final channel = _channel;
    final controller = _audioController;

    _channel = null;
    _audioController = null;
    _connectedUrl = null;
    _lastPong = null;

    if (channel != null) {
      try {
        await channel.sink.close(status.normalClosure);
      } catch (_) {}
    }

    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }
}
