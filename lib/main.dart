import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quiz/firebase_options.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz/screens/admin/authentification/login_page.dart';
import 'package:quiz/screens/admin/authentification/reset_password_page.dart';
import 'package:quiz/screens/admin/authentification/signup_page.dart';
import 'package:quiz/screens/admin/list_quiz.dart';
import 'package:quiz/screens/participant/QuestionScreen.dart';
import 'package:quiz/screens/participant/ResultQuiz.dart';
import 'package:quiz/screens/participant/joinquiz.dart';
import 'package:quiz/screens/participant/waiting_screen.dart';
import 'dart:async';


import 'package:quiz/splash_screen.dart'; // Import de la nouvelle page d'accueil

// GoRouter configuration with auth redirection
final GoRouter _router = GoRouter(
  initialLocation: '/', // Modification pour commencer par l'écran de démarrage
  redirect: (context, state) {
    // Check if the user is logged in
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final bool isGoingToLogin = state.matchedLocation == '/login';
    final bool isGoingToSignup = state.matchedLocation == '/signup';
    final bool isGoingToResetPassword = state.matchedLocation == '/reset-password';
    final bool isGoingToJoin = state.matchedLocation == '/join';
    final bool isGoingToQuizList = state.matchedLocation == '/list-quiz';
    final bool isGoingToSplash = state.matchedLocation == '/';
    
    // Si l'utilisateur n'est pas connecté et veut accéder à la liste des quiz, rediriger vers login
    if (!isLoggedIn && isGoingToQuizList) {
      return '/login';
    }
    
    // Si connecté et allant vers login/signup/reset-password, rediriger vers liste des quiz
    if (isLoggedIn && (isGoingToLogin || isGoingToSignup || isGoingToResetPassword)) {
      return '/list-quiz';
    }
    
    // Les autres routes sont accessibles sans authentification (comme / et /join)
    return null;
  },
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Erreur')),
    body: Center(child: Text('Erreur de navigation: ${state.error}')),
  ),
  routes: [
    // Nouvelle route d'accueil pour la splash screen
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    
    // Auth routes
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpPage(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordPage(),
    ),
    
    // Route pour l'écran principal (liste des quiz)
    GoRoute(
      path: '/list-quiz',
      builder: (context, state) {
        debugPrint('Navigating to /list-quiz (ListQuizScreen)');
        return const ListQuizScreen();
      },
    ),

    // Route pour rejoindre un quiz
    GoRoute(
      path: '/join',
      builder: (context, state) => const JoinQuizScreen(),
    ),

    // Route pour l'écran d'attente après avoir rejoint un quiz
    GoRoute(
      name: 'waiting',
      path: '/waiting',
      builder: (context, state) {
        final Map<String, dynamic> extra = state.extra as Map<String, dynamic>;
        return WaitingScreen(
          sessionId: extra['session_id'] as String,
          participantId: extra['participant_id'] as String,
          quizId: extra['quiz_id'] as String,
        );
      },
    ),

    // Route pour l'écran de question
    GoRoute(
      name: 'question',
      path: '/question',
      builder: (context, state) {
        final Map<String, dynamic> extra = state.extra as Map<String, dynamic>;
        return QuestionScreen(
          sessionId: extra['session_id'] as String,
          participantId: extra['participant_id'] as String,
          quizId: extra['quiz_id'] as String,
          currentQuestionIndex: extra['current_question_index'] as int,
        );
      },
    ),

    // Route pour l'écran de résultats
    GoRoute(
      name: 'results',
      path: '/results',
      builder: (context, state) {
        final Map<String, dynamic> extra = state.extra as Map<String, dynamic>;
        return ResultsScreen(
          sessionId: extra['session_id'] as String,
          participantId: extra['participant_id'] as String,
          quizId: extra['quiz_id'] as String,
          totalScore: extra['total_score'] as int,
        );
      },
    ),
  ],
);

// Custom RefreshListenable for GoRouter to listen to Firebase Auth changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Définir les couleurs principales basées sur le design Quizizz
    final primaryColor = Color(0xFF46178F); // Violet foncé
    final accentColor = Color(0xFFFF3355);  // Rouge corail

    return MaterialApp.router(
      title: 'Quiz App',
      theme: ThemeData(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: accentColor,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: primaryColor,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
          ),
        ),
        fontFamily: 'Montserrat', // Police moderne similaire à celle de Quizizz
      ),
      routerConfig: _router,
    );
  }
}