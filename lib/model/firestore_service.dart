import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Rejoint une session de quiz avec un code, un nom d'utilisateur et une icône.
  /// Retourne les informations de la session ou null en cas d'erreur.
  Future<Map<String, dynamic>?> joinQuiz(
    String code,
    String username,
    String avatar,
  ) async {
    try {
      // Rechercher une session active avec le code
      final QuerySnapshot querySnapshot = await _firestore
          .collection('sessions')
          .where('sessionCode', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .where('acceptingNewParticipants', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('Aucune session trouvée avec le code $code');
        return null; // Aucune session valide
      }

      final sessionDoc = querySnapshot.docs.first;
      final sessionId = sessionDoc.id;
      final quizId = sessionDoc.get('quizId');
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final List<dynamic> participants = sessionData['participants'] ?? [];

      // Générer un ID de participant unique
      final participantId = const Uuid().v4();

      // Vérifier si un participant avec le même nom d'utilisateur existe déjà
      bool participantExists = participants.any(
        (p) => p['username'] == username,
      );

      if (participantExists) {
        print('Un participant avec le nom $username existe déjà dans la session $sessionId');
        return null; // Empêche les doublons basés sur le nom d'utilisateur
      }

      // Ajouter le participant avec tous les champs nécessaires
     final newParticipant = {
  'participantId': participantId,
  'username': username,
  'avatar': avatar,
  'score': 0,
  'totalResponseTimeMs': 0,
  'correctAnswers': 0,
  'avgResponseTimeMs': 0,
  'rank': 0,
  'joinedAt': Timestamp.now(),
};


      // Utiliser une transaction pour ajouter le participant
      await _firestore.runTransaction((transaction) async {
        final sessionRef = _firestore.collection('sessions').doc(sessionId);
        final updatedSessionDoc = await transaction.get(sessionRef);

        if (!updatedSessionDoc.exists) {
          throw Exception('Session non trouvée lors de la transaction');
        }

        // Ajouter le participant à la liste
        transaction.update(sessionRef, {
          'participants': FieldValue.arrayUnion([newParticipant]),
        });
      });

      print('Participant $participantId ajouté à la session $sessionId');
      return {
        'session_id': sessionId,
        'participant_id': participantId,
        'quiz_id': quizId,
      };
    } catch (e) {
      print('Erreur lors de la tentative de rejoindre le quiz : $e');
      return null;
    }
  }
}