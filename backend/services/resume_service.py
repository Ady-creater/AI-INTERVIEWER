import json
from pathlib import Path
import magic
from pypdf import PdfReader
from docx import Document
from pydantic import BaseModel
from typing import List, Optional
from google import genai
from google.genai import types
import os
from dotenv import load_dotenv


BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")


_client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))
PARSER_MODEL = os.getenv("PARSER_MODEL", "gemini-3.5-flash-lite")



class Project(BaseModel):
    name: str
    description: str
    technologies: List[str] = []

class Resume(BaseModel):
    name: Optional[str] = None
    education: List[str] = []
    skills: List[str] = []
    experience: List[str] = []
    projects: List[Project] = []


class ResumeParser:

    @staticmethod
    def _read_text(file_path: Path):
        """Reads text from a PDF or DOCX file."""
        mime_type = magic.from_file(str(file_path), mime=True)
        ext = file_path.suffix.lower()
        print(f"[DEBUG] Detected mime_type: {mime_type}, file extension: {ext}")
        if mime_type.lower() == 'application/pdf' or ext == '.pdf':
            reader = PdfReader(str(file_path))
            doc_details = []
            for page in reader.pages:
                doc_details.append(page.extract_text())
            return " ".join(doc_details)
        elif mime_type.lower() == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' or ext == '.docx':
            doc = Document(str(file_path))
            doc_details = [para.text for para in doc.paragraphs if para.text.strip()]
            return " ".join(doc_details)
        else:
            raise ValueError(f"Unsupported file type. Detected mime_type: {mime_type}, extension: {ext}. Please upload a PDF or DOCX file.")


    @staticmethod
    def extract_resume_details(file_path: Path):
        """Extract details of the user's file"""
       
        if not file_path.exists():
            raise FileNotFoundError(f"Resume file not found: {file_path}")

        text = ResumeParser._read_text(file_path)
        if not text or not text.strip():
            return {}
        
        resp = _client.models.generate_content(model=PARSER_MODEL, contents=[f"Extract the details from this resume.Use only what is in the text.\n\n{text}\n\nIf the details cannot be extracted return {{}}"],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=Resume,
                    temperature=0,)
                )

        response_text = resp.text
        if response_text is None:
            return {}

        return json.loads(response_text)