import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class QuestionScreen extends StatefulWidget {
  final String sessionId;
  final String participantId;
  final String quizId;
  final int currentQuestionIndex;

  const QuestionScreen({
    Key? key,
    required this.sessionId,
    required this.participantId,
    required this.quizId,
    required this.currentQuestionIndex,
  }) : super(key: key);

  @override
  _QuestionScreenState createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _currentQuestion;
  String _questionState = 'answering';
  String? _selectedAnswerId;
  bool _hasSubmittedAnswer = false;
  late StreamSubscription<DocumentSnapshot> _sessionSubscription;
  DateTime? _questionStartTime;
  int _responseTimeMs = 0;
  bool _isCorrect = false;
  int _pointsEarned = 0;
  int _totalScore = 0;
  int _totalQuestions = 0;
  int _rank = 0;
  final Set<int> _checkedQuestions = {};
  
  // Animation controller pour le timer visuel
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _setupSessionListener();
    _fetchCurrentQuestion();
    
    // Initialiser l'animation du timer (20 secondes par défaut)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _sessionSubscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _setupSessionListener() {
    _sessionSubscription = _firestore
        .collection('sessions')
        .doc(widget.sessionId)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (!snapshot.exists) {
        _showErrorAndGoBack('Session no longer exists');
        return;
      }

      final sessionData = snapshot.data() as Map<String, dynamic>?;
      if (sessionData == null) return;

      final bool isActive = sessionData['isActive'] ?? true;
      if (!isActive) {
        _navigateToResults();
        return;
      }

      final String newQuestionState = sessionData['questionState'] ?? '';
      if (newQuestionState != _questionState) {
        setState(() {
          _questionState = newQuestionState;
        });

        if (newQuestionState == 'QuestionState.answering') {
          _questionStartTime = DateTime.now();
          _animationController.reset();
          _animationController.forward();
        } else if (newQuestionState == 'QuestionState.results') {
          _animationController.stop();
          _checkAnswer();
        }
      }

      final int questionIndex = sessionData['currentQuestionIndex'] ?? 0;
      final int totalQuestions = sessionData['totalQuestions'] ?? 0;
      setState(() {
        _totalQuestions = totalQuestions;
      });

      if (questionIndex >= totalQuestions - 1 && _questionState == 'QuestionState.results') {
        _showResultsNotification();
        return;
      }

      if (questionIndex != widget.currentQuestionIndex) {
        if (mounted) {
          context.pushNamed(
            'question',
            extra: {
              'session_id': widget.sessionId,
              'participant_id': widget.participantId,
              'quiz_id': widget.quizId,
              'current_question_index': questionIndex,
            },
          );
        }
      }

      final List<dynamic> participants = sessionData['participants'] ?? [];
      for (var participant in participants) {
        if (participant['participantId'] == widget.participantId) {
          final newScore = participant['score'] ?? 0;
          final newRank = participant['rank'] ?? 0;
          if (newScore != _totalScore || newRank != _rank) {
            setState(() {
              _totalScore = newScore;
              _rank = newRank;
            });
          }
          break;
        }
      }
    }, onError: (e) {
      debugPrint('Erreur dans le listener de session : $e');
      _showErrorAndGoBack('Erreur de synchronisation : $e');
    });
  }

  Future<void> _fetchCurrentQuestion() async {
    try {
      final quizDoc = await _firestore.collection('quizzes').doc(widget.quizId).get();
      if (!quizDoc.exists) {
        _showErrorAndGoBack('Quiz not found');
        return;
      }

      final quizData = quizDoc.data() as Map<String, dynamic>;
      final List<dynamic> questions = quizData['questions'] ?? [];
      
      setState(() {
        _totalQuestions = questions.length;
      });

      if (widget.currentQuestionIndex >= 0 && widget.currentQuestionIndex < questions.length) {
        setState(() {
          _currentQuestion = Map<String, dynamic>.from(questions[widget.currentQuestionIndex]);
          _isLoading = false;
        });
      } else {
        _showErrorAndGoBack('Question not found');
      }

      final sessionDoc = await _firestore.collection('sessions').doc(widget.sessionId).get();
      if (sessionDoc.exists) {
        final sessionData = sessionDoc.data() as Map<String, dynamic>;
        final newQuestionState = sessionData['questionState'] ?? 'QuestionState.answering';
        
        setState(() {
          _questionState = newQuestionState;
          
          if (newQuestionState == 'QuestionState.answering') {
            _questionStartTime = DateTime.now();
            _animationController.reset();
            _animationController.forward();
          } else {
            _animationController.stop();
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching question: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorAndGoBack('Error loading question: $e');
      }
    }
  }

  Future<void> _submitAnswer(String answerId) async {
    if (_hasSubmittedAnswer || _questionState != 'QuestionState.answering') {
      return;
    }

    final now = DateTime.now();
    final responseTimeMs = _questionStartTime != null 
        ? now.difference(_questionStartTime!).inMilliseconds
        : 0;
        
    setState(() {
      _selectedAnswerId = answerId;
      _hasSubmittedAnswer = true;
      _responseTimeMs = responseTimeMs;
    });

    try {
      await _firestore
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('answers')
          .doc('${widget.participantId}_${widget.currentQuestionIndex}')
          .set({
        'participantId': widget.participantId,
        'questionId': _currentQuestion?['questionId'] ?? '',
        'questionIndex': widget.currentQuestionIndex,
        'answerId': answerId,
        'timestamp': Timestamp.now(),
        'responseTimeMs': responseTimeMs,
      });

      // Optionnel: Ajouter un effet visuel pour montrer que la réponse a été soumise
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Réponse soumise !', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(10),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('Error submitting answer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de soumission de la réponse: $e')),
      );
      setState(() {
        _hasSubmittedAnswer = false;
        _selectedAnswerId = null;
      });
    }
  }

 

  Future<void> _checkAnswer() async {
    if (_currentQuestion == null || _selectedAnswerId == null) return;

    if (_checkedQuestions.contains(widget.currentQuestionIndex)) {
      debugPrint('Question ${widget.currentQuestionIndex} déjà vérifiée, ignorée');
      return;
    }

    final String correctAnswerId = _currentQuestion!['correctAnswerId'] ?? '';
    final bool isCorrect = _selectedAnswerId == correctAnswerId;

    setState(() {
      _isCorrect = isCorrect;
      _pointsEarned = isCorrect ? 1 : 0;
    });

    try {
      await _firestore.runTransaction((transaction) async {
        final sessionRef = _firestore.collection('sessions').doc(widget.sessionId);
        final sessionDoc = await transaction.get(sessionRef);

        if (!sessionDoc.exists) {
          debugPrint('Session non trouvée : ${widget.sessionId}');
          return;
        }

        final sessionData = sessionDoc.data() as Map<String, dynamic>;
        final List<dynamic> participants = List.from(sessionData['participants'] ?? []);

        bool participantFound = false;

        for (int i = 0; i < participants.length; i++) {
          if (participants[i]['participantId'] == widget.participantId) {
            participantFound = true;

            int totalResponseTime = participants[i]['totalResponseTimeMs'] ?? 0;
            participants[i]['totalResponseTimeMs'] = totalResponseTime + _responseTimeMs;

            if (isCorrect) {
              int currentScore = participants[i]['score'] ?? 0;
              participants[i]['score'] = currentScore + 1;

              int correctAnswers = participants[i]['correctAnswers'] ?? 0;
              participants[i]['correctAnswers'] = correctAnswers + 1;

              participants[i]['avgResponseTimeMs'] = participants[i]['correctAnswers'] > 0
                  ? participants[i]['totalResponseTimeMs'] / participants[i]['correctAnswers']
                  : 0;

              setState(() {
                _totalScore = currentScore + 1;
              });
            }
            break;
          }
        }

        if (!participantFound) {
          debugPrint('Participant ${widget.participantId} non trouvé, ajout en tant que nouveau');
          final newParticipant = {
            'participantId': widget.participantId,
            'username': 'Unknown',
            'icon': '',
            'score': isCorrect ? 1 : 0,
            'totalResponseTimeMs': _responseTimeMs,
            'correctAnswers': isCorrect ? 1 : 0,
            'avgResponseTimeMs': isCorrect ? _responseTimeMs : 0,
            'rank': 0,
            'joinedAt': Timestamp.now(),
          };
          participants.add(newParticipant);

          if (isCorrect) {
            setState(() {
              _totalScore = 1;
            });
          }
        }

        transaction.update(sessionRef, {
          'participants': participants,
        });
      });

      _checkedQuestions.add(widget.currentQuestionIndex);
      debugPrint('Question ${widget.currentQuestionIndex} marquée comme vérifiée');

      await _updateParticipantsRanking();

      if (widget.currentQuestionIndex >= _totalQuestions - 1) {
        _showResultsNotification();
      }
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour du score : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour du score : $e')),
      );
    }
  }

  Future<void> _updateParticipantsRanking() async {
    try {
      await _firestore.runTransaction((transaction) async {
        final sessionRef = _firestore.collection('sessions').doc(widget.sessionId);
        final sessionDoc = await transaction.get(sessionRef);

        if (!sessionDoc.exists) {
          debugPrint('Session non trouvée pour le classement : ${widget.sessionId}');
          return;
        }

        final sessionData = sessionDoc.data() as Map<String, dynamic>;
        final List<dynamic> participants = List.from(sessionData['participants'] ?? []);

        List<Map<String, dynamic>> participantsList =
            participants.map((p) => Map<String, dynamic>.from(p)).toList();

        participantsList.sort((a, b) {
          int scoreComparison = (b['score'] ?? 0).compareTo(a['score'] ?? 0);
          if (scoreComparison != 0) return scoreComparison;

          double aTime = a['avgResponseTimeMs'] ?? 0.0;
          double bTime = b['avgResponseTimeMs'] ?? 0.0;
          return aTime.compareTo(bTime);
        });

        for (int i = 0; i < participantsList.length; i++) {
          participantsList[i]['rank'] = i + 1;
          if (participantsList[i]['participantId'] == widget.participantId) {
            setState(() {
              _rank = i + 1;
            });
          }
        }

        transaction.update(sessionRef, {
          'participants': participantsList,
        });
      });
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour du classement : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour du classement : $e')),
      );
    }
  }

  void _showResultsNotification() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fin du quiz! Redirection vers les résultats...'),
        duration: Duration(seconds: 2),
      ),
    );
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _navigateToResults();
      }
    });
  }

  void _navigateToResults() async {
    if (!mounted) return;

    try {
      final sessionDoc = await _firestore.collection('sessions').doc(widget.sessionId).get();
      if (sessionDoc.exists) {
        final sessionData = sessionDoc.data() as Map<String, dynamic>;
        final List<dynamic> participants = sessionData['participants'] ?? [];
        int finalScore = _totalScore;

        for (var participant in participants) {
          if (participant['participantId'] == widget.participantId) {
            finalScore = participant['score'] ?? 0;
            break;
          }
        }

        debugPrint('Score final pour ${widget.participantId} : $finalScore');

        context.pushNamed(
          'results',
          extra: {
            'session_id': widget.sessionId,
            'participant_id': widget.participantId,
            'quiz_id': widget.quizId,
            'total_score': finalScore,
          },
        ).then((_) {
          if (mounted) {
            context.pushReplacementNamed(
              'results',
              extra: {
                'session_id': widget.sessionId,
                'participant_id': widget.participantId,
                'quiz_id': widget.quizId,
                'total_score': finalScore,
              },
            );
          }
        });
      } else {
        _showErrorAndGoBack('Session non trouvée');
      }
    } catch (e) {
      debugPrint('Erreur lors de la navigation vers les résultats : $e');
      _showErrorAndGoBack('Erreur : $e');
    }
  }

  void _showErrorAndGoBack(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // Fond dégradé violet comme dans l'image
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4B0082), // Indigo foncé
              Color(0xFF800080), // Violet
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _currentQuestion == null
                  ? const Center(child: Text('Question non disponible', style: TextStyle(color: Colors.white)))
                  : _buildQuestionContent(),
        ),
      ),
    );
  }

  Widget _buildQuestionContent() {
    final String questionText = _currentQuestion?['text'] ?? 'Aucun texte de question';
    final List<dynamic> answersData = _currentQuestion?['answers'] ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En-tête avec score et indices visuels
        _buildHeader(),
        
        // Espace pour le texte de la question
        Expanded(
          flex: 2,
          child: Center(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(16),
              child: Text(
                questionText,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        
        // Indicateur de progression (timer)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: 1.0 - _animationController.value,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _animationController.value > 0.25
                      ? Colors.green
                      : Colors.red,
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              );
            },
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Cartes de réponses sur une même ligne
        Expanded(
          flex: 4,
          child: _buildAnswerGrid(answersData),
        ),
        
        // Feedback (en mode résultats)
        if (_questionState == 'QuestionState.results')
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFeedbackPanel(),
          ),
      ],
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Score avec icône de pièce
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber,
                ),
                child: const Icon(Icons.monetization_on, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                '$_totalScore',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          
          // Numéro de question
          Text(
            'Question ${widget.currentQuestionIndex + 1}/$_totalQuestions',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // Indicateur du classement
          if (_rank > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _getRankColor(),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(Icons.leaderboard, size: 16, color: Colors.black87),
                  const SizedBox(width: 4),
                  Text(
                    '#$_rank',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  // MÉTHODE AMÉLIORÉE - Pour des cartes sur une même ligne
  Widget _buildAnswerGrid(List<dynamic> answers) {
    // Pour obtenir des cartes sur une même ligne comme dans l'image de référence
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Row(
        children: List.generate(
          answers.length,
          (index) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _buildAnswerCard(answers[index], index),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAnswerCard(dynamic answerData, int index) {
    final Map<String, dynamic> answer = answerData as Map<String, dynamic>;
    final String answerId = answer['answerId'] ?? '';
    final String answerText = answer['text'] ?? '';
    
    // Couleurs similaires à l'image de référence
    final List<Color> cardColors = [
      const Color(0xFF2196F3), // Bleu
      const Color(0xFF00BCD4), // Cyan/Teal
      const Color(0xFFFFB300), // Jaune orangé
      const Color(0xFFE91E63), // Rose/Rouge
    ];
    
    final Color cardColor = index < cardColors.length
        ? cardColors[index]
        : Colors.blueGrey;
    
    final bool isSelected = _selectedAnswerId == answerId;
    final bool isDisabled = _questionState != 'QuestionState.answering' || _hasSubmittedAnswer;
    final String correctAnswerId = _currentQuestion?['correctAnswerId'] ?? '';
    final bool isCorrectAnswer = answerId == correctAnswerId;
    
    return GestureDetector(
      onTap: isDisabled ? null : () => _submitAnswer(answerId),
      child: AspectRatio(
        aspectRatio: 1, // Carré parfait comme dans l'image
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isSelected ? cardColor.withOpacity(0.8) : cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _questionState == 'QuestionState.results' && isCorrectAnswer
                  ? Colors.white
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Stack(
            children: [
              // Indicateur de vérifié/sélectionné en haut à droite
              if (_questionState == 'QuestionState.results')
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    isCorrectAnswer ? Icons.check_circle : 
                    (isSelected && !isCorrectAnswer ? Icons.cancel : null),
                    color: isCorrectAnswer ? Colors.white : Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                ),
              
              // Texte de la réponse - Centré
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Texte principal (pays/ville/réponse)
                    Text(
                      answerText,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFeedbackPanel() {
    if (!_hasSubmittedAnswer) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange),
        ),
        child: const Center(
          child: Text(
            'Temps écoulé !',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      );
    }
    
    final bool isCorrect = _isCorrect;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect 
            ? Colors.green.withOpacity(0.3) 
            : Colors.red.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: isCorrect ? Colors.green : Colors.red,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            isCorrect ? 'Correct ! +$_pointsEarned point' : 'Incorrect !',
            style: TextStyle(
              color: isCorrect ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            'Temps de réponse: ${(_responseTimeMs / 1000).toStringAsFixed(2)}s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getRankColor() {
    if (_rank == 1) return Colors.amber;
    if (_rank == 2) return Colors.blueGrey.shade300;
    if (_rank == 3) return Colors.orange.shade300;
    return Colors.grey.shade300;
  }
}