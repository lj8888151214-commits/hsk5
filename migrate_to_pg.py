import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
import models

# .env 파일 로드
load_dotenv()

# 1. 로컬 SQLite (기존 데이터)
sqlite_engine = create_engine("sqlite:///./hsk5.db")
SqliteSession = sessionmaker(bind=sqlite_engine)

# 2. Render PostgreSQL (환경변수 DATABASE_URL에서 로드)
PG_URL = os.getenv("DATABASE_URL")
if not PG_URL:
    raise RuntimeError(
        "환경변수 DATABASE_URL이 설정되지 않았습니다. .env 파일 또는 서버 환경변수를 확인하세요."
    )

if PG_URL.startswith("postgres://"):
    PG_URL = PG_URL.replace("postgres://", "postgresql+psycopg2://", 1)
elif PG_URL.startswith("postgresql://"):
    PG_URL = PG_URL.replace("postgresql://", "postgresql+psycopg2://", 1)

pg_engine = create_engine(PG_URL, pool_pre_ping=True)
PgSession = sessionmaker(bind=pg_engine)

# 3. PostgreSQL에 테이블 자동 생성
models.Base.metadata.create_all(bind=pg_engine)

sqlite_db = SqliteSession()
pg_db = PgSession()

try:
    words = sqlite_db.query(models.Word).all()
    print(f"SQLite에서 {len(words)}개의 단어를 읽어왔습니다. PostgreSQL로 전송을 시작합니다...")

    word_objects = [
        models.Word(
            id=w.id,
            hanzi=w.hanzi,
            pinyin=w.pinyin,
            meaning=w.meaning
        )
        for w in words
    ]

    pg_db.bulk_save_objects(word_objects)
    pg_db.commit()
    print("단어 데이터 전송 완료. PostgreSQL 시퀀스를 동기화합니다...")

    with pg_engine.connect() as conn:
        conn.execute(text("SELECT setval(pg_get_serial_sequence('words', 'id'), coalesce(max(id), 1), true) FROM words;"))
        conn.commit()

    print("성공: 데이터 이전 및 시퀀스 동기화가 모두 완료되었습니다.")

except Exception as e:
    pg_db.rollback()
    print(f"이전 실패: {e}")
finally:
    sqlite_db.close()
    pg_db.close()