import random
from typing import List
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy.sql.expression import func
from pydantic import BaseModel

from database import engine, Base, get_db
from models import Word, WrongAnswerRecord

# 테이블 동기화 (새로 추가한 wrong_answers 테이블 자동 생성)
Base.metadata.create_all(bind=engine)

app = FastAPI(title="HSK 5급 단어 퀴즈 API")

# CORS 설정 (Flutter Web 통신 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- Pydantic 요청/응답 스키마 ---
class WrongRecordCreate(BaseModel):
    word_id: int


class WrongWordResponse(BaseModel):
    id: int  # wrong_answers 테이블 PK
    word_id: int  # words 테이블 PK
    hanzi: str
    pinyin: str
    meaning: str
    wrong_count: int


# --- 기존 퀴즈 API ---
@app.get("/api/v1/quiz/random")
def get_random_quiz(db: Session = Depends(get_db)):
    total_count = db.query(Word).count()
    if total_count < 4:
        raise HTTPException(
            status_code=400,
            detail=f"DB에 단어가 부족합니다. (현재 {total_count}개)"
        )

    # 1. 전체 단어 테이블에서 랜덤으로 문제 1개 추출
    target_word = db.query(Word).order_by(func.random()).first()

    # 2. 정답을 제외한 나머지 단어 중 랜덤으로 오답 보기 3개 추출
    distractors = (
        db.query(Word)
        .filter(Word.id != target_word.id)
        .order_by(func.random())
        .limit(3)
        .all()
    )

    # 3. 4개 보기 조합 및 셔플
    options = [
        {"id": target_word.id, "text": target_word.meaning}
    ]
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
    results = []
    for r in records:
        results.append(
            WrongWordResponse(
                id=r.id,
                word_id=r.word.id,
                hanzi=r.word.hanzi,
                pinyin=r.word.pinyin,
                meaning=r.word.meaning,
                wrong_count=r.wrong_count,
            )
        )
    return results


@app.post("/api/v1/wrong-answers")
def add_wrong_answer(req: WrongRecordCreate, db: Session = Depends(get_db)):
    """오답 등록 또는 기존 오답 횟수 1 증가"""
    # 단어 존재 여부 검증
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


@app.delete("/api/v1/wrong-answers/{record_id}")
def delete_wrong_answer(record_id: int, db: Session = Depends(get_db)):
    """개별 오답 항목 삭제 (복습 완료 또는 수동 삭제)"""
    record = db.query(WrongAnswerRecord).filter(WrongAnswerRecord.id == record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="해당 오답 기록을 찾을 수 없습니다.")
    db.delete(record)
    db.commit()
    return {"message": "오답 기록 삭제 완료", "record_id": record_id}


@app.delete("/api/v1/wrong-answers")
def clear_all_wrong_answers(db: Session = Depends(get_db)):
    """오답노트 전체 비우기"""
    db.query(WrongAnswerRecord).delete()
    db.commit()
    return {"message": "오답노트 전체 비우기 완료"}