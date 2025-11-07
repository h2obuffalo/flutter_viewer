import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import '../config/theme.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  String _markdownContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacyPolicy();
  }

  Future<void> _loadPrivacyPolicy() async {
    try {
      final content = await rootBundle.loadString('assets/docs/privacy-policy.md');
      if (mounted) {
        setState(() {
          _markdownContent = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _markdownContent = 'Error loading privacy policy: $e';
          _isLoading = false;
        });
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
          'PRIVACY POLICY',
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: RetroTheme.neonCyan,
              ),
            )
          : Markdown(
              data: _markdownContent,
              styleSheet: MarkdownStyleSheet(
                h1: const TextStyle(
                  color: RetroTheme.neonCyan,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontFamily: 'Impact',
                ),
                h2: const TextStyle(
                  color: RetroTheme.hotPink,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'Impact',
                ),
                h3: const TextStyle(
                  color: RetroTheme.electricGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
                p: const TextStyle(
                  color: RetroTheme.neonCyan,
                  fontSize: 16,
                  height: 1.6,
                  letterSpacing: 0.5,
                ),
                strong: const TextStyle(
                  color: RetroTheme.electricGreen,
                  fontWeight: FontWeight.bold,
                ),
                listBullet: const TextStyle(
                  color: RetroTheme.hotPink,
                ),
                code: TextStyle(
                  color: RetroTheme.electricGreen,
                  backgroundColor: RetroTheme.darkGray,
                  fontFamily: 'CourierPrimeCode',
                ),
                codeblockDecoration: BoxDecoration(
                  color: RetroTheme.darkGray,
                  border: Border.all(
                    color: RetroTheme.neonCyan,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: RetroTheme.hotPink,
                      width: 4,
                    ),
                  ),
                ),
                blockquote: const TextStyle(
                  color: RetroTheme.mutedGray,
                  fontStyle: FontStyle.italic,
                ),
              ),
              selectable: true,
            ),
    );
  }
}

