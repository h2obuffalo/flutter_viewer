import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../screens/simple_player_screen.dart';

class TicketInputDialog extends StatefulWidget {
  const TicketInputDialog({super.key});

  @override
  State<TicketInputDialog> createState() => _TicketInputDialogState();
}

class _TicketInputDialogState extends State<TicketInputDialog> {
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
        // Close dialog and navigate to player
        Navigator.of(context).pop(); // Close dialog
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SimplePlayerScreen()),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              RetroTheme.darkBlue,
              RetroTheme.darkGray,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: RetroTheme.neonCyan,
            width: 2,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with back button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: RetroTheme.neonCyan.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: RetroTheme.neonCyan),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                    Expanded(
                      child: Text(
                        'ENTER TICKET',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: RetroTheme.neonCyan,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    // Invisible button to balance the back button
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo/Icon
                        Icon(
                          Icons.qr_code,
                          size: 60,
                          color: RetroTheme.neonCyan,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Enter your ticket number to access the stream',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: RetroTheme.electricGreen.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Ticket input field
                        TextFormField(
                          controller: _ticketController,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _activateTicket(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
                        const SizedBox(height: 16),
                        // Error message
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
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
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: RetroTheme.hotPink,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_errorMessage != null) const SizedBox(height: 16),
                        // Activate button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _activateTicket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RetroTheme.electricGreen,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                  ),
                                )
                              : const Text(
                                  'ACTIVATE',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        // Help text
                        Text(
                          'Your ticket gives you 4 days of access starting from first activation',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: RetroTheme.electricGreen.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}








