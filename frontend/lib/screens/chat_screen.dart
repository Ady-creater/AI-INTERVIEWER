import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../widgets/camera_widget.dart';
import '../widgets/waveform_widget.dart';
import '../widgets/file_picker.dart';

import '../services/mic_service.dart';
import '../services/playback_service.dart';
import '../services/websocket_service.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChatScreen());
}

class ChatScreen extends StatefulWidget {
  /// Default Constructor
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late Map<String, dynamic> parsedResume = {};

  final MicService _micService = MicService();
  final PlaybackService _playbackService = PlaybackService();
  final WebsocketService _wsService = WebsocketService();
  late CameraController _controller;
  StreamSubscription<Uint8List>? _incomingAudioSubscription;

  bool _isListening = false;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _playbackService.initPlayer();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(camera, ResolutionPreset.medium);
    try {
      await _controller.initialize();
      if (!mounted) {
        return;
      }
      setState(() {
        _isReady = true;
      });
    } catch (e) {
      debugPrint("Error initialization camera: $e");
    }
  }

  Future<void> _startSession(Map<String, dynamic> resumeDetails) async {
    if (_isListening) return;

    await _incomingAudioSubscription?.cancel();
    _incomingAudioSubscription = null;

    try {
      await _wsService.connect('ws://127.0.0.1:8000/ws');
    } catch (e) {
      debugPrint('Could not connect to backend: $e');
      return;
    } 
    await _wsService.sendSetup({'resume_details': resumeDetails});

    _incomingAudioSubscription = _wsService.incomingAudioStream.listen(
      (chunk) {
        debugPrint("WS received audio chunk: ${chunk.lengthInBytes}");
        unawaited(_playbackService.playChunk(chunk));
      },
      onError: (error) {
        debugPrint('Incoming audio stream error: $error');
      },
    );
    // await _playbackService.startPlayerBuffer();

    await _micService.startMicrophone((chunk) {
      if (!_wsService.isConnected) {
        unawaited(_stopSession()); // socket died, stop the mic too
        return;
      }
      _wsService.sendAudioChunk(chunk);
      debugPrint("Mic sending chunk size: ${chunk.lengthInBytes}");
    });
    setState(() {
      _isListening = true;
    });
  }

  Future<void> _stopSession() async {
    if (!_isListening) return;

    await _incomingAudioSubscription?.cancel();
    _incomingAudioSubscription = null;

    await _micService.stopMicrophone();
    await _playbackService.stopPlayer();
    await _wsService.disconnect();
    debugPrint("Websocket connection closed.");

    setState(() => _isListening = false);
  }

  Future<void> postResume(PlatformFile file) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://127.0.0.1:8000/resume'),
    );
    final ext = file.extension?.toLowerCase();
    MediaType mediaType;

    try {
      if (ext == "pdf") {
        mediaType = MediaType("application", "pdf");
      } else if (ext == "docx") {
        mediaType = MediaType(
          "application",
          "vnd.openxmlformats-officedocument.wordprocessingml.document",
        );
      } else {
        throw Exception("Unsupported file");
      }

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            "resume",
            file.bytes!,
            filename: file.name,
            contentType: mediaType,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath("resume", file.path!),
        );
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        debugPrint("Document sent successfully: ${response.statusCode}");
        final body = await response.stream.bytesToString();
        parsedResume = jsonDecode(body)['resume_details'] ?? {};
        debugPrint(
          "Document details parsed successfully: ${response.statusCode}",
        );
      } else {
        debugPrint("Failed to upload document. Code: ${response.statusCode}");
        debugPrint(await response.stream.bytesToString());
      }
    } catch (e) {
      debugPrint("Error occured: $e");
    }
  }

  // Future<Map<String, dynamic>> getResumeDetails() async {
  //   try {
  //     var response = await http.get(Uri.parse('http://127.0.0.1:8000/resume'));
  //     if (response.statusCode == 200) {
  //       debugPrint(
  //         "Document details parsed successfully: ${response.statusCode}",
  //       );
  //       parsedResume = jsonDecode(response.body);
  //       return parsedResume;
  //     }
  //   } catch (e) {
  //     debugPrint("Could not fetch resume details: $e");
  //   }
  //   return {"status": "FAILED"};
  // }

  // Future<void> deleteResume(String filename) async {
  //   var request = http.MultipartRequest(
  //     'DELETE',
  //     Uri.parse("http://127.0.0.1:8000/resume/$filename"),
  //   );
  //   try {
  //     final response = await request.send();
  //     if (response.statusCode == 200) {
  //       debugPrint("Deleted $filename successfully.");
  //     } else {
  //       debugPrint(
  //         "Failed to delete $filename. Status code: ${response.statusCode}",
  //       );
  //     }
  //   } catch (e) {
  //     debugPrint("Error occured during deletion: $e");
  //   }
  // }

  @override
  void dispose() {
    unawaited(_wsService.disconnect());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_controller.value.isInitialized) {
      return Container();
    }
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          alignment: AlignmentGeometry.bottomCenter,
          children: [
            CameraWidget(cameraController: _controller),
            FilePickerWidget(
              onFileSelected: (file) async {
                if (file != null) {
                  await postResume(file);
                  debugPrint(
                    "Picked File Name: ${file.name}\nPath: ${file.path}",
                  );
                } else {
                  debugPrint("No file provided");
                }
              },
              onCancel: (file) {
                debugPrint("File selection cleared");
                // deleteResume(file!.name);
                parsedResume = {};
              },
            ),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          child: ElevatedButton(
            onPressed: () async {
              if (_isListening) {
                await _stopSession();
                return;
              }

              // final resumeDetails = await getResumeDetails();
          
              await _startSession(parsedResume);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateColor.fromMap(
                <WidgetStatesConstraint, Color>{
                  WidgetState.focused: Colors.blue,
                  WidgetState.any: Colors.green,
                },
              ),
              elevation: WidgetStatePropertyAll(10),
            ),
            child: !_isListening
                ? Text(
                    'START',
                    style: TextStyle(color: Colors.white, fontSize: 25),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Speak now...",
                          style: TextStyle(color: Colors.white, fontSize: 25),
                        ),
                      ),
                      VoiceLineWidget(isActive: _isListening),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
