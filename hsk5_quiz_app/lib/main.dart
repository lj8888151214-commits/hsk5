import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'quiz_model.dart';

void main() {
  // 1. Flutter 엔진과 네이티브 바인딩 보장
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 릴리즈 모드에서도 크래시 발생 시 화면에 에러를 강제 표시
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '🚨 앱 기동 에러 발생:\n\n${details.exceptionAsString()}\n\n${details.stack}',
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  };

  runApp(const HskQuizApp());
}

class HskQuizApp extends StatelessWidget {
  const HskQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HSK 5 Quiz',
      debugShowCheckedModeBanner: false,
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
  // 백엔드 주소 (Render 주소)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://hsk5.onrender.com',
  );
  static const String apiKey = String.fromEnvironment('API_SECRET_KEY');

  QuizQuestion? _question;
  bool _isLoading = true;
  bool _isAnswerRevealed = false;
  int _score = 0;
  int _questionCount = 0;

  // 초기 구동 카운터 및 로딩 상태 관리
  int _loadingSeconds = 0;
  Timer? _countdownTimer;
  String _loadingMessage = '서버와 연결을 확인하는 중입니다...';

  // DB에서 불러온 오답 목록
  List<DbWrongAnswer> _wrongAnswers = [];

  // 복습 모드 상태 관리
  bool _isReviewMode = false;
  List<DbWrongAnswer> _reviewQueue = [];
  int _reviewIndex = 0;

  // 현재 문제의 한국어 뜻 가져오기
  String get _currentMeaning {
    if (_question == null) return '';
    return _question!.options
        .firstWhere(
          (opt) => opt.id == _question!.answerId,
          orElse: () => QuizOption(id: -1, text: '뜻을 불러올 수 없습니다.'),
        )
        .text;
  }

  // 공통 헤더 (API Key 인증 포함)
  Map<String, String> get _commonHeaders => {
        'ngrok-skip-browser-warning': 'true',
        'Accept': 'application/json',
        if (apiKey.isNotEmpty) 'X-API-Key': apiKey,
      };

  @override
  void initState() {
    super.initState();
    _startTimer();

    // 첫 프레임 UI가 완전히 그려진 직후 네트워크 요청을 시작하도록 보장
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNextQuestion();
      _fetchWrongAnswersFromDB(); // 앱 기동 시 DB 오답 목록 동기화
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // 1초 단위 타이머 시작
  void _startTimer() {
    _loadingSeconds = 0;
    _loadingMessage = '서버와 연결을 확인하는 중입니다...';
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _loadingSeconds++;
          if (_loadingSeconds >= 10) {
            _loadingMessage = '서버 콜드 스타트 중입니다. 잠시만 기다려주세요...';
          }
        });
      }
    });
  }

  // 타이머 종료
  void _stopTimer() {
    _countdownTimer?.cancel();
  }

  // 1. DB에서 오답 목록 불러오기 (타임아웃 10초 부여)
  Future<void> _fetchWrongAnswersFromDB() async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/api/v1/wrong-answers'),
            headers: _commonHeaders,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
        if (mounted) {
          setState(() {
            _wrongAnswers =
                data.map((item) => DbWrongAnswer.fromJson(item)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('오답 목록 로드 실패: $e');
    }
  }

  // 2. 새 단어 로드 (Render 콜드스타트 감안 50초 타임아웃)
  Future<void> _fetchNextQuestion() async {
    setState(() {
      _isLoading = true;
      _isAnswerRevealed = false;
    });

    if (_isReviewMode) {
      if (_reviewIndex < _reviewQueue.length) {
        setState(() {
          _question = _reviewQueue[_reviewIndex].toQuizQuestion();
          _isLoading = false;
        });
        _stopTimer();
      } else {
        _showReviewCompleteDialog();
      }
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/v1/quiz/random'),
            headers: _commonHeaders,
          )
          .timeout(const Duration(seconds: 50));

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> data = json.decode(decodedBody);

        if (mounted) {
          setState(() {
            _question = QuizQuestion.fromJson(data);
            _isLoading = false;
          });
          _stopTimer();
        }
      } else {
        throw Exception('API 호출 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _question = null; // 실패 시 재시도 화면 노출
        });
        _stopTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('단어 로드 실패: $e')),
        );
      }
    }
  }

  // 뜻 열기 (블라인드 해제)
  void _revealAnswer() {
    if (!_isAnswerRevealed) {
      setState(() {
        _isAnswerRevealed = true;
      });
    }
  }

  // [알고 있어요 (정답)] 선택 시
  void _markAsKnown() async {
    setState(() {
      _questionCount++;
      _score++;
    });

    if (_isReviewMode && _reviewIndex < _reviewQueue.length) {
      final currentItem = _reviewQueue[_reviewIndex];
      await _deleteWrongAnswer(currentItem.id, silent: true);
    }

    _goToNext();
  }

  // [헷갈려요 (오답)] 선택 시 DB 저장
  void _markAsUnknown() async {
    setState(() {
      _questionCount++;
    });

    if (!_isReviewMode && _question != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/api/v1/wrong-answers'),
          headers: {
            'Content-Type': 'application/json',
            ..._commonHeaders,
          },
          body: json.encode({'word_id': _question!.answerId}),
        );
        _fetchWrongAnswersFromDB();
      } catch (e) {
        debugPrint('오답 DB 저장 실패: $e');
      }
    }

    _goToNext();
  }

  void _goToNext() {
    if (_isReviewMode) {
      _reviewIndex++;
    }
    _fetchNextQuestion();
  }

  // 개별 오답 삭제 (DB 호출)
  Future<void> _deleteWrongAnswer(int recordId, {bool silent = false}) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/v1/wrong-answers/$recordId'),
        headers: _commonHeaders,
      );
      if (res.statusCode == 200) {
        await _fetchWrongAnswersFromDB();
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('오답노트에서 삭제되었습니다.')),
          );
        }
      }
    } catch (e) {
      debugPrint('오답 삭제 실패: $e');
    }
  }

  // 오답 전체 비우기 (DB 호출)
  Future<void> _clearAllWrongAnswers() async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/v1/wrong-answers'),
        headers: _commonHeaders,
      );
      if (res.statusCode == 200) {
        setState(() {
          _wrongAnswers.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('오답노트가 초기화되었습니다.')),
          );
        }
      }
    } catch (e) {
      debugPrint('오답 전체 비우기 실패: $e');
    }
  }

  // 복습 모드 진입
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

  // 일반 모드 복귀
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

  // 복습 완료 팝업
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
                      onPressed: () async {
                        await _clearAllWrongAnswers();
                        setDialogState(() {});
                      },
                      child: const Text('전체 비우기',
                          style: TextStyle(color: Colors.red)),
                    )
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: _wrongAnswers.isEmpty
                    ? const Center(child: Text('저장된 오답이 없습니다. 완벽해요! 🎉'))
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
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.pinyin,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const Spacer(),
                                Chip(
                                  label: Text(
                                    '${item.wrongCount}회 틀림',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.red,
                                    ),
                                  ),
                                  backgroundColor: Colors.red.shade50,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '뜻: ${item.meaning}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.grey),
                              onPressed: () async {
                                await _deleteWrongAnswer(item.id);
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
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.deepOrange),
              ),
            )
          else
            TextButton.icon(
              onPressed: _showWrongAnswerDialog,
              icon: const Icon(Icons.menu_book, color: Colors.deepPurple),
              label: Text(
                '오답 (${_wrongAnswers.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.deepPurple),
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
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          strokeWidth: 3.5,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '접속 대기 시간: $_loadingSeconds초',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _loadingMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : _question == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('문제를 불러올 수 없습니다.'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              _startTimer();
                              _fetchNextQuestion();
                            },
                            child: const Text('다시 시도'),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 16.0),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 36),
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
                                padding: const EdgeInsets.symmetric(
                                    vertical: 24, horizontal: 16),
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
                                          _currentMeaning,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepPurple,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.touch_app,
                                                color: Colors.grey.shade600,
                                                size: 24),
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
                                        side: BorderSide(
                                            color: Colors.red.shade300,
                                            width: 1.5),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: _markAsUnknown,
                                      icon: const Icon(Icons.close, size: 24),
                                      label: const Text(
                                        '헷갈려요 (오답)',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
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
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                      onPressed: _markAsKnown,
                                      icon: const Icon(Icons.check, size: 24),
                                      label: const Text(
                                        '알고 있어요 (정답)',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Center(
                                child: Text(
                                  '단어를 떠올려본 후 뜻을 열어보세요!',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500),
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