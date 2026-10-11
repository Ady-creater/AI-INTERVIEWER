# Complete Setup: Flutter + WebSocket + FastAPI Audio Streaming

## Architecture Overview

```
┌─────────────────────────────────┐
│    Flutter Frontend (Mobile)    │
│  - Audio Recording (Microphone) │
│  - WebSocket Client             │
│  - Audio Playback (Speaker)     │
└────────────┬────────────────────┘
             │ WebSocket (ws://)
             │ Audio Chunks (binary)
┌────────────▼────────────────────┐
│  FastAPI Backend Server         │
│  - WebSocket Endpoint (/ws)     │
│  - Audio Processing             │
│  - AI Integration (Gemini/HF)   │
│  - Real-time Response           │
└─────────────────────────────────┘
```

## Part 1: Backend Setup (FastAPI)

### 1.1 Dependencies

Add to `pyproject.toml`:
```toml
[project]
dependencies = [
    # ... existing deps ...
    "fastapi>=0.100.0",
    "uvicorn[standard]>=0.23.0",
    "websockets>=12.0",
    "numpy>=1.24.0",
    "pydantic>=2.0.0",
]
```

Or `requirements.txt`:
```
fastapi>=0.100.0
uvicorn[standard]>=0.23.0
websockets>=12.0
numpy>=1.24.0
pydantic>=2.0.0
python-dotenv>=1.0.0
google-genai>=2.9.0
langchain>=1.3.0
langchain-google-genai>=4.2.0
pyaudio>=0.2.14
```

### 1.2 Audio Utilities Module

Create `backend/audio_processor.py`:
```python
import numpy as np
import asyncio
from typing import AsyncGenerator

class AudioProcessor:
    """Handle audio encoding/decoding and processing"""
    
    SAMPLE_RATE = 16000
    CHUNK_SIZE = 4096
    CHANNELS = 1
    SAMPLE_WIDTH = 2  # 16-bit PCM
    
    @staticmethod
    def bytes_to_pcm(audio_bytes: bytes) -> np.ndarray:
        """Convert raw bytes to PCM audio array"""
        audio_data = np.frombuffer(audio_bytes, dtype=np.int16)
        return audio_data.astype(np.float32) / 32768.0
    
    @staticmethod
    def pcm_to_bytes(audio_array: np.ndarray) -> bytes:
        """Convert PCM audio array to raw bytes"""
        audio_int16 = (audio_array * 32768).astype(np.int16)
        return audio_int16.tobytes()
    
    @staticmethod
    def normalize_audio(audio_bytes: bytes) -> bytes:
        """Normalize audio to prevent clipping"""
        pcm = AudioProcessor.bytes_to_pcm(audio_bytes)
        max_val = np.max(np.abs(pcm))
        if max_val > 0:
            pcm = pcm / max_val * 0.9
        return AudioProcessor.pcm_to_bytes(pcm)
    
    @staticmethod
    async def stream_audio_chunks(audio_data: bytes, 
                                   chunk_size: int = CHUNK_SIZE) -> AsyncGenerator:
        """Stream audio in chunks"""
        for i in range(0, len(audio_data), chunk_size):
            chunk = audio_data[i:i + chunk_size]
            yield chunk
            await asyncio.sleep(0.01)  # Simulate real-time streaming
```

### 1.3 WebSocket Manager

