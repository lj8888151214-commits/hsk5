class QuizOption {
  final int id;
  final String text;

  QuizOption({required this.id, required this.text});

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      id: json['id'] as int,
      text: json['text'] as String,
    );
  }
}

class QuizQuestion {
  final int id;
  final String hanzi;
  final String pinyin;
  final List<QuizOption> options;
  final int answerId;

  QuizQuestion({
    required this.id,
    required this.hanzi,
    required this.pinyin,
    required this.options,
    required this.answerId,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    var rawOptions = json['options'] as List;
    List<QuizOption> optionList =
        rawOptions.map((opt) => QuizOption.fromJson(opt)).toList();

    return QuizQuestion(
      id: json['id'] as int,
      hanzi: json['hanzi'] as String,
      pinyin: json['pinyin'] as String,
      options: optionList,
      answerId: json['answer_id'] as int,
    );
  }
}

/// 백엔드 DB의 wrong_answers 테이블 대응 모델
class DbWrongAnswer {
  final int id; // wrong_answers PK (삭제 시 사용)
  final int wordId; // words PK
  final String hanzi;
  final String pinyin;
  final String meaning;
  final int wrongCount;

  DbWrongAnswer({
    required this.id,
    required this.wordId,
    required this.hanzi,
    required this.pinyin,
    required this.meaning,
    required this.wrongCount,
  });

  factory DbWrongAnswer.fromJson(Map<String, dynamic> json) {
    return DbWrongAnswer(
      id: json['id'] as int,
      wordId: json['word_id'] as int,
      hanzi: json['hanzi'] as String,
      pinyin: json['pinyin'] as String,
      meaning: json['meaning'] as String,
      wrongCount: json['wrong_count'] as int,
    );
  }

  /// 복습 모드에서 QuizQuestion 형태로 재활용하기 위한 변환기
  QuizQuestion toQuizQuestion() {
    return QuizQuestion(
      id: wordId,
      hanzi: hanzi,
      pinyin: pinyin,
      options: [QuizOption(id: wordId, text: meaning)],
      answerId: wordId,
    );
  }
}