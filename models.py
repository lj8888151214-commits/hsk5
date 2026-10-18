from sqlalchemy import Column, Integer, String
from database import Base


class Word(Base):
    __tablename__ = "words"

    id = Column(Integer, primary_key=True, index=True)
    hanzi = Column(String, unique=True, index=True, nullable=False)
    pinyin = Column(String, nullable=False)
    meaning = Column(String, nullable=False)