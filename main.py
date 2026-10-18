import random
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy.sql.expression import func

from database import engine, Base, get_db
from models import Word

# 테이블 동기화 (기존 데이터 유지)
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