Create `backend/websocket_manager.py`:
```python
import json
import logging
from typing import Set, Dict, Any
from fastapi import WebSocket

logger = logging.getLogger(__name__)

class ConnectionManager:
    """Manage active WebSocket connections"""
    
    def __init__(self):
        self.active_connections: Set[WebSocket] = set()
        self.client_data: Dict[str, Any] = {}
    
    async def connect(self, websocket: WebSocket) -> str:
        """Accept connection and return client ID"""
        await websocket.accept()
        self.active_connections.add(websocket)
        client_id = id(websocket)
        self.client_data[client_id] = {
            "connected": True,
            "audio_buffer": b"",
            "interview_started": False
        }
        logger.info(f"Client {client_id} connected. Total: {len(self.active_connections)}")
        return str(client_id)
    
    def disconnect(self, websocket: WebSocket):
        """Remove disconnected client"""
        self.active_connections.discard(websocket)
        client_id = id(websocket)
        if client_id in self.client_data:
            del self.client_data[client_id]
        logger.info(f"Client {client_id} disconnected. Total: {len(self.active_connections)}")
    
    async def broadcast_audio(self, audio_chunk: bytes, sender_id: str = None):
        """Broadcast audio to all connected clients except sender"""
        disconnected = set()
        for connection in self.active_connections:
            conn_id = str(id(connection))
            if conn_id != sender_id:
                try:
                    await connection.send_bytes(audio_chunk)
                except Exception as e:
                    logger.error(f"Failed to send audio: {e}")
                    disconnected.add(connection)
        
        for conn in disconnected:
            self.disconnect(conn)
    
    async def send_text_to_client(self, websocket: WebSocket, message: dict):
        """Send JSON message to specific client"""
        try:
            await websocket.send_json(message)
        except Exception as e:
            logger.error(f"Failed to send message: {e}")
            self.disconnect(websocket)
    
    async def receive_audio_chunk(self, websocket: WebSocket) -> bytes:
        """Receive audio chunk from client"""
        try:
            return await websocket.receive_bytes()
        except Exception as e:
            logger.error(f"Failed to receive audio: {e}")
            raise
```

### 1.4 Main FastAPI Application

Update `backend/main.py`:
```python
import asyncio
import logging
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from dotenv import load_dotenv
import os

from websocket_manager import ConnectionManager
from audio_processor import AudioProcessor
from agent.main import take_interview_async  # Update agent to be async-friendly

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

# Initialize manager
manager = ConnectionManager()

# Lifespan context for startup/shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🚀 FastAPI server starting...")
    yield
    logger.info("🛑 FastAPI server shutting down...")

app = FastAPI(title="Interview AI Backend", version="1.0.0", lifespan=lifespan)

# CORS middleware for Flutter frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check endpoint
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "connected_clients": len(manager.active_connections)
    }

# WebSocket endpoint for audio streaming
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    client_id = await manager.connect(websocket)
    
    try:
        # Send welcome message
        await manager.send_text_to_client(websocket, {
            "type": "connection",
            "message": "Connected to interview server",
            "client_id": client_id
        })
        
        # Start interview in background
        interview_task = asyncio.create_task(
            take_interview_async(websocket, manager, client_id)
        )
        
        # Listen for incoming audio from client
        while True:
            audio_chunk = await manager.receive_audio_chunk(websocket)
            
            if not audio_chunk:
                break
            
            # Process and normalize audio
            processed_audio = AudioProcessor.normalize_audio(audio_chunk)
            
            # Broadcast to other clients (optional)
            await manager.broadcast_audio(processed_audio, sender_id=client_id)
            
            # Log audio received (for debugging)
            logger.debug(f"Received {len(audio_chunk)} bytes from client {client_id}")
    
    except WebSocketDisconnect:
        manager.disconnect(websocket)
        logger.info(f"Client {client_id} disconnected gracefully")
    except Exception as e:
        logger.error(f"WebSocket error for client {client_id}: {e}")
        manager.disconnect(websocket)
    finally:
        try:
            await websocket.close()
        except:
            pass

# Endpoint to start interview
@app.post("/interview/start")
async def start_interview(resume_path: str = None):
    if not resume_path:
        raise HTTPException(status_code=400, detail="Resume path required")
    
    return {
        "status": "interview_started",
        "message": "Connect via WebSocket to begin audio streaming",
        "websocket_url": "ws://localhost:8000/ws"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
```

---

