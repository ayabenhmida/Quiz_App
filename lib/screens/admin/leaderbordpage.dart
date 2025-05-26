import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LeaderboardPage extends StatelessWidget {
  final String sessionId;

  const LeaderboardPage({
    Key? key,
    required this.sessionId,
  }) : super(key: key);

  // Récupérer l'ID du participant actuel
  String _getCurrentParticipantId() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
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
      Color(0xFF47A2FF), 
      Color(0xFFFFA41B), 
      Color(0xFF4CD964), 
      Color(0xFFFF6B8A), 
      Color(0xFF9B72FF), 
      Color(0xFF1A7D5A), 
      Color(0xFF607D8B), 
      Color(0xFFFF5252),
      Color(0xFFFFD600), 
      Color(0xFF8D6E63), 
    ];
    return colors[(rank - 1) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final currentParticipantId = _getCurrentParticipantId();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A2151), // Bleu foncé
              Color(0xFF0D1333), // Bleu très foncé
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Leaderboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: 48), // Pour équilibrer avec le bouton retour
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('sessions')
                      .doc(sessionId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Une erreur est survenue',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Center(
                        child: Text(
                          'Aucune donnée disponible',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    // Extraction des données
                    var sessionData = snapshot.data!.data() as Map<String, dynamic>;
                    List<dynamic> participants = sessionData['participants'] ?? [];

                    // Trier les participants par score (décroissant)
                    participants.sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0));

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Text(
                                '${participants.length} joueurs',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18,
                                ),
                              ),
                              Spacer(),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: participants.length,
                            itemBuilder: (context, index) {
                              var participant = participants[index];
                              int rank = index + 1;
                              bool isCurrentUser = participant['participantId'] == currentParticipantId;
                              String name = _getParticipantName(participant, isCurrentUser);
                              int score = participant['score'] ?? 0;
                              String avatar = participant['icon'] ?? '🔥';
                              
                              // Score précédent pour l'animation
                              String scoreChange = '+${score}';

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
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // Barre principale avec avatar et nom
                                    Expanded(
                                      child: Container(
                                        height: 54,
                                        decoration: BoxDecoration(
                                          color: _getRankColor(rank),
                                          borderRadius: BorderRadius.circular(27),
                                        ),
                                        child: Row(
                                          children: [
                                            // Avatar
                                            Container(
                                              width: 46,
                                              height: 46,
                                              margin: EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                avatar,
                                                style: TextStyle(fontSize: 24),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            // Nom
                                            Text(
                                              name,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    // Score et gain
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${score}p',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          scoreChange,
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 14,
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
                        // Indicateur pour montrer qu'il y a plus de contenu
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white54,
                            size: 36,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}