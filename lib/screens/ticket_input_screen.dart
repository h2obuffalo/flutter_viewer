import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import 'main_menu_screen.dart';

class TicketInputScreen extends StatefulWidget {
  const TicketInputScreen({super.key});

  @override
  State<TicketInputScreen> createState() => _TicketInputScreenState();
}

class _TicketInputScreenState extends State<TicketInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ticketController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _ticketController.dispose();
    super.dispose();
  }

  Future<void> _activateTicket() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ticketNumber = _ticketController.text.trim();
      final success = await AuthService().validateTicket(ticketNumber);

      if (!mounted) return;

      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainMenuScreen()),
        );
      } else {
        setState(() {
          _errorMessage = 'Invalid ticket number. Please try again.';
          _isLoading = false;
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error activating ticket. Please try again.';
        _isLoading = false;
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroTheme.darkBlue,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              RetroTheme.darkBlue,
              RetroTheme.darkGray,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo/Title
                    Icon(
                      Icons.qr_code,
                      size: 80,
                      color: RetroTheme.neonCyan,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'ENTER TICKET',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: RetroTheme.neonCyan,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your ticket number to activate access',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: RetroTheme.electricGreen.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Ticket input field
                    TextFormField(
                      controller: _ticketController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _activateTicket(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ticket Number',
                        hintStyle: TextStyle(
                          color: RetroTheme.electricGreen.withValues(alpha: 0.5),
                        ),
                        prefixIcon: Icon(
                          Icons.confirmation_number,
                          color: RetroTheme.neonCyan,
                        ),
                        filled: true,
                        fillColor: RetroTheme.darkGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: RetroTheme.neonCyan,
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: RetroTheme.neonCyan,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: RetroTheme.electricGreen,
                            width: 3,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your ticket number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Error message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: RetroTheme.hotPink.withValues(alpha: 0.2),
                          border: Border.all(
                            color: RetroTheme.hotPink,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: RetroTheme.hotPink,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: RetroTheme.hotPink,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_errorMessage != null) const SizedBox(height: 24),
                    // Activate button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _activateTicket,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RetroTheme.electricGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Text(
                              'ACTIVATE',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    // Help text
                    Text(
                      'Your ticket gives you 4 days of access starting from first activation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: RetroTheme.electricGreen.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


