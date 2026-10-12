from dotenv import load_dotenv
import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, UploadFile, File, HTTPException, status
from agent.agent import InterviewAgent
from services.resume_service import ResumeParser
from google import genai
from google.genai import types
import base64
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path
import shutil
import asyncio
import os;

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")


def build_live_connect_config(full_prompt_text: str):
    system_instruction = types.Content(
        role="user",
        parts=[types.Part.from_text(text=full_prompt_text)],
    )
    return types.LiveConnectConfig(
        response_modalities=[types.Modality.AUDIO],
        system_instruction=system_instruction,
        realtime_input_config=types.RealtimeInputConfig(
            automatic_activity_detection=
            types.AutomaticActivityDetection(
                disabled=False,
                start_of_speech_sensitivity=types.StartSensitivity.START_SENSITIVITY_HIGH,
                end_of_speech_sensitivity=types.EndSensitivity.END_SENSITIVITY_HIGH,
                prefix_padding_ms=20,
                silence_duration_ms=300,
            )
        )
    )


def get_live_model_name() -> str:
    return os.getenv("GEMINI_MODEL", "gemini-3.1-flash-live-preview")

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://your-project.vercel.app"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


async def safe_send_json(websocket: WebSocket, payload: dict):
    try:
        await websocket.send_json(payload)
    except Exception:
        pass

client = None
if os.getenv("GOOGLE_API_KEY"):
    client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))

ALLOWED_MIME_TYPES = {
    "application/pdf": ".pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": ".docx"
}
UPLOAD_DIR = BASE_DIR / "uploaded_files"
os.makedirs(UPLOAD_DIR, exist_ok=True)


db = {}

@app.post("/resume")
async def upload_resume(resume: UploadFile = File(...)):
    if resume.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code = status.HTTP_400_BAD_REQUEST,
            detail = f"Invalid resume type. Only PDF and DOCX are allowed. Received: {resume.content_type}"
        )
    original_filename = resume.filename

    if not original_filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A resume filename is required",
        )
    
    filename = Path(original_filename).name
    file_path = UPLOAD_DIR / filename

    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(resume.file, buffer)
            print("File uploaded. Extracting details...")
        extracted_details = await asyncio.to_thread(ResumeParser.extract_resume_details, file_path)
        print("Resume uploaded and parsed successfully.")
        print(extracted_details)
        if extracted_details == {}:
            print("Unable to extract details from resume.")
            
    except Exception as e:
        if file_path.exists():
            os.remove(file_path)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Could not process uploaded file: {e}"
        )
        
    finally:
        file_path.unlink(missing_ok=True)
        await resume.close()

    return {
        "message": "File uploaded successfully",
        "filename": filename,
        "content_type": resume.content_type,
        "path": str(file_path),
        "resume_details": extracted_details
    }

# @app.get("/resume")
# async def get_resume_details():
#     return db

