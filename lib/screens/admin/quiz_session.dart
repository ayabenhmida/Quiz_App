import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quiz/model/quiz_models.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import 'package:quiz/screens/admin/leaderbordpage.dart';
import 'dart:async';

class LaunchQuizPage extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const LaunchQuizPage({
    Key? key,
    required this.quizId,
    required this.quizTitle,
  }) : super(key: key);

  @override
  _LaunchQuizPageState createState() => _LaunchQuizPageState();
}

class _LaunchQuizPageState extends State<LaunchQuizPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _sessionId = '';
  String _sessionCode = '';
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = -1;
  QuestionState _questionState = QuestionState.waiting;
  List<Participant> _participants = [];
  bool _isSessionActive = false;

 
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;

  // Stream subscription for Firestore listener
  StreamSubscription<DocumentSnapshot>? _participantsSubscription;

  
  static const Color primaryColor = Color(0xFF46178F);
  static const Color accentColor = Color(0xFFFF3355);
  static const String defaultAvatar = 'avatar_1.png';

 
  final List<Color> _answerCardColors = [
    const Color(0xFF2196F3),
    const Color(0xFF00BCD4), 
    const Color(0xFFFFA000), 
    const Color(0xFFE91E63), 
  ];

  @override
  void initState() {
    super.initState();
    _loadQuizData();

  
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuart,
      ),
    );

    Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _participantsSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }


  String _generateSessionCode() {
    final random = Random();
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += random.nextInt(10).toString();
    }
    return code;
  }

 
  Future<void> _loadQuizData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final docSnapshot = await _firestore.collection('quizzes').doc(widget.quizId).get();

      if (!docSnapshot.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quiz introuvable'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: accentColor,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      final quizData = docSnapshot.data() as Map<String, dynamic>;
      List<dynamic> questionsList = quizData['questions'] ?? [];

      setState(() {
        _questions = List<Map<String, dynamic>>.from(questionsList);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement du quiz: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: accentColor,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createSession() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final sessionId = const Uuid().v4();
      final sessionCode = _generateSessionCode();

      await _firestore.collection('sessions').doc(sessionId).set({
        'sessionId': sessionId,
        'quizId': widget.quizId,
        'quizTitle': widget.quizTitle,
        'sessionCode': sessionCode,
        'createdAt': Timestamp.now(),
        'activeQuestionId': '',
        'questionState': QuestionState.waiting.toString(),
        'participants': [],
        'isActive': true,
        'acceptingNewParticipants': true,
      });

      setState(() {
        _sessionId = sessionId;
        _sessionCode = sessionCode;
        _currentQuestionIndex = -1;
        _questionState = QuestionState.waiting;
        _participants = [];
        _isSessionActive = true;
        _isLoading = false;
      });

      _listenForParticipants();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création de la session: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: accentColor,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  void _listenForParticipants() {
    _participantsSubscription = _firestore.collection('sessions').doc(_sessionId).snapshots().listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      List<dynamic>? participantsData = data['participants'] as List<dynamic>?;

      // Mise à jour du statut de la question active
      String questionStateStr = data['questionState'] ?? QuestionState.waiting.toString();
      QuestionState newQuestionState;

      if (questionStateStr == QuestionState.answering.toString()) {
        newQuestionState = QuestionState.answering;
      } else if (questionStateStr == QuestionState.results.toString()) {
        newQuestionState = QuestionState.results;
      } else {
        newQuestionState = QuestionState.waiting;
      }

      int? currentQuestionIdx = data['currentQuestionIndex'] as int?;

      if (mounted) {
        setState(() {
          if (participantsData != null) {
            _participants = participantsData
                .map((p) => Participant.fromMap(p as Map<String, dynamic>))
                .toList();
          }

          if (currentQuestionIdx != null) {
            _currentQuestionIndex = currentQuestionIdx;
          }

          _questionState = newQuestionState;
        });
      }
    });
  }

  Future<void> _nextQuestion() async {
    if (_questions.isEmpty) return;

    int nextIndex = _currentQuestionIndex + 1;

    if (nextIndex >= _questions.length) {
      await _endSession();
      return;
    }

    try {
      if (_currentQuestionIndex == -1) {
        await _firestore.collection('sessions').doc(_sessionId).update({
          'acceptingNewParticipants': false,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The quiz has started. New participants are blocked'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: primaryColor,
            ),
          );
        }
      }

      Map<String, dynamic> nextQuestion = _questions[nextIndex];

      await _firestore.collection('sessions').doc(_sessionId).update({
        'activeQuestionId': nextQuestion['questionId'],
        'questionState': QuestionState.answering.toString(),
        'currentQuestionIndex': nextIndex,
      });

      setState(() {
        _currentQuestionIndex = nextIndex;
        _questionState = QuestionState.answering;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du changement de question: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: accentColor,
          ),
        );
      }
    }
  }

  // Afficher les résultats de la question actuelle
  Future<void> _showResults() async {
    try {
      await _firestore.collection('sessions').doc(_sessionId).update({
        'questionState': QuestionState.results.toString(),
      });

      setState(() {
        _questionState = QuestionState.results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'affichage des résultats: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: accentColor,
          ),
        );
      }
    }
  }

  // Terminer la session
  Future<void> _endSession() async {
    try {
      await _firestore.collection('sessions').doc(_sessionId).update({
        'isActive': false,
        'endedAt': Timestamp.now(),
      });

      setState(() {
        _isSessionActive = false;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LeaderboardPage(sessionId: _sessionId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la fin de session: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: accentColor,
          ),
        );
      }
    }
  }


  Future<void> _stopSession() async {
    showDialog(
      context: context,
      builder

: (context) => AlertDialog(
        title: const Text('Stop session'),
        content: const Text('Are you sure you want to end this quiz session? This action is irreversible.'),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stop', style: TextStyle(color: primaryColor)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _endSession();
              if (mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: accentColor),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  Widget _getAvatarWidget(String avatar, String username, {bool isHighlighted = false}) {
    String avatarPath = avatar.isNotEmpty ? avatar : defaultAvatar;
    if (avatarPath.startsWith('assets/')) {
      avatarPath = avatarPath.replaceFirst('assets/', '');
    }

    bool isValidAsset = avatarPath.isNotEmpty;

    return Stack(
      alignment: Alignment.center,
      children: [
        Hero(
          tag: 'avatar_$username', 
          child: CircleAvatar(
            radius: 35,
            backgroundColor: accentColor,
            child: ClipOval(
              child: Image.asset(
                'assets/$avatarPath',
                fit: BoxFit.cover,
                width: 60,
                height: 60,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isHighlighted)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.green,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor, Color(0xFF2E1065)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeInAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: child,
                ),
              );
            },
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  )
                : _isSessionActive
                    ? _buildActiveSessionUI()
                    : _buildPreSessionUI(),
          ),
        ),
      ),
    );
  }

  Widget _buildPreSessionUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.quiz_outlined, size: 80, color: Colors.white70),
          const SizedBox(height: 20),
          Text(
            widget.quizTitle,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_questions.length} question${_questions.length > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 50),
          ElevatedButton.icon(
            onPressed: _createSession,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start quiz'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionUI() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: maxHeight),
            child: Column(
              children: [
               
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.quizTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isSessionActive)
                        IconButton(
                          icon: const Icon(Icons.stop_circle, color: accentColor),
                          onPressed: _stopSession,
                          tooltip: 'Stop session',
                        ),
                    ],
                  ),
                ),

                // Conteneur du code de session
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'CODE SESSION',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _sessionCode,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                          color: Colors.white,
                        ),
                      ),
                      if (_currentQuestionIndex >= 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Quiz in progress – New participants are blocked',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Information sur les participants et bouton Commencer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Participants: ${_participants.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (_currentQuestionIndex == -1)
                        ElevatedButton(
                          onPressed: _participants.isNotEmpty ? _nextQuestion : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                            
                            ),
                            disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                          ),
                          child: const Text('Start', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Liste des participants avec avatars améliorés
                if (_participants.isNotEmpty)
                  _buildParticipantsGrid()
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0,),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 36,
                              color: Colors.white38,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Waiting participants...',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share the code for players to join',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // UI de la question active (si une question est active)
                if (_currentQuestionIndex >= 0 && _currentQuestionIndex < _questions.length)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildQuestionUI(_questions[_currentQuestionIndex]),
                  ),

                // Espace supplémentaire en bas pour éviter les problèmes de débordement
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // Grille des participants optimisée
 Widget _buildParticipantsGrid() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    constraints: const BoxConstraints(
      maxWidth: 400,
    ),
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 5 : 4,
        childAspectRatio: 0.65,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final participant = _participants[index];
        final isHighlighted = participant.score == (_participants.isNotEmpty ? _participants.map((p) => p.score).reduce(max) : 0);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _getAvatarWidget(participant.avatar, participant.username, isHighlighted: isHighlighted),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Text(
                participant.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${participant.score} pts',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

  Widget _buildQuestionUI(Map<String, dynamic> question) {
    final String questionText = question['text'] ?? '';
    final List<dynamic> answersData = question['answers'] ?? [];
    final String correctAnswerId = question['correctAnswerId'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Question ${_currentQuestionIndex + 1}/${_questions.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStateColor(_questionState),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _getStateText(_questionState),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

    
          Text(
            questionText,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 20),

          // Liste des réponses en ligne au lieu d'une grille
          Column(
            children: List.generate(answersData.length, (index) {
              final answer = answersData[index] as Map<String, dynamic>;
              final bool isCorrect = answer['answerId'] == correctAnswerId;
              final String answerText = answer['text'] ?? '';

         
              Color baseColor = _answerCardColors[index % _answerCardColors.length];
              IconData? iconData;

            
              if (_questionState == QuestionState.results && isCorrect) {
                iconData = Icons.check_circle;
              }

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        answerText,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_questionState == QuestionState.results && isCorrect)
                      Icon(iconData, color: Colors.white),
                  ],
                ),
              );
            }),
          ),

         
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: _questionState == QuestionState.answering
                  ? ElevatedButton(
                      onPressed: _showResults,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Show Results',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                  : _questionState == QuestionState.results
                      ? ElevatedButton(
                          onPressed: _nextQuestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _currentQuestionIndex < _questions.length - 1
                                ? ' NEXT QUESTION '
                                : 'END QUIZ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        )
                      : const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStateColor(QuestionState state) {
    switch (state) {
      case QuestionState.waiting:
        return Colors.blue;
      case QuestionState.answering:
        return const Color(0xFFFF8800); 
      case QuestionState.results:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStateText(QuestionState state) {
    switch (state) {
      case QuestionState.waiting:
        return 'EN ATTENTE';
      case QuestionState.answering:
        return 'RÉPONSES EN COURS';
      case QuestionState.results:
        return 'RÉSULTATS';
      default:
        return '';
    }
  }
}

class Participant {
  final String participantId;
  final String username;
  final String avatar;
  final int score;

  Participant({
    required this.participantId,
    required this.username,
    required this.avatar,
    required this.score,
  });

  factory Participant.fromMap(Map<String, dynamic> map) {
    String avatar = map['avatar'] ?? _LaunchQuizPageState.defaultAvatar;
    if (avatar.isEmpty) {
      avatar = _LaunchQuizPageState.defaultAvatar;
    }
    return Participant(
      participantId: map['participantId'] ?? '',
      username: map['username'] ?? '',
      avatar: avatar,
      score: map['score'] ?? 0,
    );
  }
}
enum QuestionState {
  waiting,
  answering,
  results,
}
