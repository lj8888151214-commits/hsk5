
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base


class Word(Base):
    __tablename__ = "words"

    id = Column(Integer, primary_key=True, index=True)
    hanzi = Column(String, unique=True, index=True, nullable=False)
    pinyin = Column(String, nullable=False)
    meaning = Column(String, nullable=False)

# --- 새로 추가할 오답 테이블 ---
class WrongAnswerRecord(Base):
    __tablename__ = "wrong_answers"

    id = Column(Integer, primary_key=True, index=True)
    word_id = Column(Integer, ForeignKey("words.id"), nullable=False)
    wrong_count = Column(Integer, default=1)  # 틀린 누적 횟수
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Word 테이블과의 관계 설정
    word = relationship("Word")