# @app.delete("/resume/{filename}")
# async def delete_resume(filename: str):
#     file_path = UPLOAD_DIR / filename
#     if not file_path.exists():
#         raise HTTPException(
#             status_code=status.HTTP_404_NOT_FOUND,
#             detail=f"File: {filename} not found in db."
#         )
#     try:
#         db.pop(filename, None)
#         os.remove(file_path)
#         return {"message": f"File {filename} deleted successfully."}
#     except PermissionError:
#         raise HTTPException(
#             status_code=status.HTTP_403_FORBIDDEN,
#             detail="Permission denied. Cannot delete file."
#         )
#     except Exception as e:
#         raise HTTPException(
#             status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
#             detail=f"An error occured. {str(e)}"
#         )
# abc = json.dumps(db)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()

    if client is None:
        await safe_send_json(
            websocket,
            {
                "error":
                "GOOGLE_API_KEY is not configured on the backend"
            },
        )
        await websocket.close(code=1011)
        return

    try:
        setup_data = await websocket.receive_json()
    except Exception as e:
        await safe_send_json(
            websocket,
            {
                "error":
                f"Invalid websocket setup payload: {e}"
            },
        )
        await websocket.close(code=1008)
        return

    resume_json = setup_data.get("resume_details")
    full_prompt_text = InterviewAgent.build_interviewer_prompt(resume_json)

    print("Initializing server-side Gemini live session...")

    try:
        config = build_live_connect_config(full_prompt_text)
    except Exception as e:
        await safe_send_json(
            websocket,
            {
                "error":
                f"Failed to initialize Gemini live config: {e}"
            },
        )
        await websocket.close(code=1011)
        return

    try:
        async with client.aio.live.connect(model=get_live_model_name(), config=config) as session:
            print("Bidirectional Live Audio-Visual Link established with Gemini.")

            async def send_to_gemini():
                
                """Sends messages from the client websocket to the Gemini API."""
                await session.send_realtime_input(text="Start the interview with a short greeting and your first question asking for introduction.")
                try:
                    async for message in websocket.iter_json():
                        if "type" in message and message["type"] == "ping":
                            await safe_send_json(websocket, {"type": "pong"})
                            continue
                        if "type" in message and message["type"] == "pong":
                            continue
                        if "type" in message and message["type"] == "end_turn":
                            try:
                                await (session.send_realtime_input(audio_stream_end=True))

                            except Exception as e:
                                print(f"Could not send audio_stream_end: {e}")
                            continue

                        audio_value = message.get("audio")

                        if not isinstance(audio_value,str):
                            continue
                        
                        if "audio" in message:
                            try:
                                raw_audio_bytes = base64.b64decode(message["audio"], validate=True)
                            except Exception:
                                print("Skipping invalid base64 audio payload")
                                continue
                            if len(raw_audio_bytes) < 2:
                                continue
                            
                            await session.send_realtime_input(
                                audio=types.Blob(data=raw_audio_bytes, mime_type="audio/pcm;rate=16000")
                            )
                        print(f"Received audio chunk bytes")

                except WebSocketDisconnect:
                    print("Client connection closed (send)")

                except asyncio.CancelledError:
                    raise

                except Exception as e:
                    print(f"Error sending to Gemini: {e}")

                finally:
                    print("send_to_gemini closed")

            async def receive_from_gemini():
                """Listens to Gemini's voice thoughts and forwards them back to Flutter."""
                try:
                    while True:
                        try:
                            print("receiving from gemini")
                            async for response in session.receive():
                                if response.server_content is None:
                                    print(f'Unhandled server message! - {response}')
                                    continue

                                model_turn = response.server_content.model_turn

                                if model_turn:
                                    for part in model_turn.parts or []:
                                        inline_data = getattr(part, "inline_data", None)
                                        audio_bytes = getattr(inline_data, "data", None)
                                        if audio_bytes is not None:
                                            base64_audio = base64.b64encode(audio_bytes).decode("utf-8")
                                            await websocket.send_json({"audio": base64_audio})
                                    print(f"Sent audio chunk bytes")

                                if response.server_content.turn_complete:
                                    await websocket.send_json({
                                        "type": "turn_complete"
                                    })

                                if response.server_content.interrupted:
                                    await websocket.send_json({
                                        "type": "interrupted"
                                    })
                                    continue

                        except WebSocketDisconnect:
                            print("Client connection closed normally")
                        except Exception as e:
                            print(f"Error receiving from Gemini: {e}")
                            break

                except Exception as e:
                    print(f"Error receiving from Gemini: {e}")
                finally:
                    print("Gemini connection closed (receive)")

            send_task = asyncio.create_task(send_to_gemini())
            receive_task = asyncio.create_task(receive_from_gemini())
            done, pending = await asyncio.wait(
            {send_task, receive_task},
            return_when=asyncio.FIRST_COMPLETED,
        )

        for task in pending:
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass

    except WebSocketDisconnect:
        print("Client Disconnected")
    except Exception as e:
        print(f"Live session failed: {e}")
        try:
            await websocket.send_json({"error": str(e)})
        except Exception:
            pass
    finally:
        print("Gemini session closed.")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", 8000)),
        reload=False,
        ws_ping_interval=20,
        ws_ping_timeout=120,
    )
