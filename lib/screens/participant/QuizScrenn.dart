import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';

class QuizScreen extends StatefulWidget {
  final String sessionId;
  final String participantId;
  final String username;

  const QuizScreen({
    Key? key,
    required this.sessionId,
    required this.participantId,
    required this.username,
  }) : super(key: key);

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _currentState = 'prepare';
  Timer? _timer;
  int _countdown = 3;
  Map<String, dynamic>? _currentQuestion;
  String? _selectedAnswer;
  bool _answerSubmitted = false;
  int _questionNumber = 0;

  // Couleurs pour les options (comme dans l'image)
  final List<Color> _optionColors = [
    const Color(0xFF00A3A3), // Turquoise
    const Color(0xFFFF9E1F), // Orange
    const Color(0xFFFF4D6A), // Rose
    const Color(0xFF6A5AE0), // Violet
  ];

  @override
  void initState() {
    super.initState();
    _startPreparePhase();
  }

  void _startPreparePhase() {
    setState(() {
      _currentState = 'prepare';
      _countdown = 3;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
      });
      if (_countdown minorequal 0) {
        timer.cancel();
        setState(() {
          _currentState = 'question';
        });
      }
    });
  }

  Future<void> _submitAnswer(String answerId) async {
    if (_answerSubmitted) return;

    setState(() {
      _answerSubmitted = true;
      _selectedAnswer = answerId;
    });

    try {
      // Récupérer la question active
      DocumentSnapshot sessionDoc = await _firestore.collection('sessions').doc(widget.sessionId).get();
      if (!sessionDoc.exists) {
        throw Exception("Session introuvable");
      }

      String activeQuestionId = sessionDoc['activeQuestionId'];
      DocumentSnapshot quizDoc = await _firestore.collection('quizzes').doc(sessionDoc['quizId']).get();
      var questions = (quizDoc['questions'] as List<dynamic>);
      var question = questions.firstWhere((q) => q['id'] == activeQuestionId);

      // Vérifier si la réponse est correcte
      bool isCorrect = question['correctAnswerId'] == answerId;
      int score = isCorrect ? 10 : 0;

      // Utiliser une transaction pour mettre à jour le score et enregistrer la réponse
      await _firestore.runTransaction((transaction) async {
        // Récupérer à nouveau le document de session dans la transaction
        DocumentReference sessionRef = _firestore.collection('sessions').doc(widget.sessionId);
        DocumentSnapshot sessionSnapshot = await transaction.get(sessionRef);

        if (!sessionSnapshot.exists) {
          throw Exception("Session introuvable dans la transaction");
        }

        var sessionData = sessionSnapshot.data() as Map<String, dynamic>;
        var participants = (sessionData['participants'] as List<dynamic>).map((p) => Map<String, dynamic>.from(p)).toList();

        // Trouver le participant
        var participantIndex = participants.indexWhere((p) => p['participantId'] == widget.participantId);
        if (participantIndex == -1) {
          throw Exception("Participant introuvable");
        }

        // Initialiser le score si nécessaire
        participants[participantIndex]['score'] ??= 0;
        participants[participantIndex]['score'] += score;

        // Enregistrer la réponse
        String responseId = const Uuid().v4();
        var response = {
          'responseId': responseId,
          'participantId': widget.participantId,
          'questionId': activeQuestionId,
          'answerId': answerId,
          'isCorrect': isCorrect,
          'score': score,
        };

        // Mettre à jour le document
        transaction.update(sessionRef, {
          'participants': participants,
          'responses': FieldValue.arrayUnion([response]),
        });
      });

      // Afficher le résultat
      setState(() {
        _currentState = 'result';
        _currentQuestion = question;
      });

      // Attendre avant de passer à la prochaine question
      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          _answerSubmitted = false;
          _selectedAnswer = null;
          _questionNumber++;
          _startPreparePhase();
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
      setState(() {
        _answerSubmitted = false;
        _selectedAnswer = null;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A125E), Color(0xFF220A46)], // Dégradé violet foncé comme dans l'image
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('sessions').doc(widget.sessionId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text('Session terminée ou introuvable', style: TextStyle(color: Colors.white)));
              }

              var sessionData = snapshot.data!.data() as Map<String, dynamic>;
              String? activeQuestionId = sessionData['activeQuestionId'];

              if (_currentState == 'prepare') {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Préparez-vous !',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Center(
                          child: Text(
                            '$_countdown',
                            style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (_currentState == 'question' && activeQuestionId != null) {
                return FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('quizzes').doc(sessionData['quizId']).get(),
                  builder: (context, quizSnapshot) {
                    if (!quizSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }

                    var quizData = quizSnapshot.data!.data() as Map<String, dynamic>;
                    var questions = quizData['questions'] as List<dynamic>;
                    var question = questions.firstWhere((q) => q['id'] == activeQuestionId);

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Q${_questionNumber + 1}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              question['text'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Expanded(
                            child: GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: (question['options'] as List<dynamic>).length,
                              itemBuilder: (context, index) {
                                final option = (question['options'] as List<dynamic>)[index];
                                final isSelected = _selectedAnswer == option['id'];

                                return GestureDetector(
                                  onTap: _answerSubmitted
                                      ? null
                                      : () {
                                          setState(() {
                                            _selectedAnswer = option['id'];
                                          });
                                          _submitAnswer(option['id']);
                                        },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _optionColors[index % _optionColors.length],
                                      borderRadius: BorderRadius.circular(15),
                                      border: isSelected
                                          ? Border.all(color: Colors.white, width: 3)
                                          : null,
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              option['text'],
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Positioned(
                                          top: 10,
                                          left: 10,
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.3),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          Positioned(
                                            bottom: 10,
                                            right: 10,
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                color: Colors.blue,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }

              if (_currentState == 'result' && _currentQuestion != null) {
                bool isCorrect = _currentQuestion!['correctAnswerId'] == _selectedAnswer;
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: isCorrect ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCorrect ? Icons.check : Icons.close,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        isCorrect ? 'Bonne réponse !' : 'Mauvaise réponse.',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Question: ${_currentQuestion!['text']}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, color: Colors.white),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Réponse correcte: ${_currentQuestion!['options'].firstWhere((o) => o['id'] == _currentQuestion!['correctAnswerId'])['text']}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return const Center(
                child: Text(
                  'En attente de la prochaine question...',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}