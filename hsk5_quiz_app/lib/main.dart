import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'quiz_model.dart';

void main() {
  runApp(const HskQuizApp());
}

class HskQuizApp extends StatelessWidget {
  const HskQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HSK 5급 단어 플래시카드',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const QuizScreen(),
    );
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final String apiUrl = 'https://hsk5.onrender.com/api/v1/quiz/random';

  QuizQuestion? _question;
  bool _isLoading = true;
  bool _isAnswerRevealed = false; // 뜻 공개 여부 (블라인드 상태)
  int _score = 0;
  int _questionCount = 0;

  // 정답 텍스트 추출 헬퍼
  String get _correctMeaning {
    if (_question == null) return '';
    return _question!.options
        .firstWhere(
          (opt) => opt.id == _question!.answerId,
          orElse: () => QuizOption(id: -1, text: '뜻을 불러올 수 없습니다.'),
        )
        .text;
  }

  // 오답 목록
  final List<WrongAnswer> _wrongAnswers = [];

  // 복습 모드 상태 관리
  bool _isReviewMode = false;
  List<WrongAnswer> _reviewQueue = [];
  int _reviewIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchNextQuestion();
  }

  // 다음 문제 로드
  Future<void> _fetchNextQuestion() async {
    setState(() {
      _isLoading = true;
      _isAnswerRevealed = false; // 새 단어 로드 시 다시 블라인드 처리
    });

    if (_isReviewMode) {
      if (_reviewIndex < _reviewQueue.length) {
        setState(() {
          _question = _reviewQueue[_reviewIndex].question;
          _isLoading = false;
        });
      } else {
        _showReviewCompleteDialog();
      }
      return;
    }

    // 일반 모드: 백엔드 API 호출
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> data = json.decode(decodedBody);

        setState(() {
          _question = QuizQuestion.fromJson(data);
          _isLoading = false;
        });
      } else {
        throw Exception('API 호출 실패: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('백엔드 연결 실패: $e')),
        );
      }
    }
  }

  // 블라인드 해제 (뜻 열기)
  void _revealAnswer() {
    if (!_isAnswerRevealed) {
      setState(() {
        _isAnswerRevealed = true;
      });
    }
  }

  // 정답 처리 (알고 있어요)
  void _markAsKnown() {
    setState(() {
      _questionCount++;
      _score++;

      if (_isReviewMode && _question != null) {
        _wrongAnswers.removeWhere((item) => item.hanzi == _question!.hanzi);
      }
    });

    _goToNext();
  }

  // 오답 처리 (헷갈려요)
  void _markAsUnknown() {
    setState(() {
      _questionCount++;

      if (!_isReviewMode && _question != null) {
        final isAlreadyAdded = _wrongAnswers.any((item) => item.hanzi == _question!.hanzi);
        if (!isAlreadyAdded) {
          _wrongAnswers.add(
            WrongAnswer(
              question: _question!,
              selectedMeaning: '복습 필요',
              correctMeaning: _correctMeaning,
            ),
          );
        }
      }
    });

    _goToNext();
  }

  void _goToNext() {
    if (_isReviewMode) {
      _reviewIndex++;
    }
    _fetchNextQuestion();
  }

  // 복습 모드 시작
  void _startReviewMode() {
    if (_wrongAnswers.isEmpty) return;

    setState(() {
      _isReviewMode = true;
      _reviewQueue = List.from(_wrongAnswers);
      _reviewIndex = 0;
      _score = 0;
      _questionCount = 0;
    });

    _fetchNextQuestion();
  }

  // 일반 모드로 복귀
  void _exitReviewMode() {
    setState(() {
      _isReviewMode = false;
      _reviewQueue = [];
      _reviewIndex = 0;
      _score = 0;
      _questionCount = 0;
    });
    _fetchNextQuestion();
  }

  // 복습 완료 다이얼로그
  void _showReviewCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 복습 완료!'),
        content: Text(
          '오답 복습을 모두 마쳤습니다!\n남은 오답: ${_wrongAnswers.length}개',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exitReviewMode();
            },
            child: const Text('일반 모드로 돌아가기'),
          ),
          if (_wrongAnswers.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startReviewMode();
              },
              child: const Text('남은 오답 다시 복습'),
            ),
        ],
      ),
    );
  }

  // 오답노트 모달
  void _showWrongAnswerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('오답노트 (${_wrongAnswers.length}개)'),
                  if (_wrongAnswers.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _wrongAnswers.clear();
                        });
                        setDialogState(() {});
                      },
                      child: const Text('전체 비우기', style: TextStyle(color: Colors.red)),
                    )
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: _wrongAnswers.isEmpty
                    ? const Center(child: Text('틀린 단어가 없습니다. 완벽해요! 🎉'))
                    : ListView.separated(
                        itemCount: _wrongAnswers.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = _wrongAnswers[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Row(
                              children: [
                                Text(
                                  item.hanzi,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.pinyin,
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '뜻: ${item.correctMeaning}',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _wrongAnswers.removeAt(index);
                                });
                                setDialogState(() {});
                              },
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                if (_wrongAnswers.isNotEmpty && !_isReviewMode)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.replay),
                    label: const Text('오답 복습 시작'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _startReviewMode();
                    },
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isReviewMode ? '📖 HSK 5급 오답 복습' : 'HSK 5급 단어 암기'),
        centerTitle: true,
        backgroundColor: _isReviewMode
            ? Colors.orange.shade100
            : Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isReviewMode)
            TextButton.icon(
              onPressed: _exitReviewMode,
              icon: const Icon(Icons.close, color: Colors.deepOrange),
              label: const Text(
                '복귀',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
              ),
            )
          else
            TextButton.icon(
              onPressed: _showWrongAnswerDialog,
              icon: const Icon(Icons.menu_book, color: Colors.deepPurple),
              label: Text(
                '오답 (${_wrongAnswers.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _question == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('문제를 불러올 수 없습니다.'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchNextQuestion,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 상단 진행 상태
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_isReviewMode)
                                  Chip(
                                    label: Text(
                                      '복습: ${_reviewIndex + 1} / ${_reviewQueue.length}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                    backgroundColor: Colors.deepOrange,
                                    visualDensity: VisualDensity.compact,
                                  )
                                else
                                  const SizedBox(),
                                Text(
                                  '암기 완료: $_score / $_questionCount',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 메인 단어 카드 (한자 + 병음)
                            Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 36),
                                child: Column(
                                  children: [
                                    Text(
                                      _question!.hanzi,
                                      style: const TextStyle(
                                        fontSize: 46,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _question!.pinyin,
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 블라인드 한국어 뜻 영역 (터치하여 열기)
                            InkWell(
                              onTap: _revealAnswer,
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: _isAnswerRevealed
                                      ? Colors.deepPurple.shade50
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _isAnswerRevealed
                                        ? Colors.deepPurple.shade300
                                        : Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: _isAnswerRevealed
                                      ? Text(
                                          _correctMeaning,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepPurple,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.touch_app, color: Colors.grey.shade600, size: 24),
                                            const SizedBox(width: 8),
                                            Text(
                                              '터치하여 한국어 뜻 확인',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // 뜻을 확인한 후에만 나타나는 정답/오답 판정 버튼
                            if (_isAnswerRevealed)
                              Row(
                                children: [
                                  // 오답 버튼 (헷갈려요)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade50,
                                        foregroundColor: Colors.red.shade700,
                                        side: BorderSide(color: Colors.red.shade300, width: 1.5),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: _markAsUnknown,
                                      icon: const Icon(Icons.close, size: 24),
                                      label: const Text(
                                        '헷갈려요 (오답)',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // 정답 버튼 (알고 있어요)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                      onPressed: _markAsKnown,
                                      icon: const Icon(Icons.check, size: 24),
                                      label: const Text(
                                        '알고 있어요 (정답)',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              // 뜻 확인 전 안내
                              Center(
                                child: Text(
                                  '단어를 떠올려본 후 뜻을 열어보세요!',
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                                ),
                              ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}