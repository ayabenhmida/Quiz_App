import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

import '../../model/quiz_models.dart' show AnswerItem, QuestionItem;

class EditQuizPage extends StatefulWidget {
  final String quizId;

  const EditQuizPage({Key? key, required this.quizId}) : super(key: key);

  @override
  _EditQuizPageState createState() => _EditQuizPageState();
}

class _EditQuizPageState extends State<EditQuizPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSaving = false;
  String _code = '';
  List<QuestionItem> _questions = [];
  int? _selectedQuestionIndex;

  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
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

    _loadQuizData();
  }

  Future<void> _loadQuizData() async {
    try {
      final docSnapshot = await _firestore.collection('quizzes').doc(widget.quizId).get();

      if (!docSnapshot.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quiz introuvable'),
              backgroundColor: Color(0xFFFF3355),
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      final quizData = docSnapshot.data() as Map<String, dynamic>;

      _titleController.text = quizData['title'] ?? '';
      _code = quizData['code'] ?? '';

      List<QuestionItem> loadedQuestions = [];
      List<dynamic> questionsList = quizData['questions'] ?? [];

      for (var questionData in questionsList) {
        final questionController = TextEditingController(text: questionData['text'] ?? '');

        List<AnswerItem> answers = [];
        List<dynamic> answersList = questionData['answers'] ?? [];
        String correctAnswerId = questionData['correctAnswerId'] ?? '';

        for (var answerData in answersList) {
          answers.add(AnswerItem(
            answerId: answerData['answerId'] ?? const Uuid().v4(),
            controller: TextEditingController(text: answerData['text'] ?? ''),
            isCorrect: answerData['answerId'] == correctAnswerId,
          ));
        }

        loadedQuestions.add(QuestionItem(
          questionId: questionData['questionId'] ?? const Uuid().v4(),
          controller: questionController,
          answers: answers,
          timeLimit: questionData['timeLimit'] ?? 30,
        ));
      }

      setState(() {
        _questions = loadedQuestions;
        _isLoading = false;
        if (_questions.isNotEmpty) {
          _selectedQuestionIndex = 0;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement du quiz: $e'),
            backgroundColor: const Color(0xFFFF3355),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _addQuestion() {
    setState(() {
      _questions.add(QuestionItem(
        questionId: const Uuid().v4(),
        controller: TextEditingController(),
        answers: [
          AnswerItem(answerId: const Uuid().v4(), controller: TextEditingController(), isCorrect: true),
          AnswerItem(answerId: const Uuid().v4(), controller: TextEditingController(), isCorrect: false),
        ],
        timeLimit: 30,
      ));
      _selectedQuestionIndex = _questions.length - 1;
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
      if (_questions.isEmpty) {
        _selectedQuestionIndex = null;
      } else if (_selectedQuestionIndex != null && _selectedQuestionIndex! >= _questions.length) {
        _selectedQuestionIndex = _questions.length - 1;
      }
    });
  }

  void _addAnswer(QuestionItem question) {
    setState(() {
      question.answers.add(AnswerItem(
        answerId: const Uuid().v4(),
        controller: TextEditingController(),
        isCorrect: false,
      ));
    });
  }

  void _removeAnswer(QuestionItem question, int index) {
    setState(() {
      bool isRemovingCorrect = question.answers[index].isCorrect;
      bool hasOtherCorrect = question.answers.any((a) => a.isCorrect && a != question.answers[index]);

      if (isRemovingCorrect && !hasOtherCorrect && question.answers.length > 1) {
        for (int i = 0; i < question.answers.length; i++) {
          if (i != index) {
            question.answers[i].isCorrect = true;
            break;
          }
        }
      }

      question.answers.removeAt(index);

      if (question.answers.isEmpty) {
        question.answers.add(AnswerItem(
          answerId: const Uuid().v4(),
          controller: TextEditingController(),
          isCorrect: true,
        ));
      }
    });
  }

  void _setCorrectAnswer(QuestionItem question, int index) {
    setState(() {
      for (var answer in question.answers) {
        answer.isCorrect = false;
      }
      question.answers[index].isCorrect = true;
    });
  }

  void _reorderQuestions(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final question = _questions.removeAt(oldIndex);
      _questions.insert(newIndex, question);
      if (_selectedQuestionIndex == oldIndex) {
        _selectedQuestionIndex = newIndex;
      } else if (_selectedQuestionIndex != null) {
        if (_selectedQuestionIndex! > oldIndex && _selectedQuestionIndex! <= newIndex) {
          _selectedQuestionIndex = _selectedQuestionIndex! - 1;
        } else if (_selectedQuestionIndex! < oldIndex && _selectedQuestionIndex! >= newIndex) {
          _selectedQuestionIndex = _selectedQuestionIndex! + 1;
        }
      }
    });
  }

  Future<void> _saveQuiz() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isSaving = true;
        });

        final Map<String, dynamic> quizData = {
          'title': _titleController.text.trim(),
          'updatedAt': Timestamp.now(),
          'questions': _questions.asMap().entries.map((entry) {
            final q = entry.value;
            String correctAnswerId = '';
            for (var answer in q.answers) {
              if (answer.isCorrect) {
                correctAnswerId = answer.answerId;
                break;
              }
            }

            return {
              'questionId': q.questionId,
              'text': q.controller.text,
              'order': entry.key,
              'answers': q.answers.map((a) => {
                    'answerId': a.answerId,
                    'text': a.controller.text,
                    'isCorrect': a.isCorrect,
                  }).toList(),
              'correctAnswerId': correctAnswerId,
              'timeLimit': q.timeLimit,
            };
          }).toList(),
        };

        await _firestore.collection('quizzes').doc(widget.quizId).update(quizData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quiz mis à jour avec succès'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF46178F),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la mise à jour: $e'),
              backgroundColor: const Color(0xFFFF3355),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  InputDecoration _inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 14,
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF46178F);
    final accentColor = const Color(0xFFFF3355);

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
              return Opacity(
                opacity: _fadeInAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: child,
                ),
              );
            },
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: Row(
                      children: [
                        // Sidebar for questions
                        Container(
                          width: 250,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Questions',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Code: $_code',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: ElevatedButton.icon(
                                  onPressed: _addQuestion,
                                  icon: const Icon(Icons.add),
                                  label: const Text('New Question'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ReorderableListView(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  onReorder: _reorderQuestions,
                                  buildDefaultDragHandles: false,
                                  children: _questions.asMap().entries.map((entry) {
                                    int index = entry.key;
                                    QuestionItem question = entry.value;
                                    return ReorderableDragStartListener(
                                      key: ValueKey(question.questionId),
                                      index: index,
                                      child: Card(
                                        color: _selectedQuestionIndex == index
                                            ? accentColor.withOpacity(0.2)
                                            : Colors.transparent,
                                        elevation: 0,
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: _selectedQuestionIndex == index
                                                ? accentColor
                                                : Colors.white.withOpacity(0.2),
                                            foregroundColor: Colors.white,
                                            radius: 14,
                                            child: Text('${index + 1}'),
                                          ),
                                          title: Text(
                                            question.controller.text.isEmpty
                                                ? 'Question ${index + 1}'
                                                : question.controller.text,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.white70,
                                              size: 18,
                                            ),
                                            onPressed: () => _removeQuestion(index),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _selectedQuestionIndex = index;
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Main content area
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_questions.isNotEmpty)
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: ElevatedButton.icon(
                                      onPressed: _isSaving ? null : _saveQuiz,
                                      icon: const Icon(Icons.save),
                                      label: const Text('Registre'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accentColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _titleController,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  decoration: _inputDecoration('Enter quiz title'),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter a title';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                if (_selectedQuestionIndex != null)
                                  Expanded(
                                    child: _buildQuestionEditor(
                                      _questions[_selectedQuestionIndex!],
                                      _selectedQuestionIndex!,
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.quiz_outlined,
                                            size: 60,
                                            color: Colors.white70,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Add your first question',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.white.withOpacity(0.6),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton(
                                            onPressed: _addQuestion,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: accentColor,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 12,
                                              ),
                                            ),
                                            child: const Text('Create Question'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionEditor(QuestionItem question, int questionIndex) {
    final accentColor = const Color(0xFFFF3355);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${questionIndex + 1}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: question.controller,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            decoration: _inputDecoration('Enter your question'),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a question';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Time limit: ${question.timeLimit} seconds',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accentColor,
              inactiveTrackColor: Colors.white.withOpacity(0.2),
              thumbColor: accentColor,
              overlayColor: accentColor.withOpacity(0.2),
              valueIndicatorColor: accentColor,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: question.timeLimit.toDouble(),
              min: 5,
              max: 120,
              divisions: 23,
              label: '${question.timeLimit} seconds',
              onChanged: (value) {
                setState(() {
                  question.timeLimit = value.round();
                });
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Answer choices',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          ...question.answers.asMap().entries.map((entry) {
            int index = entry.key;
            AnswerItem answer = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Radio(
                    value: true,
                    groupValue: answer.isCorrect,
                    onChanged: (_) => _setCorrectAnswer(question, index),
                    activeColor: accentColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: answer.controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        'Option ${index + 1}',
                        suffixIcon: question.answers.length > 1
                            ? IconButton(
                                icon: const Icon(Icons.close, color: Colors.white70),
                                onPressed: () => _removeAnswer(question, index),
                              )
                            : null,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an answer';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _addAnswer(question),
            icon: const Icon(Icons.add, color: Colors.white, size: 16),
            label: const Text(
              'Add another option',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _animationController.dispose();
    for (var question in _questions) {
      question.controller.dispose();
      for (var answer in question.answers) {
        answer.controller.dispose();
      }
    }
    super.dispose();
  }
}


