import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class WaitingScreen extends StatefulWidget {
  final String sessionId;
  final String participantId;
  final String quizId;

  const WaitingScreen({
    Key? key,
    required this.sessionId,
    required this.participantId,
    required this.quizId,
  }) : super(key: key);

  @override
  _WaitingScreenState createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _quizTitle = 'Quiz';
  late Stream<DocumentSnapshot> _sessionStream;
  late Stream<List<Map<String, dynamic>>> _participantsStream;

  // Countdown animation state
  bool _showCountdown = false;
  int _countdownValue = 3;
  bool _showStartMessage = false;

  // Participants data
  List<Map<String, dynamic>> _participants = [];

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Animation for new participant joining
  int? _lastJoinedParticipantIndex;
  Timer? _resetLastJoinedTimer;

  @override
  void initState() {
    super.initState();
    _fetchQuizDetails();
    _setupSessionListener();
    _setupParticipantsListener();
    _fixFirestoreData();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    // Validate Firestore structure after a short delay
    Future.delayed(const Duration(milliseconds: 300), _validateFirestoreStructure);
  }

  Future<void> _fetchQuizDetails() async {
    try {
      final quizDoc = await _firestore.collection('quizzes').doc(widget.quizId).get();
      if (quizDoc.exists) {
        setState(() {
          _quizTitle = quizDoc.data()?['title'] ?? 'Quiz';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching quiz details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fixFirestoreData() async {
    final sessionRef = _firestore.collection('sessions').doc(widget.sessionId);
    final sessionDoc = await sessionRef.get();
    if (sessionDoc.exists) {
      final data = sessionDoc.data() as Map<String, dynamic>;
      List<dynamic> participants = data['participants'] ?? [];
      participants = participants.map((p) {
        if (p['avatar'] == null || p['avatar'].isEmpty) {
          p['avatar'] = 'avatar_1.png';
        }
        return p;
      }).toList();
      await sessionRef.update({'participants': participants});
    }
  }

  void _setupParticipantsListener() {
    _participantsStream = _firestore
        .collection('sessions')
        .doc(widget.sessionId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return [];

      final List<dynamic> participantData = data['participants'] ?? [];
      return participantData.cast<Map<String, dynamic>>();
    });

    _participantsStream.listen((participantsData) {
      if (mounted) {
        setState(() {
          int oldParticipantsCount = _participants.length;
          _participants = participantsData.map((p) {
            debugPrint('Raw participant avatar from Firestore: ${p['avatar']}');
            String avatarPath = p['avatar'] ?? 'avatar_1.png';
            if (avatarPath.startsWith('assets/')) {
              avatarPath = avatarPath.replaceFirst('assets/', '');
            }
            debugPrint('Normalized participant avatar: $avatarPath');
            return {
              'id': p['participantId'] ?? '',
              'name': p['username'] ?? 'Unknown',
              'avatar': avatarPath,
            };
          }).toList();

          if (_participants.length > oldParticipantsCount) {
            _lastJoinedParticipantIndex = _participants.length - 1;
            _animationController.forward(from: 0.0);

            _resetLastJoinedTimer?.cancel();
            _resetLastJoinedTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _lastJoinedParticipantIndex = null;
                });
              }
            });
          }
        });
      }
    });
  }

  Future<void> _validateFirestoreStructure() async {
    try {
      final sessionDoc = await _firestore.collection('sessions').doc(widget.sessionId).get();
      if (!sessionDoc.exists) {
        debugPrint('ERROR: Session does not exist!');
        _showErrorAndGoBack('Session not found');
        return;
      }

      final sessionData = sessionDoc.data() as Map<String, dynamic>?;
      if (sessionData == null) {
        debugPrint('ERROR: Session data is null');
        return;
      }

      List<dynamic> participants = sessionData['participants'] ?? [];
      if (!participants.any((p) => p['participantId'] == widget.participantId)) {
        debugPrint('Adding current participant to session: ${widget.participantId}');
        final newParticipant = {
          'participantId': widget.participantId,
          'username': 'Player ${participants.length + 1}',
          'avatar': 'avatar_1.png',
          'score': 0,
          'totalResponseTimeMs': 0,
          'correctAnswers': 0,
          'avgResponseTimeMs': 0,
          'rank': 0,
          'joinedAt': Timestamp.now(),
        };
        await _firestore.collection('sessions').doc(widget.sessionId).update({
          'participants': FieldValue.arrayUnion([newParticipant]),
        });
      }
    } catch (e) {
      debugPrint('Error validating Firestore structure: $e');
    }
  }

  void _setupSessionListener() {
    _sessionStream = _firestore
        .collection('sessions')
        .doc(widget.sessionId)
        .snapshots();

    _sessionStream.listen((DocumentSnapshot snapshot) {
      if (!snapshot.exists) {
        _showErrorAndGoBack('Session no longer exists');
        return;
      }

      final sessionData = snapshot.data() as Map<String, dynamic>?;
      if (sessionData == null) return;

      final bool acceptingParticipants = sessionData['acceptingNewParticipants'] ?? true;
      if (!acceptingParticipants) {
        if (!_showCountdown && mounted) {
          setState(() {
            _showCountdown = true;
          });
          _startCountdownAnimation();
        }

        Future.delayed(const Duration(seconds: 5), () {
          final String activeQuestionId = sessionData['activeQuestionId'] ?? '';
          if (activeQuestionId.isNotEmpty) {
            _navigateToQuestionScreen(sessionData);
          }
        });
      }

      final bool isActive = sessionData['isActive'] ?? true;
      if (!isActive) {
        _showErrorAndGoBack('This quiz session has ended');
      }
    });
  }

  void _startCountdownAnimation() {
    _animationController.forward(from: 0.0);

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownValue > 1) {
        setState(() {
          _countdownValue--;
          _animationController.forward(from: 0.0);
        });
      } else if (_countdownValue == 1) {
        setState(() {
          _countdownValue = 0;
          _showStartMessage = true;
          _animationController.forward(from: 0.0);
        });
        timer.cancel();
      }
    });
  }

  void _navigateToQuestionScreen(Map<String, dynamic> sessionData) {
    if (!mounted) return;

    context.pushNamed(
      'question',
      extra: {
        'session_id': widget.sessionId,
        'participant_id': widget.participantId,
        'quiz_id': widget.quizId,
        'current_question_index': sessionData['currentQuestionIndex'] ?? 0,
      },
    );
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

  Widget _buildCountdownAnimation() {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.deepPurple,
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$_countdownValue',
              style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartMessage() {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B5C),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Text(
            "C'est parti !",
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantsList() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Text(
            'QUIZLY',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _quizTitle,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: _participants.length),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade300,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.people,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$value participants',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _participants.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 60,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucun participant pour le moment',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Les participants apparaîtront ici en rejoignant',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 100,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                    ),
                    itemCount: _participants.length,
                    itemBuilder: (context, index) {
                      final participant = _participants[index];
                      final bool isCurrentUser = participant['id'] == widget.participantId;
                      final bool isNewlyJoined = index == _lastJoinedParticipantIndex;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Hero(
                                tag: 'avatar_${participant['id']}',
                                child: ScaleTransition(
                                  scale: _scaleAnimation,
                                  child: CircleAvatar(
                                    backgroundImage: participant['avatar'] != null && participant['avatar'].isNotEmpty
                                        ? AssetImage('assets/${participant['avatar']}')
                                        : null,
                                    radius: 35,
                                    backgroundColor: Colors.deepPurple.shade200,
                                    child: participant['avatar'] == null || participant['avatar'].isEmpty
                                        ? Text(
                                            participant['name']?.isNotEmpty == true
                                                ? participant['name'][0].toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              if (isCurrentUser || isNewlyJoined)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isCurrentUser ? Colors.white : Colors.green,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              if (isNewlyJoined)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'New!',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            participant['name'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 2,
                                  offset: const Offset(1, 1),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isCurrentUser)
                            Container(
                              margin: const EdgeInsets.only(top: 5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Vous',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple.shade200),
                  ),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Text(
                    'En attente du démarrage par l\'hôte',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : _showCountdown
                ? _countdownValue > 0
                    ? _buildCountdownAnimation()
                    : _showStartMessage
                        ? _buildStartMessage()
                        : _buildParticipantsList()
                : _buildParticipantsList(),
      ),
    );
  }

  @override
  void dispose() {
    _resetLastJoinedTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }
}