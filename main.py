import os
import random
from typing import List
from dotenv import load_dotenv
from fastapi import FastAPI, Depends, HTTPException, Header, Security
from fastapi.security.api_key import APIKeyHeader
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy.sql.expression import func
from pydantic import BaseModel

from database import engine, Base, get_db
from models import Word, WrongAnswerRecord

# .env 파일 로드 (로컬 개발 환경용)
load_dotenv()

# 환경변수에서 시크릿 키 및 허용 도메인 로드
API_SECRET_KEY = os.getenv("API_SECRET_KEY")
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "https://hsk5-hsk5quizapp.vercel.app").split(",")

# 테이블 동기화
Base.metadata.create_all(bind=engine)

app = FastAPI(title="HSK 5급 단어 퀴즈 API")

# CORS 설정 (환경변수로 허용된 출처만 접근 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in ALLOWED_ORIGINS if origin.strip()],
    allow_credentials=True,
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["Content-Type", "X-API-Key"],
)

# --- API Key 보안 검증 의존성 ---
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


def verify_api_key(api_key: str = Security(api_key_header)):
    if not API_SECRET_KEY:
        raise HTTPException(
            status_code=500,
            detail="서버 환경변수(API_SECRET_KEY)가 설정되지 않았습니다."
        )
    if api_key != API_SECRET_KEY:
        raise HTTPException(
            status_code=403,
            detail="유효하지 않은 API Key입니다. 접근이 거부되었습니다."
        )
    return api_key


# --- Pydantic 요청/응답 스키마 ---
class WrongRecordCreate(BaseModel):
    word_id: int


class WrongWordResponse(BaseModel):
    id: int
    word_id: int
    hanzi: str
    pinyin: str
    meaning: str
    wrong_count: int


# --- 기존 퀴즈 API (읽기 전용 - 공개) ---
@app.get("/api/v1/quiz/random")
def get_random_quiz(db: Session = Depends(get_db)):
    total_count = db.query(Word).count()
    if total_count < 4:
        raise HTTPException(
            status_code=400,
            detail=f"DB에 단어가 부족합니다. (현재 {total_count}개)"
        )

    target_word = db.query(Word).order_by(func.random()).first()
    distractors = (
        db.query(Word)
        .filter(Word.id != target_word.id)
        .order_by(func.random())
        .limit(3)
        .all()
    )

    options = [{"id": target_word.id, "text": target_word.meaning}]
    for d in distractors:
        options.append({"id": d.id, "text": d.meaning})

    random.shuffle(options)

    return {
        "id": target_word.id,
        "hanzi": target_word.hanzi,
        "pinyin": target_word.pinyin,
        "options": options,
        "answer_id": target_word.id,
    }


@app.get("/api/v1/words/count")
def get_word_count(db: Session = Depends(get_db)):
    """현재 API가 바라보고 있는 DB의 실제 단어 수를 점검하는 엔드포인트"""
    count = db.query(Word).count()
    return {"total_words": count}


# --- 신규 오답노트 DB 연동 API ---
@app.get("/api/v1/wrong-answers", response_model=List[WrongWordResponse])
def get_wrong_answers(db: Session = Depends(get_db)):
    """DB에 저장된 전체 오답 목록 조회"""
    records = db.query(WrongAnswerRecord).join(Word).order_by(WrongAnswerRecord.updated_at.desc()).all()
    return [
        WrongWordResponse(
            id=r.id,
            word_id=r.word.id,
            hanzi=r.word.hanzi,
            pinyin=r.word.pinyin,
            meaning=r.word.meaning,
            wrong_count=r.wrong_count,
        )
        for r in records
    ]


@app.post("/api/v1/wrong-answers", dependencies=[Depends(verify_api_key)])
def add_wrong_answer(req: WrongRecordCreate, db: Session = Depends(get_db)):
    """오답 등록 또는 기존 오답 횟수 1 증가 (API Key 인증 필수)"""
    word = db.query(Word).filter(Word.id == req.word_id).first()
    if not word:
        raise HTTPException(status_code=404, detail="해당 단어가 DB에 존재하지 않습니다.")

    record = db.query(WrongAnswerRecord).filter(WrongAnswerRecord.word_id == req.word_id).first()
    if record:
        record.wrong_count += 1
    else:
        record = WrongAnswerRecord(word_id=req.word_id, wrong_count=1)
        db.add(record)

    db.commit()
    return {"message": "오답이 DB에 성공적으로 저장되었습니다.", "word_id": req.word_id, "wrong_count": record.wrong_count}


@app.delete("/api/v1/wrong-answers/{record_id}", dependencies=[Depends(verify_api_key)])
def delete_wrong_answer(record_id: int, db: Session = Depends(get_db)):
    """개별 오답 항목 삭제 (API Key 인증 필수)"""
    record = db.query(WrongAnswerRecord).filter(WrongAnswerRecord.id == record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="해당 오답 기록을 찾을 수 없습니다.")
    db.delete(record)
    db.commit()
    return {"message": "오답 기록 삭제 완료", "record_id": record_id}


@app.delete("/api/v1/wrong-answers", dependencies=[Depends(verify_api_key)])
def clear_all_wrong_answers(db: Session = Depends(get_db)):
    """오답노트 전체 비우기 (API Key 인증 필수)"""
    db.query(WrongAnswerRecord).delete()
    db.commit()
    return {"message": "오답노트 전체 비우기 완료"}