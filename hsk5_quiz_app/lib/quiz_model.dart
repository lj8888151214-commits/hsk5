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
    List<QuizOption> parsedOptions =
        rawOptions.map((opt) => QuizOption.fromJson(opt as Map<String, dynamic>)).toList();

    return QuizQuestion(
      id: json['id'] as int,
      hanzi: json['hanzi'] as String,
      pinyin: json['pinyin'] as String,
      options: parsedOptions,
      answerId: json['answer_id'] as int,
    );
  }
}

// 오답노트 저장 및 복습용 모델
class WrongAnswer {
  final QuizQuestion question;
  final String selectedMeaning;
  final String correctMeaning;

  WrongAnswer({
    required this.question,
    required this.selectedMeaning,
    required this.correctMeaning,
  });

  String get hanzi => question.hanzi;
  String get pinyin => question.pinyin;
}