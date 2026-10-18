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
      title: 'HSK 5급 단어 퀴즈',
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
  //final String apiUrl = 'http://127.0.0.1:8000/api/v1/quiz/random';
  final String apiUrl = 'http://192.168.30.2:8000/api/v1/quiz/random';

  QuizQuestion? _question;
  bool _isLoading = true;
  int? _selectedOptionId;
  int _score = 0;
  int _questionCount = 0;

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

  // 다음 문제 로드 (일반 모드 vs 복습 모드)
  Future<void> _fetchNextQuestion() async {
    setState(() {
      _isLoading = true;
      _selectedOptionId = null;
    });

    if (_isReviewMode) {
      if (_reviewIndex < _reviewQueue.length) {
        setState(() {
          _question = _reviewQueue[_reviewIndex].question;
          _isLoading = false;
        });
      } else {
        // 복습 완료 처리
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

  void _onOptionSelected(int optionId) {
    if (_selectedOptionId != null || _question == null) return;

    setState(() {
      _selectedOptionId = optionId;
      _questionCount++;

      final isCorrect = (optionId == _question!.answerId);

      if (isCorrect) {
        _score++;
        if (_isReviewMode) {
          // 복습 모드에서 맞힌 단어는 오답 목록에서 자동 제거
          _wrongAnswers.removeWhere((item) => item.hanzi == _question!.hanzi);
        }
      } else {
        if (!_isReviewMode) {
          // 일반 모드에서 틀린 경우 오답노트에 추가
          final selectedText = _question!.options
              .firstWhere((opt) => opt.id == optionId, orElse: () => QuizOption(id: -1, text: ''))
              .text;
          final correctText = _question!.options
              .firstWhere((opt) => opt.id == _question!.answerId, orElse: () => QuizOption(id: -1, text: ''))
              .text;

          final isAlreadyAdded = _wrongAnswers.any((item) => item.hanzi == _question!.hanzi);
          if (!isAlreadyAdded) {
            _wrongAnswers.add(
              WrongAnswer(
                question: _question!,
                selectedMeaning: selectedText,
                correctMeaning: correctText,
              ),
            );
          }
        }
      }
    });
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

  Color _getButtonColor(int optionId) {
    if (_selectedOptionId == null) {
      return Colors.white;
    }
    if (optionId == _question!.answerId) {
      return Colors.green.shade100;
    }
    if (optionId == _selectedOptionId) {
      return Colors.red.shade100;
    }
    return Colors.white;
  }

  // 오답노트 모달 띄우기
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '정답: ${item.correctMeaning}',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '선택한 오답: ${item.selectedMeaning}',
                                    style: const TextStyle(color: Colors.redAccent),
                                  ),
                                ],
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
        title: Text(_isReviewMode ? '📖 HSK 5급 오답 복습 모드' : 'HSK 5급 단어 퀴즈'),
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
                '일반 모드 복귀',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
              ),
            )
          else
            TextButton.icon(
              onPressed: _showWrongAnswerDialog,
              icon: const Icon(Icons.menu_book, color: Colors.deepPurple),
              label: Text(
                '오답노트 (${_wrongAnswers.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_isReviewMode)
                                Chip(
                                  label: Text(
                                    '복습 진행: ${_reviewIndex + 1} / ${_reviewQueue.length}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  backgroundColor: Colors.deepOrange,
                                )
                              else
                                const SizedBox(),
                              Text(
                                '점수: $_score / $_questionCount',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: [
                                  Text(
                                    _question!.hanzi,
                                    style: const TextStyle(
                                      fontSize: 48,
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
                          const SizedBox(height: 32),
                          ..._question!.options.map((option) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: _getButtonColor(option.id),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(
                                    color: _selectedOptionId != null &&
                                            option.id == _question!.answerId
                                        ? Colors.green
                                        : Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                ),
                                onPressed: () => _onOptionSelected(option.id),
                                child: Text(
                                  option.text,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 24),
                          if (_selectedOptionId != null)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isReviewMode
                                    ? Colors.deepOrange
                                    : Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _goToNext,
                              child: Text(
                                _isReviewMode && _reviewIndex == _reviewQueue.length - 1
                                    ? '복습 완료하기'
                                    : '다음 문제',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}