## Part 2: Frontend Setup (Flutter)

### 2.1 Update pubspec.yaml

Already has: `camera`, `record`, `web_socket_channel`

Ensure you have:
```yaml
dependencies:
  flutter:
    sdk: flutter
  camera: ^0.12.0+1
  record: ^6.2.1
  web_socket_channel: ^3.0.3
  http: ^1.6.0
  cupertino_icons: ^1.0.8
  # For audio playback response
  audioplayers: ^5.2.0
```

### 2.2 WebSocket Service

Create `frontend/lib/services/websocket_service.dart`:
```dart
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class WebSocketService {
  late WebSocketChannel _channel;
  bool _connected = false;
  final String _serverUrl = 'ws://localhost:8000/ws';
  
  String? _clientId;
  
  // Callbacks
  Function(String)? onMessage;
  Function(Uint8List)? onAudio;
  Function()? onConnected;
  Function(String)? onDisconnected;
  Function(String)? onError;
  
  bool get isConnected => _connected;
  String? get clientId => _clientId;
  
  /// Connect to WebSocket server
  Future<bool> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      
      await _channel.ready;
      _connected = true;
      
      onConnected?.call();
      print('✅ WebSocket Connected: $_serverUrl');
      
      // Start listening for messages
      _listen();
      
      return true;
    } catch (e) {
      _connected = false;
      onError?.call('Connection failed: $e');
      print('❌ WebSocket Connection Error: $e');
      return false;
    }
  }
  
  /// Listen to incoming messages/audio
  void _listen() {
    _channel.stream.listen(
      (data) {
        if (data is String) {
          // Text message (JSON)
          try {
            final json = jsonDecode(data);
            if (json['type'] == 'connection') {
              _clientId = json['client_id'];
            }
            onMessage?.call(data);
            print('📨 Message: $data');
          } catch (e) {
            print('⚠️ Failed to parse JSON: $e');
          }
        } else if (data is List<int>) {
          // Binary data (audio)
          final audioData = Uint8List.fromList(data);
          onAudio?.call(audioData);
          print('🔊 Received audio chunk: ${audioData.length} bytes');
        }
      },
      onError: (error) {
        print('❌ WebSocket Error: $error');
        onError?.call('Error: $error');
      },
      onDone: () {
        _connected = false;
        onDisconnected?.call('Server closed connection');
        print('❌ WebSocket Disconnected');
      },
    );
  }
  
  /// Send audio chunk to server
  void sendAudio(Uint8List audioData) {
    if (!_connected) {
      print('⚠️ Not connected. Cannot send audio.');
      return;
    }
    
    try {
      _channel.sink.add(audioData);
      print('📤 Sent audio chunk: ${audioData.length} bytes');
    } catch (e) {
      print('❌ Failed to send audio: $e');
      onError?.call('Send failed: $e');
    }
  }
  
  /// Send text message
  void sendMessage(Map<String, dynamic> message) {
    if (!_connected) {
      print('⚠️ Not connected. Cannot send message.');
      return;
    }
    
    try {
      _channel.sink.add(jsonEncode(message));
      print('📤 Sent message: $message');
    } catch (e) {
      print('❌ Failed to send message: $e');
    }
  }
  
  /// Disconnect
  void disconnect() {
    _connected = false;
    _channel.sink.close();
    print('🔌 WebSocket Disconnected');
  }
}
```

### 2.3 Audio Recorder Service

