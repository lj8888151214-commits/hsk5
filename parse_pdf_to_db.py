import re
from pypdf import PdfReader
from sqlalchemy.orm import Session
from database import engine, Base, SessionLocal
from models import Word

# 1. DB 테이블 준비
Base.metadata.create_all(bind=engine)

PDF_PATH = "hsk_words.pdf"

# 한어병음 성조 기호 포함 정규식 패턴
PINYIN_PATTERN = re.compile(r"^[a-zA-ZāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüÜ'’\s\-~]+$")
POS_TAGS = ["명", "동", "형", "부", "대", "개", "조", "감", "접", "전", "양", "통", "초", "㈜"]


def clean_meaning(text: str) -> str:
    """품사 태그 및 불필요한 특수문자 제거"""
    cleaned = text.strip()
    for tag in POS_TAGS:
        if cleaned.startswith(tag):
            cleaned = cleaned[len(tag):].strip()
    return cleaned


def parse_pdf_words(pdf_path: str):
    reader = PdfReader(pdf_path)
    words = []

    # 텍스트 전체 블록 추출
    for page_idx, page in enumerate(reader.pages):
        text = page.extract_text()
        if not text:
            continue

        lines = [line.strip() for line in text.split("\n") if line.strip()]

        for line in lines:
            # 1. 파이프(|) 구분자로 되어 있는 줄 처리
            if "|" in line:
                parts = [p.strip() for p in line.split("|") if p.strip()]
                if len(parts) >= 3:
                    hanzi = parts[0]
                    pinyin = parts[1]
                    meaning = clean_meaning(" ".join(parts[2:]))

                    # 한자 유효성 검증
                    if re.search(r"[\u4e00-\u9fff]", hanzi) and meaning:
                        words.append({"hanzi": hanzi, "pinyin": pinyin, "meaning": meaning})
                elif len(parts) == 2:
                    # '한자 | pinyin' 형태이거나 'pinyin | 뜻' 형태일 수 있음
                    pass

            # 2. 101페이지와 같이 한 줄에 나열된 형태 ('座 zuò  좌석. 자리.')
            else:
                match = re.findall(
                    r"([\u4e00-\u9fff]+)\s+([a-zA-ZāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüÜ\s]+?)\s*[\.\s]\s*([가-힣\s\.,~]+)", line)
                for h, p, m in match:
                    words.append({"hanzi": h.strip(), "pinyin": p.strip(), "meaning": clean_meaning(m)})

    # 중복 제거 (한자 기준)
    unique_words = {}
    for w in words:
        if w["hanzi"] not in unique_words:
            unique_words[w["hanzi"]] = w

    return list(unique_words.values())


def save_to_db(word_list):
    db: Session = SessionLocal()
    inserted_count = 0
    updated_count = 0

    try:
        for item in word_list:
            existing = db.query(Word).filter(Word.hanzi == item["hanzi"]).first()
            if existing:
                existing.pinyin = item["pinyin"]
                existing.meaning = item["meaning"]
                updated_count += 1
            else:
                new_word = Word(
                    hanzi=item["hanzi"],
                    pinyin=item["pinyin"],
                    meaning=item["meaning"]
                )
                db.add(new_word)
                inserted_count += 1

        db.commit()
        print(f"🎉 작업 완료! 신규 단어: {inserted_count}개 삽입 / 기존 단어: {updated_count}개 갱신")
        print(f"📊 현재 DB 총 단어 수: {db.query(Word).count()}개")
    except Exception as e:
        db.rollback()
        print(f"❌ DB 저장 중 오류 발생: {e}")
    finally:
        db.close()


if __name__ == "__main__":
    print("📖 PDF에서 HSK 단어/성조/뜻 추출을 시작합니다...")
    extracted = parse_pdf_words(PDF_PATH)
    print(f"🔍 추출된 유효 단어 수: {len(extracted)}개")
    if extracted:
        save_to_db(extracted)
    else:
        print("⚠️ 단어가 추출되지 않았습니다. PDF 파일명과 경로를 확인해 주세요.")