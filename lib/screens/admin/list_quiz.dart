import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:quiz/screens/admin/create_quiz.dart';
import 'package:quiz/screens/admin/Edit_quiz.dart';
import 'package:quiz/screens/admin/quiz_session.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

class ListQuizScreen extends StatefulWidget {
  const ListQuizScreen({Key? key}) : super(key: key);

  @override
  _ListQuizScreenState createState() => _ListQuizScreenState();
}

class _ListQuizScreenState extends State<ListQuizScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Define design colors
  final primaryColor = const Color(0xFF46178F);
  final accentColor = const Color(0xFFFF3355);
  final secondaryColor = const Color(0xFF00C2FF);

  // Store hover states
  final Map<String, bool> _hoverStates = {};

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
             
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center, // Alignement vertical au centre
                  children: [
                    // Logo et titre alignés
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center, // Alignement vertical au centre
                      children: [
                    
                        Container(
                          width: 45,
                          height: 45,
                          child: ClipOval(
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      
                        Text(
                          "QUIZLY",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 3,
                            shadows: [
                              Shadow(
                                blurRadius: 15,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  
                    CircleAvatar(
                      backgroundColor: accentColor.withOpacity(0.3),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
             
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white.withOpacity(0.9),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Mes Quiz",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main content - GridView
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('quizzes').orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: secondaryColor,
                          strokeWidth: 3,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Erreur: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final quiz = snapshot.data!.docs[index];
                          final quizData = quiz.data() as Map<String, dynamic>;
                          final String quizId = quiz.id;
                          final String title = quizData['title'] ?? 'Sans titre';

                          return StatefulBuilder(
                            builder: (context, setHoverState) {
                              bool isHovered = _hoverStates[quizId] ?? false;
                              
                              return MouseRegion(
                                onEnter: (_) => setHoverState(() => _hoverStates[quizId] = true),
                                onExit: (_) => setHoverState(() => _hoverStates[quizId] = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  transform: Matrix4.identity()..scale(isHovered ? 1.02 : 1.0),
                                  child: Card(
                                    elevation: isHovered ? 8 : 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isHovered 
                                            ? Colors.white.withOpacity(0.5)
                                            : Colors.white.withOpacity(0.2),
                                        width: isHovered ? 1.5 : 0.8,
                                      ),
                                    ),
                                    color: Colors.white.withOpacity(0.05),
                                    child: Stack(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Center(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isHovered ? FontWeight.w800 : FontWeight.bold,
                                                color: Colors.white.withOpacity(isHovered ? 1.0 : 0.9),
                                              ),
                                              maxLines: 2,
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        if (isHovered)
                                          Positioned(
                                            right: 10,
                                            top: 0,
                                            bottom: 0,
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  _actionIconButton(
                                                    icon: Icons.play_arrow,
                                                    color: Colors.green,
                                                    tooltip: 'Run',
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => LaunchQuizPage(
                                                            quizId: quizId,
                                                            quizTitle: title,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(height: 12),
                                                  _actionIconButton(
                                                    icon: Icons.edit,
                                                    color: Colors.white,
                                                    tooltip: 'Edit',
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => EditQuizPage(quizId: quizId),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(height: 12),
                                                  _actionIconButton(
                                                    icon: Icons.delete,
                                                    color: accentColor,
                                                    tooltip: 'Delete',
                                                    onPressed: () {
                                                      _showDeleteConfirmation(context, quizId);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateQuizPage()),
          );
        },
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.add),
        label: const Text(
          'Create Quiz',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _actionIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String quizId) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.white.withOpacity(0.97),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      insetPadding: const EdgeInsets.all(20), 
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450), 
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete quiz ?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This action is irreversible.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      _firestore.collection('quizzes').doc(quizId).delete().then((_) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Quiz deleted'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      });
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
