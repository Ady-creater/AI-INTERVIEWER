# AI Interviewer 🎙️

An AI-powered mock interview application built with **Flutter**, **FastAPI**, and **Google Gemini**. The app lets a candidate upload a PDF or DOCX resume, extracts structured resume details, and uses that context to personalize an interactive interview conducted through real-time audio.

## Features

- **Resume upload:** Select one PDF or DOCX file from the Flutter app.
- **Resume parsing:** Extracts resume text and asks a Gemini model to return structured details, including name, education, skills, experience, and projects.
- **Personalized interview context:** Builds an interviewer prompt from the extracted resume data.
- **Real-time voice interaction:** Streams microphone audio from Flutter to the FastAPI WebSocket endpoint and forwards Gemini-generated audio back to the app.
- **Audio playback:** Queues incoming audio chunks for playback using `flutter_soloud`.
- **Camera preview:** Displays a camera preview in the interview UI.
- **Connection heartbeat:** Uses WebSocket ping/pong messages to help detect disconnected sessions.
- **Temporary resume handling:** Uploaded files are removed by the backend after parsing; the current implementation does not persist resumes or interview history in a database.

## Tech Stack

| Area | Technology |
|---|---|
| Frontend | Flutter, Dart |
| Backend API | FastAPI, Python, Uvicorn |
| AI model integration | Google Gen AI SDK / Gemini |
| Real-time communication | WebSockets |
| Resume parsing | `pypdf`, `python-docx`, `python-magic-bin` |
| Audio capture | `record`, `permission_handler` |
| Audio playback | `flutter_soloud` |
| File upload | `file_picker`, `http`, `http_parser` |

## How It Works

1. The user selects a PDF or DOCX resume in the Flutter UI.
2. Flutter uploads the file to `POST /resume` as multipart form data.
3. FastAPI validates the file type and temporarily writes the file to `uploaded_files/`.
4. The resume service extracts text and sends it to Gemini for structured JSON extraction.
5. The backend deletes the temporary uploaded file and returns the extracted `resume_details`.
6. When the user starts an interview, Flutter opens a WebSocket connection to `/ws` and sends the resume details as the setup message.
7. Flutter streams microphone audio as base64-encoded PCM chunks.
8. FastAPI forwards audio to a Gemini Live session and relays generated audio chunks to Flutter.
9. Flutter decodes incoming audio chunks and sends them to the playback buffer.

## Project Structure

The following is the backend structure implied by the Python imports. Adapt the paths if your repository uses different names.

```text
ai-interviewer/
├── main.py
├── agent/
│   └── agent.py
├── services/
│   └── resume_service.py
├── uploaded_files/             # Temporary files; do not commit
├── requirements.txt
├── .env.example
├── .gitignore
└── frontend/                   # Flutter project
    ├── lib/
    │   ├── screens/
    │   │   └── chat_screen.dart
    │   ├── services/
    │   │   ├── mic_service.dart
    │   │   ├── playback_service.dart
    │   │   └── websocket_service.dart
    │   └── widgets/
    │       ├── camera_widget.dart
    │       ├── file_picker.dart
    │       └── waveform_widget.dart
    └── pubspec.yaml
```

Your uploaded Flutter filenames include `chat_screen(3).dart`, `mic_service(3).dart`, `playback_service(2).dart`, and `websocket_service(3).dart`. Rename them to the conventional names above only if those match the imports and layout in your actual project.

## Prerequisites

- Python 3.10+ (use the version compatible with your installed Google Gen AI SDK)
- Flutter SDK and Dart
- A Google Gemini API key with access to the models you configure
- Git

## Backend Setup

### 1. Clone the repository

```bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
cd <YOUR_REPOSITORY_DIRECTORY>
```

### 2. Create a virtual environment

Using `uv`:

```bash
uv venv
```

Activate it on Windows PowerShell:

```powershell
.venv\Scripts\Activate.ps1
```

Install dependencies using the method your project uses. If you maintain a `requirements.txt`:

```bash
uv pip install -r requirements.txt
```

Alternatively, with pip:

```bash
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

### 3. Configure environment variables

Create a `.env` file in the location expected by your backend. The current Python code loads environment variables from the project directory.

Example:

```env
GOOGLE_GENAI_USE_VERTEXAI=FALSE
GOOGLE_API_KEY=your_google_gemini_api_key
PARSER_MODEL=gemini-3.5-flash-lite
GEMINI_MODEL=gemini-3.1-flash-live-preview
PORT=8000
```

Use model IDs that are currently available to your Google AI project. The defaults in code may change or may not be available for every account.

**Never commit `.env` or a real API key.** Commit only a placeholder-only `.env.example`. If a real key has ever been committed or shared, revoke it and create a replacement.

### 4. Start FastAPI

From the backend directory, run:

```bash
uv run uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Or, with the virtual environment activated:

```bash
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Open the interactive API documentation at:

- `http://127.0.0.1:8000/docs`

The backend exposes:

- `POST /resume` — accepts a multipart upload with the field name `resume`.
- `WS /ws` — accepts a JSON setup message containing `resume_details`, then handles audio and heartbeat messages.

## Flutter Setup

From the Flutter project directory:

```bash
flutter pub get
flutter run
```

The Dart code currently uses `http://127.0.0.1:8000/resume` for resume uploads and `ws://127.0.0.1:8000/ws` for the interview WebSocket.

**Update these URLs for your environment:**

- **Android emulator:** use `10.0.2.2` to reach the host computer.
- **Desktop on the same computer:** `127.0.0.1` may work.
- **Physical phone:** use the computer's LAN IP address and ensure both devices can reach each other.
- **Production:** use your deployed HTTPS API URL and secure WebSocket URL (`wss://`).

For Flutter web, ensure the backend's CORS and browser security configuration is appropriate for your deployed origin. Browsers generally block insecure `ws://` connections from an HTTPS page, so production web deployments should use `wss://`.

## Audio and WebSocket Protocol

The current client/server code uses JSON messages over the WebSocket.

### Client → server

Setup message:

```json
{
  "resume_details": {
    "name": "Candidate",
    "skills": ["Python", "Flutter"],
    "education": [],
    "experience": [],
    "projects": []
  }
}
```

Audio message:

```json
{
  "audio": "<base64-encoded PCM audio chunk>"
}
```

Heartbeat messages:

```json
{"type": "ping"}
```

The backend responds with:

```json
{"type": "pong"}
```

### Server → client

Audio response:

```json
{
  "audio": "<base64-encoded audio chunk>"
}
```

The backend can also send status messages such as `turn_complete`, `interrupted`, or an `error` message.

The microphone service captures mono PCM 16-bit audio at 16 kHz. The playback service configures SoLoud for mono 16-bit little-endian audio at 24 kHz. Confirm that the configured Gemini Live model emits audio in the format expected by the player; mismatched sample rates or formats can affect playback speed and quality.

## Important Implementation Notes

- **Resume privacy:** The backend deletes the uploaded resume file after parsing, but extracted resume details are sent to the AI model and passed to the interview session. Tell users how their information is processed.
- **No database:** The current code does not save interview history or resume data in a persistent database.
- **Temporary storage:** `uploaded_files/` is used during parsing and should be excluded from Git.
- **Camera:** The UI displays a camera preview. In the uploaded Flutter code, camera frames are not currently sent through the WebSocket, even though the backend has a video-message branch.
- **Mic/camera buttons:** The camera widget currently changes the button icons/states; verify or add the actual hardware enable/disable behavior before describing those controls as fully functional.
- **Model configuration:** Ensure the parser and live-interview model IDs are supported by your Google AI project.
- **File validation:** The backend checks MIME type. Browser uploads can sometimes send generic MIME types; test PDF and DOCX uploads in each target platform.
- **Production security:** Restrict CORS to trusted origins, add request/upload limits and authentication if needed, and avoid exposing the backend or API key unnecessarily.
- **Cloud hosting:** FastAPI can be deployed to a container host such as Google Cloud Run, but configure WebSocket session timeouts, concurrency, secrets, and client URLs for production. GitHub Pages can host a Flutter web frontend, but it cannot run the FastAPI backend.

## Troubleshooting

| Problem | Things to check |
|---|---|
| WebSocket cannot connect | Confirm FastAPI is running and that the URL is correct for the device/platform. |
| Resume upload returns `400` | Check that the selected file is PDF or DOCX and inspect the MIME type sent by the client. |
| Resume upload returns `500` | Check backend logs, model availability, API key configuration, and whether text could be extracted. |
| No audio is heard | Check microphone permissions, WebSocket messages, Gemini model access, audio sample rate/format, and player initialization. |
| Works on emulator but not on a phone | Replace `127.0.0.1` with the computer's reachable LAN address. |
| Browser blocks the connection | Check CORS and use secure `wss://` when the frontend is served over HTTPS. |

## Roadmap Ideas

- Interview feedback and scoring
- Support for selectable job roles and difficulty levels
- Interview summaries and downloadable reports
- Authentication and saved interview history
- More complete camera controls and real-time video streaming
- Improved error handling and connection/session lifecycle management

These are possible improvements, not claims that the features are already implemented.

## Contributing

Issues, suggestions, and pull requests are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Make and test your changes.
4. Submit a pull request with a clear description.

## License

No license is specified by the uploaded files. Add a `LICENSE` file and update this section once you choose how others may use and distribute the project.

---

**Practice with purpose. Interview with confidence.**
