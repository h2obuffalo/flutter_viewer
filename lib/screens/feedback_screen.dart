import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../services/feedback_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
    });

    final success = await FeedbackService().submitFeedback(
      feedbackText: _feedbackController.text,
      email: _emailController.text.trim().isEmpty ? null : _emailController.text,
      name: _nameController.text.trim().isEmpty ? null : _nameController.text,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _isSubmitted = success;
      });

      final bool isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
      if (!mounted || !isCurrentRoute) {
        return;
      }

      if (success) {
        // Clear form after successful submission
        _feedbackController.clear();
        _emailController.clear();
        _nameController.clear();
        
        // Show success message only if still on feedback screen
        if (mounted && isCurrentRoute) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Thank you for your feedback!',
                style: TextStyle(color: RetroTheme.darkBlue),
              ),
              backgroundColor: RetroTheme.electricGreen,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Reset submitted state after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
            setState(() {
              _isSubmitted = false;
            });
          }
        });
      } else {
        // Show error message only if still on feedback screen
        if (mounted && isCurrentRoute) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Failed to submit feedback. Please try again.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: RetroTheme.hotPink,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroTheme.darkBlue,
      appBar: AppBar(
        backgroundColor: RetroTheme.darkBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: RetroTheme.neonCyan),
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'FEEDBACK',
          style: TextStyle(
            color: RetroTheme.neonCyan,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontFamily: 'Impact',
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  
                  // Feedback text field
                  Container(
                    width: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: RetroTheme.neonCyan,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: RetroTheme.neonCyan.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _feedbackController,
                      maxLines: 8,
                      style: const TextStyle(
                        color: RetroTheme.neonCyan,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter your feedback here...',
                        hintStyle: TextStyle(
                          color: RetroTheme.neonCyan.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your feedback';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Optional: Name field
                  Container(
                    width: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: RetroTheme.electricGreen,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: RetroTheme.electricGreen.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _nameController,
                      style: const TextStyle(
                        color: RetroTheme.electricGreen,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Name (optional - for reply)',
                        hintStyle: TextStyle(
                          color: RetroTheme.electricGreen.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Optional: Email field
                  Container(
                    width: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: RetroTheme.electricGreen,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: RetroTheme.electricGreen.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(
                        color: RetroTheme.electricGreen,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Email (optional - for reply)',
                        hintStyle: TextStyle(
                          color: RetroTheme.electricGreen.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          // Basic email validation
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Submit button
                  GestureDetector(
                    onTap: _isSubmitting || _isSubmitted ? null : _submitFeedback,
                    child: Container(
                      width: 280,
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isSubmitting || _isSubmitted
                              ? RetroTheme.mutedGray
                              : RetroTheme.hotPink,
                          width: 2,
                        ),
                        boxShadow: _isSubmitting || _isSubmitted
                            ? null
                            : [
                                BoxShadow(
                                  color: RetroTheme.hotPink.withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                              ],
                      ),
                      child: Center(
                        child: _isSubmitting
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: RetroTheme.hotPink,
                                ),
                              )
                            : Text(
                                _isSubmitted ? 'SUBMITTED' : 'SUBMIT',
                                style: TextStyle(
                                  color: _isSubmitting || _isSubmitted
                                      ? RetroTheme.mutedGray
                                      : RetroTheme.hotPink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Info text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Your feedback helps us improve the app. Email and name are optional and only used if you want a reply.',
                      style: TextStyle(
                        color: RetroTheme.neonCyan.withValues(alpha: 0.7),
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
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
}

