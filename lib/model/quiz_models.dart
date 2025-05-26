import 'package:flutter/material.dart';

class Quiz {
  final String quizId;
  final String title;
  final String code;
  final List<Question> questions;

  Quiz({
    required this.quizId,
    required this.title,
    required this.code,
    required this.questions,
  });

  Map<String, dynamic> toMap() {
    return {
      'quizId': quizId,
      'title': title,
      'code': code,
      'questions': questions.map((q) => q.toMap()).toList(),
    };
  }

  factory Quiz.fromMap(Map<String, dynamic> map) {
    return Quiz(
      quizId: map['quizId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      code: map['code'] as String? ?? '',
      questions: (map['questions'] as List<dynamic>?)
              ?.map((q) => Question.fromMap(q as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Question {
  final String questionId;
  final String text;
  final List<Answer> answers;
  final String correctAnswerId;
  final int timeLimit;

  Question({
    required this.questionId,
    required this.text,
    required this.answers,
    required this.correctAnswerId,
    required this.timeLimit,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'text': text,
      'answers': answers.map((a) => a.toMap()).toList(),
      'correctAnswerId': correctAnswerId,
      'timeLimit': timeLimit,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      questionId: map['questionId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      answers: (map['answers'] as List<dynamic>?)
              ?.map((a) => Answer.fromMap(a as Map<String, dynamic>))
              .toList() ??
          [],
      correctAnswerId: map['correctAnswerId'] as String? ?? '',
      timeLimit: map['timeLimit'] as int? ?? 30,
    );
  }
}

class Answer {
  final String answerId;
  final String text;
  final bool isCorrect;

  Answer({
    required this.answerId,
    required this.text,
    required this.isCorrect,
  });

  Map<String, dynamic> toMap() {
    return {
      'answerId': answerId,
      'text': text,
      'isCorrect': isCorrect,
    };
  }

  factory Answer.fromMap(Map<String, dynamic> map) {
    return Answer(
      answerId: map['answerId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      isCorrect: map['isCorrect'] as bool? ?? false,
    );
  }
  
}

class QuizSession {
  final String sessionId;
  final String quizId;
  final String adminId;
  final String code;
  String activeQuestionId;
  String state;
  List<Participant> participants;
  List<QuizResponse> responses;
  List<LeaderboardEntry> leaderboard;
  String status;

  QuizSession({
    required this.sessionId,
    required this.quizId,
    required this.adminId,
    required this.code,
    this.activeQuestionId = '',
    this.state = 'waiting',
    this.participants = const [],
    this.responses = const [],
    this.leaderboard = const [],
    this.status = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'quizId': quizId,
      'adminId': adminId,
      'code': code,
      'activeQuestionId': activeQuestionId,
      'state': state,
      'participants': participants.map((p) => p.toMap()).toList(),
      'responses': responses.map((r) => r.toMap()).toList(),
      'leaderboard': leaderboard.map((l) => l.toMap()).toList(),
      'status': status,
    };
  }

  factory QuizSession.fromMap(Map<String, dynamic> map) {
    return QuizSession(
      sessionId: map['session_id'] as String? ?? '',
      quizId: map['quizId'] as String? ?? '',
      adminId: map['adminId'] as String? ?? '',
      code: map['code'] as String? ?? '',
      activeQuestionId: map['activeQuestionId'] as String? ?? '',
      state: map['state'] as String? ?? 'waiting',
      participants: (map['participants'] as List<dynamic>?)
              ?.map((p) => Participant.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      responses: (map['responses'] as List<dynamic>?)
              ?.map((r) => QuizResponse.fromMap(r as Map<String, dynamic>))
              .toList() ??
          [],
      leaderboard: (map['leaderboard'] as List<dynamic>?)
              ?.map((l) => LeaderboardEntry.fromMap(l as Map<String, dynamic>))
              .toList() ??
          [],
      status: map['status'] as String? ?? '',
    );
  }

  QuizSession copyWith({
    String? activeQuestionId,
    String? state,
    List<Participant>? participants,
    List<QuizResponse>? responses,
    List<LeaderboardEntry>? leaderboard,
    String? status,
  }) {
    return QuizSession(
      sessionId: sessionId,
      quizId: quizId,
      adminId: adminId,
      code: code,
      activeQuestionId: activeQuestionId ?? this.activeQuestionId,
      state: state ?? this.state,
      participants: participants ?? this.participants,
      responses: responses ?? this.responses,
      leaderboard: leaderboard ?? this.leaderboard,
      status: status ?? this.status,
    );
  }
}

class Participant {
  final String idParticipant;
  int totalScore;
  final String quizId;

  Participant({
    required this.idParticipant,
    this.totalScore = 0,
    required this.quizId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_participant': idParticipant,
      'totalScore': totalScore,
      'quizId': quizId,
    };
  }

  factory Participant.fromMap(Map<String, dynamic> map) {
    return Participant(
      idParticipant: map['id_participant'] as String? ?? '',
      totalScore: map['totalScore'] as int? ?? 0,
      quizId: map['quizId'] as String? ?? '',
    );
  }
}

class QuizResponse {
  final String idParticipant;
  final String questionId;
  final String answerId;
  final String isCorrect;
  final int score;
  final int timeUsed;
  final String idSession;

  QuizResponse({
    required this.idParticipant,
    required this.questionId,
    required this.answerId,
    required this.isCorrect,
    required this.score,
    required this.timeUsed,
    required this.idSession,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_participant': idParticipant,
      'question_id': questionId,
      'id_answer': answerId,
      'isCorrect': isCorrect,
      'score': score,
      'timeUsed': timeUsed,
      'id_session': idSession,
    };
  }

  factory QuizResponse.fromMap(Map<String, dynamic> map) {
    return QuizResponse(
      idParticipant: map['id_participant'] as String? ?? '',
      questionId: map['question_id'] as String? ?? '',
      answerId: map['id_answer'] as String? ?? '',
      isCorrect: map['isCorrect'] as String? ?? '',
      score: map['score'] as int? ?? 0,
      timeUsed: map['timeUsed'] as int? ?? 0,
      idSession: map['id_session'] as String? ?? '',
    );
  }
}

class LeaderboardEntry {
  final String idParticipant;
  final int totalScore;

  LeaderboardEntry({
    required this.idParticipant,
    required this.totalScore,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_participant': idParticipant,
      'totalScore': totalScore,
    };
  }

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      idParticipant: map['id_participant'] as String? ?? '',
      totalScore: map['totalScore'] as int? ?? 0,
    );
  }
}
class QuestionItem {
  final String questionId;
  final TextEditingController controller;
  final List<AnswerItem> answers;
  int timeLimit;

  QuestionItem({
    required this.questionId,
    required this.controller,
    required this.answers,
    required this.timeLimit,
  });
}

class AnswerItem {
  final String answerId;
  final TextEditingController controller;
  bool isCorrect;

  AnswerItem({
    required this.answerId,
    required this.controller,
    required this.isCorrect,
  });
}

