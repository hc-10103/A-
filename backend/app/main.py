from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path

load_dotenv(Path(__file__).resolve().parents[2] / ".env")

from .routes import router  # noqa: E402  (환경변수 로드 후 import)

app = FastAPI(title="OLPARK RUN API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(router)