Create `frontend/lib/services/audio_service.dart`:
```dart
import 'package:record/record.dart';
import 'dart:typed_data';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  
  Future<bool> hasPermission() => _recorder.hasPermission();
  
  Future<void> requestPermission() async {
    final has = await _recorder.hasPermission();
    if (!has) {
      throw Exception('Microphone permission denied');
    }
  }
  
  Future<void> startRecording(
    Function(Uint8List) onAudioChunk,
  ) async {
    try {
      if (_isRecording) return;
      
      final isSupported = await _recorder.isEncoderSupported(AudioEncoder.pcm);
      if (!isSupported) {
        throw Exception('PCM encoding not supported');
      }
      
      await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 128000,
        ),
        onProgress: (recordEvent) {
          // Get recorded bytes
          print('Recording: ${recordEvent.duration}');
        },
      );
      
      _isRecording = true;
      print('🎤 Recording started');
      
      // Stream audio chunks
      _recorder.onStateChanged.listen((state) {
        print('Recording state: $state');
      });
      
    } catch (e) {
      print('❌ Error starting recording: $e');
      rethrow;
    }
  }
  
  Future<Uint8List?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      print('⏹️ Recording stopped: $path');
      return null; // In production, read the file
    } catch (e) {
      print('❌ Error stopping recording: $e');
      return null;
    }
  }
  
  bool get isRecording => _isRecording;
  
  void dispose() {
    _recorder.dispose();
  }
}
```

### 2.4 Interview Widget

Create `frontend/lib/widgets/interview_widget.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/websocket_service.dart';
import '../services/audio_service.dart';
import 'dart:typed_data';

class InterviewWidget extends StatefulWidget {
  final CameraController cameraController;
  
  const InterviewWidget({Key? key, required this.cameraController})
      : super(key: key);

  @override
  State<InterviewWidget> createState() => _InterviewWidgetState();
}

class _InterviewWidgetState extends State<InterviewWidget> {
  late WebSocketService _wsService;
  late AudioService _audioService;
  
  bool _isRecording = false;
  bool _isConnected = false;
  String _statusMessage = 'Initializing...';
  
  @override
  void initState() {
    super.initState();
    _wsService = WebSocketService();
    _audioService = AudioService();
    _setupWebSocket();
    _initAudio();
  }
  
  void _setupWebSocket() {
    _wsService.onConnected = () {
      setState(() {
        _isConnected = true;
        _statusMessage = 'Connected to server ✅';
      });
    };
    
    _wsService.onDisconnected = (reason) {
      setState(() {
        _isConnected = false;
        _statusMessage = 'Disconnected: $reason ❌';
      });
    };
    
    _wsService.onMessage = (message) {
      print('Received: $message');
      setState(() {
        _statusMessage = message;
      });
    };
    
    _wsService.onAudio = (audioData) {
      // Handle received audio (playback)
      print('Received audio: ${audioData.length} bytes');
    };
    
    _wsService.onError = (error) {
      setState(() {
        _statusMessage = 'Error: $error ❌';
      });
    };
  }
  
  void _initAudio() async {
    try {
      final hasPermission = await _audioService.hasPermission();
      if (!hasPermission) {
        setState(() {
          _statusMessage = 'Microphone permission denied ❌';
        });
        return;
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Audio init failed: $e ❌';
      });
    }
  }
  
  Future<void> _connectToServer() async {
    final connected = await _wsService.connect();
    if (connected) {
      print('✅ Connected to WebSocket server');
    } else {
      print('❌ Failed to connect');
    }
  }
  
  Future<void> _toggleRecording() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to server first')),
      );
      return;
    }
    
    try {
      if (_isRecording) {
        await _audioService.stopRecording();
        setState(() {
          _isRecording = false;
          _statusMessage = 'Recording stopped';
        });
      } else {
        await _audioService.startRecording((audioChunk) {
          // Send audio to server
          _wsService.sendAudio(audioChunk);
        });
        setState(() {
          _isRecording = true;
          _statusMessage = 'Recording...';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }
  
  @override
  void dispose() {
    _wsService.disconnect();
    _audioService.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interview Session'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.check_circle : Icons.error,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          
          // Camera preview
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: widget.cameraController.value.isInitialized
                    ? CameraPreview(widget.cameraController)
                    : const Center(
                        child: CircularProgressIndicator(),
                      ),
              ),
            ),
          ),
          
          // Control buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Connect button
                FloatingActionButton(
                  onPressed: _isConnected ? null : _connectToServer,
                  backgroundColor: _isConnected ? Colors.grey : Colors.blue,
                  child: Icon(
                    _isConnected ? Icons.check : Icons.cloud_upload,
                  ),
                ),
                
                // Microphone button
                FloatingActionButton(
                  onPressed: _toggleRecording,
                  backgroundColor: _isRecording ? Colors.red : Colors.blue,
                  child: Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                  ),
                ),
                
                // Disconnect button
                FloatingActionButton(
                  onPressed: _isConnected
                      ? () {
                          _wsService.disconnect();
                          setState(() {
                            _isConnected = false;
                            _statusMessage = 'Disconnected';
                          });
                        }
                      : null,
                  backgroundColor: _isConnected ? Colors.orange : Colors.grey,
                  child: const Icon(Icons.cloud_off),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

### 2.5 Update main.dart

```dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'widgets/interview_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Interview AI',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final frontCamera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.high,
        );

        await _cameraController!.initialize();
        setState(() {});
      }
    } catch (e) {
      print('Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _cameraController != null
        ? InterviewWidget(cameraController: _cameraController!)
        : const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
  }
}
```

---

## Part 3: Running the Complete Setup

### 3.1 Backend

```bash
# Install dependencies
cd backend
pip install -r requirements.txt

