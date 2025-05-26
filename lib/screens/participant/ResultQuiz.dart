import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class ResultsScreen extends StatefulWidget {
  final String sessionId;
  final String participantId;
  final String quizId;
  final int totalScore;

  const ResultsScreen({
    Key? key,
    required this.sessionId,
    required this.participantId,
    required this.quizId,
    required this.totalScore,
  }) : super(key: key);

  @override
  _ResultsScreenState createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final primaryColor = const Color(0xFF46178F);
  final secondaryColor = const Color(0xFF00C2FF);
  bool _isLoading = true;
  String _quizTitle = '';
  List<Map<String, dynamic>> _leaderboard = [];
  int _userRank = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Initialiser les animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Lancer l'animation après un délai
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _animationController.forward();
      }
    });

    _loadResults();
  }

  Future<void> _loadResults() async {
    try {
      // Récupérer le titre du quiz
      final quizDoc = await _firestore.collection('quizzes').doc(widget.quizId).get();
      if (quizDoc.exists) {
        setState(() {
          _quizTitle = quizDoc.data()?['title'] ?? 'Quiz';
        });
      }

      // Récupérer les données de la session pour le classement
      final sessionDoc = await _firestore.collection('sessions').doc(widget.sessionId).get();
      if (sessionDoc.exists) {
        final List<dynamic> participants = sessionDoc.data()?['participants'] ?? [];

        // Convertir en liste de maps et trier par score (décroissant)
        List<Map<String, dynamic>> leaderboard = participants
            .map<Map<String, dynamic>>((p) => {
                  'participantId': p['participantId'],
                  'username': p['username'],
                  'avatar': p['avatar'] ?? 'assets/avatar_1.png',
                  'score': p['score'] ?? 0,
                })
            .toList();


        // Trier par score (décroissant)
        leaderboard.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

        // Trouver le rang de l'utilisateur
        int userRank = leaderboard.indexWhere((p) => p['participantId'] == widget.participantId) + 1;

        setState(() {
          _leaderboard = leaderboard;
          _userRank = userRank;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading results: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des résultats : $e')),
        );
      }
    }
  }

  void _goHome() {
    context.go('/'); // Retour à l'écran d'accueil
  }

  String _getParticipantName(Map<String, dynamic> participant, bool isCurrentUser) {
    if (isCurrentUser) {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.displayName != null && user!.displayName!.isNotEmpty) {
        return user.displayName!;
      }
    }
    return participant['username'] ?? 'Anonyme';
  }

  Color _getRankColor(int rank) {
    const colors = [
      Color(0xFF47A2FF), // 1st
      Color(0xFFFFA41B), // 2nd
      Color(0xFF4CD964), // 3rd
      Color(0xFFFF6B8A), // 4th
      Color(0xFF9B72FF), // 5th
      Color(0xFF1A7D5A), // 6th
      Color(0xFF607D8B), // 7th
      Color(0xFFFF5252), // 8th
      Color(0xFFFFD600), // 9th
      Color(0xFF8D6E63), // 10th
    ];
    return colors[(rank - 1) % colors.length];
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentParticipantId = widget.participantId;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor, const Color(0xFF2E1065)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: child,
                ),
              );
            },
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Column(
                    children: [
                      // En-tête
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                              onPressed: _goHome,
                            ),
                            Expanded(
                              child: Text(
                                'Résultats - $_quizTitle',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 15,
                                      color: secondaryColor.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      // Carte de résultat de l'utilisateur
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.emoji_events,
                                size: 48,
                                color: Colors.amber,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Quiz Terminé !',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Votre Score : ${widget.totalScore}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Votre Rang : $_userRank sur ${_leaderboard.length}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            // Nombre de joueurs
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                children: [
                                  Text(
                                    '${_leaderboard.length} joueurs',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 18,
                                    ),
                                  ),
                                  const Spacer(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Liste du classement
                            Expanded(
                              child: _leaderboard.isEmpty
                                  ? Center(
                                      child: Text(
                                        'Aucun participant',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 16,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      itemCount: _leaderboard.length,
                                      itemBuilder: (context, index) {
                                        var participant = _leaderboard[index];
                                        int rank = index + 1;
                                        bool isCurrentUser = participant['participantId'] == currentParticipantId;
                                        String name = _getParticipantName(participant, isCurrentUser);
                                        int score = participant['score'] ?? 0;
                                        String avatar = participant['avatar'] ?? 'assets/avatar_1.png';

                                        // Déterminer la largeur de la bande
                                        double bandWidth;
                                        if (rank == 1) {
                                          bandWidth = MediaQuery.of(context).size.width * 0.9;
                                        } else if (rank == 2) {
                                          int rank3Score = (index + 1 < _leaderboard.length)
                                              ? _leaderboard[index + 1]['score'] ?? 0
                                              : score;
                                          bandWidth = (score != rank3Score)
                                              ? MediaQuery.of(context).size.width * 0.75
                                              : MediaQuery.of(context).size.width * 0.6;
                                        } else {
                                          bandWidth = MediaQuery.of(context).size.width * 0.6;
                                        }

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            children: [
                                              // Rang
                                              Container(
                                                width: 40,
                                                height: 40,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  '$rank',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Bande principale
                                              Container(
                                                width: bandWidth,
                                                height: 54,
                                                decoration: BoxDecoration(
                                                  color: _getRankColor(rank),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: isCurrentUser
                                                      ? Border.all(color: Colors.white, width: 2)
                                                      : null,
                                                ),
                                                child: Row(
                                                  children: [
                                                    // Avatar
                                                    Container(
                                                      width: 46,
                                                      height: 46,
                                                      margin: const EdgeInsets.all(4),
                                                      decoration: const BoxDecoration(
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: CircleAvatar(
                                                        backgroundImage: avatar.startsWith('assets/')
                                                            ? AssetImage(avatar)
                                                            : null,
                                                        backgroundColor: Colors.white,
                                                        child: avatar.startsWith('assets/')
                                                            ? null
                                                            : Text(
                                                                avatar,
                                                                style: const TextStyle(fontSize: 24),
                                                              ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    // Nom
                                                    Text(
                                                      name,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 18,
                                                        fontWeight: isCurrentUser
                                                            ? FontWeight.bold
                                                            : FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              // Score
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${score}p',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            // Flèche vers le bas
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white.withOpacity(0.54),
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bouton retour
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        child: ElevatedButton.icon(
                          onPressed: _goHome,
                          icon: const Icon(Icons.home),
                          label: const Text('Retour à l\'accueil'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
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