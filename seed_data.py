from sqlalchemy.orm import Session
from models import Word

# HSK 5급 핵심 단어 샘플 데이터 (단어 리스트는 자유롭게 확장 가능)
INITIAL_HSK5_WORDS = [
    {"hanzi": "包括", "pinyin": "bāokuò", "meaning": "포함하다"},
    {"hanzi": "把握", "pinyin": "bǎwò", "meaning": "쥐다, 장악하다, 자신감"},
    {"hanzi": "摆", "pinyin": "bǎi", "meaning": "놓다, 진열하다, 흔들다"},
    {"hanzi": "班主任", "pinyin": "bānzhǔrèn", "meaning": "담임선생님"},
    {"hanzi": "办理", "pinyin": "bànlǐ", "meaning": "처리하다, 취급하다"},
    {"hanzi": "棒", "pinyin": "bàng", "meaning": "훌륭하다, 뛰어나다"},
    {"hanzi": "傍晚", "pinyin": "bàngwǎn", "meaning": "해 질 녘, 황혼"},
    {"hanzi": "包裹", "pinyin": "bāoguǒ", "meaning": "소포, 싸다"},
    {"hanzi": "包含", "pinyin": "bāohán", "meaning": "내포하다, 포함하다"},
    {"hanzi": "薄", "pinyin": "báo", "meaning": "얇다, 싱겁다"},
    {"hanzi": "宝贝", "pinyin": "bǎobèi", "meaning": "보물, 소중한 것"},
    {"hanzi": "宝贵", "pinyin": "bǎoguì", "meaning": "귀중하다, 소중하다"},
    {"hanzi": "保持", "pinyin": "bǎochí", "meaning": "유지하다, 지키다"},
    {"hanzi": "保存", "pinyin": "bǎocún", "meaning": "보존하다, 저장하다"},
    {"hanzi": "保留", "pinyin": "bǎoliú", "meaning": "보류하다, 남겨두다"},
    {"hanzi": "保险", "pinyin": "bǎoxiǎn", "meaning": "보험, 안전하다"},
    {"hanzi": "报到", "pinyin": "bàodào", "meaning": "출석 보고하다, 등록하다"},
    {"hanzi": "报道", "pinyin": "bàodào", "meaning": "보도하다, 보도"},
    {"hanzi": "报警", "pinyin": "bàojǐng", "meaning": "경보를 울리다, 경찰에 신고하다"},
    {"hanzi": "抱怨", "pinyin": "bàoyuàn", "meaning": "불평하다, 원망하다"},
    {"hanzi": "悲观", "pinyin": "bēiguān", "meaning": "비관적이다"},
    {"hanzi": "背", "pinyin": "bèi", "meaning": "외우다, 암기하다"},
    {"hanzi": "背景", "pinyin": "bèijǐng", "meaning": "배경"},
    {"hanzi": "被子", "pinyin": "bèizi", "meaning": "이불"},
    {"hanzi": "本质", "pinyin": "běnzhì", "meaning": "본질"},
    {"hanzi": "比例", "pinyin": "bǐlì", "meaning": "비율"},
    {"hanzi": "彼此", "pinyin": "bǐcǐ", "meaning": "서로, 피차"},
    {"hanzi": "必然", "pinyin": "bìrán", "meaning": "필연적이다"},
    {"hanzi": "必要", "pinyin": "bìyào", "meaning": "필요하다"},
    {"hanzi": "毕竟", "pinyin": "bìjìng", "meaning": "결국, 어쨌든"},
    {"hanzi": "编辑", "pinyin": "biānjí", "meaning": "편집하다, 편집자"},
    {"hanzi": "辩论", "pinyin": "biànlùn", "meaning": "토론하다, 변론하다"},
    {"hanzi": "标点", "pinyin": "biāodiǎn", "meaning": "구두점"},
    {"hanzi": "标志", "pinyin": "biāozhì", "meaning": "표지, 상징하다"},
    {"hanzi": "表达", "pinyin": "biǎodá", "meaning": "표현하다, 나타내다"},
    {"hanzi": "表情", "pinyin": "biǎoqíng", "meaning": "표정"},
    {"hanzi": "表面", "pinyin": "biǎomiàn", "meaning": "표면, 겉모습"},
    {"hanzi": "表明", "pinyin": "biǎomíng", "meaning": "명백히 밝히다"},
    {"hanzi": "丙", "pinyin": "bǐng", "meaning": "병 (갑을병정의 셋째)"},
    {"hanzi": "病毒", "pinyin": "bìngdú", "meaning": "바이러스"},
]


def seed_words(db: Session):
    existing_count = db.query(Word).count()
    if existing_count == 0:
        for item in INITIAL_HSK5_WORDS:
            word = Word(
                hanzi=item["hanzi"],
                pinyin=item["pinyin"],
                meaning=item["meaning"]
            )
            db.add(word)
        db.commit()
        print(f"✅ HSK 5급 단어 {len(INITIAL_HSK5_WORDS)}개 DB 적재 완료!")