# Or if using pyproject.toml
uv pip install .

# Run FastAPI server
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 3.2 Frontend

```bash
cd frontend

# Get dependencies
flutter pub get

# Run on device/emulator
flutter run -d <device_id>

# Or for all connected devices
flutter run
```

### 3.3 Network Configuration

**For Local Testing:**
- Update `frontend/lib/services/websocket_service.dart`: 
  ```dart
  final String _serverUrl = 'ws://localhost:8000/ws';
  ```

**For Network Testing (Android Emulator):**
- Update to: `ws://10.0.2.2:8000/ws` (special alias for host)

**For Physical Device:**
- Update to your machine's IP: `ws://192.168.x.x:8000/ws`

---

## Part 4: Audio Format & Streaming

### Audio Specifications
- **Sample Rate**: 16000 Hz (16 kHz)
- **Channels**: 1 (Mono)
- **Format**: PCM 16-bit (signed)
- **Chunk Size**: 4096 bytes (~128ms at 16kHz)
- **Bitrate**: 256 kbps

### Data Flow
```
[User Microphone]
        ↓
   [Record Audio]
        ↓
   [16kHz PCM]
        ↓
[WebSocket Binary Frames]
        ↓
[FastAPI /ws endpoint]
        ↓
[Process/Normalize]
        ↓
[AI Model (Gemini)]
        ↓
[Generate Response Audio]
        ↓
[Stream Back via WebSocket]
        ↓
[Flutter Audio Playback]
```

---

## Part 5: Environment Variables

Create `.env` file in `backend/`:
```env
GOOGLE_API_KEY=your_google_api_key
HF_TOKEN=your_huggingface_token
ENVIRONMENT=development
LOG_LEVEL=INFO
```

---

## Part 6: Testing

### Test WebSocket Connection
```bash
# Using websocat (install: cargo install websocat)
websocat ws://localhost:8000/ws
```

### Check Backend Health
```bash
curl http://localhost:8000/health
```

### Verify Audio Recording (Flutter)
- Check device logs: `flutter logs`
- Look for "🎤 Recording started" messages

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Connection Refused** | Ensure FastAPI is running on port 8000 |
| **Audio Permission Denied** | Grant microphone permission in app settings |
| **Binary Data Error** | Verify audio format is PCM 16-bit |
| **WebSocket Timeout** | Check network connectivity, firewall rules |
| **Audio Distortion** | Reduce volume or implement normalization |
| **Memory Leaks** | Properly dispose of resources in `dispose()` |

