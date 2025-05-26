import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz/model/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class JoinQuizScreen extends StatefulWidget {
  const JoinQuizScreen({Key? key}) : super(key: key);

  @override
  _JoinQuizScreenState createState() => _JoinQuizScreenState();
}

class _JoinQuizScreenState extends State<JoinQuizScreen> with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedAvatar = 'assets/avatars/avatar1.png';
  bool _isLoading = false;
  String? _errorMessage;

 
  final primaryColor = const Color(0xFF46178F);
  final accentColor = const Color(0xFFFF3355);
  final secondaryColor = const Color(0xFF00C2FF);

  final List<String> _avatars = [
    'assets/avatar_blonde.png',
    'assets/avatar_curly_hair.png',
    'assets/avatar_red_hair.png',  
    'assets/avatar_1.png', 
    'assets/avatar_2.png', 
  ];
  int _currentAvatarIndex = 0;
  Timer? _avatarTimer;
  bool _isAvatarSelected = false;

 
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint('JoinQuizScreen initialized');
    
   
    _startAvatarCycling();
    
   
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
      _animationController.forward();
    });
  }

  void _startAvatarCycling() {
    // Roulement d'avatar plus rapide pour une meilleure expérience utilisateur
    _avatarTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!_isAvatarSelected) {
        setState(() {
          _currentAvatarIndex = (_currentAvatarIndex + 1) % _avatars.length;
          _selectedAvatar = _avatars[_currentAvatarIndex];
        });
      }
    });
  }

  void _stopAvatarCycling() {
    _avatarTimer?.cancel();
    setState(() {
      _isAvatarSelected = true;
    });
  }

 
  InputDecoration _inputDecoration(String hint, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: secondaryColor.withOpacity(0.8)),
      ),
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        size: 20,
        color: Colors.white.withOpacity(0.7),
      ),
      suffixIcon: suffixIcon,
      counterText: '',
    );
  }

  // Widget pour centrer les champs texte
  Widget _buildCenteredTextField(Widget child) {
    return Center(
      child: SizedBox(
        width: 500,
        child: child,
      ),
    );
  }

  void _joinQuiz() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final code = _codeController.text.trim();
      final username = _usernameController.text.trim();
      final effectiveUsername = username.isEmpty ? 'Guest_${DateTime.now().millisecondsSinceEpoch}' : username;

      final result = await _firestoreService.joinQuiz(
        code,
        effectiveUsername,
        _selectedAvatar,
      );

      if (result != null && result.containsKey('session_id') && result.containsKey('participant_id')) {
        debugPrint('Successfully joined quiz: $result');
        
        if (!mounted) return;
        
        final router = GoRouter.of(context);
        router.pushNamed(
          'waiting',
          extra: {
            'session_id': result['session_id'],
            'participant_id': result['participant_id'],
            'quiz_id': result['quiz_id'],
          },
        );
      } else {
        setState(() {
          _errorMessage = 'Code de session invalide ou session introuvable';
          _isLoading = false;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('FirebaseException in joinQuiz: ${e.message}');
      setState(() {
        _errorMessage = 'Échec de la connexion au quiz: ${e.message ?? 'Erreur inconnue'}';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Unexpected error in joinQuiz: $e');
      setState(() {
        _errorMessage = 'Une erreur inattendue s\'est produite: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          // Gradient mis à jour pour correspondre à LoginPage
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor, const Color(0xFF2E1065)],
          ),
        ),
        child: SafeArea(
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Center(
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Titre avec le style de LoginPage
                              Text(
                                "QUIZLY",
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 4,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 15,
                                      color: secondaryColor.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "JOIN A QUIZ",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 40),
                              
                              // Logo Icon avec le style de LoginPage
                              GestureDetector(
                                onTap: () {
                                  _stopAvatarCycling();
                                  setState(() {
                                    _selectedAvatar = _avatars[_currentAvatarIndex];
                                  });
                                },
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accentColor.withOpacity(0.8),
                                        secondaryColor.withOpacity(0.8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: secondaryColor.withOpacity(0.4),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: _isAvatarSelected 
                                      ? Image.asset(_selectedAvatar, fit: BoxFit.cover)
                                      : Image.asset(_avatars[_currentAvatarIndex], fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              Text(
                                _isAvatarSelected ? 'Select Avatar!' : 'Tap to select an avatar',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _isAvatarSelected ? Colors.white : Colors.white.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 40),

                              // Message d'erreur
                              if (_errorMessage != null)
                                _buildCenteredTextField(
                                  Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.redAccent, 
                                      fontSize: 13,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 10,
                                          color: Colors.red.withOpacity(0.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              
                              const SizedBox(height: 20),
                              
                           
                              _buildCenteredTextField(
                                TextFormField(
                                  controller: _codeController,
                                  maxLength: 6,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                  style: const TextStyle(fontSize: 14, color: Colors.white),
                                  decoration: _inputDecoration('Code du quiz', Icons.confirmation_number_outlined),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer un code de session';
                                    }
                                    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                                      return 'Le code doit contenir exactement 6 chiffres';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                          
                              _buildCenteredTextField(
                                TextFormField(
                                  controller: _usernameController,
                                  style: const TextStyle(fontSize: 14, color: Colors.white),
                                  decoration: _inputDecoration('Nom d\'utilisateur', Icons.person_outline),
                                  validator: (value) {
                                    // Optionnel puisque le nom d'utilisateur peut être vide (invité sera utilisé)
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 40),
                              
                             
                              Center(
                                child: SizedBox(
                                  width: 200,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _joinQuiz,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      minimumSize: const Size(200, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      elevation: 8,
                                      shadowColor: accentColor.withOpacity(0.5),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'REJOINDRE',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                    
                             
                              
                           
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _avatarTimer?.cancel();
    _codeController.dispose();
    _usernameController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}