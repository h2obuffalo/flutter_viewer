import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _notificationsEnabled;
  bool _aboutExpanded = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    final enabled = await NotificationService().areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    HapticFeedback.mediumImpact();
    await NotificationService().setNotificationsEnabled(value);
    if (mounted) {
      setState(() {
        _notificationsEnabled = value;
      });
    }
  }

  void _navigateToPrivacyPolicy() {
    HapticFeedback.mediumImpact();
    Navigator.pushNamed(context, '/privacy');
  }

  void _navigateToFeedback() {
    HapticFeedback.mediumImpact();
    Navigator.pushNamed(context, '/feedback');
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
          'SETTINGS',
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              const SizedBox(height: 40),
              
              // Notification Toggle
                Container(
                  width: 280,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'NOTIFICATIONS',
                        style: TextStyle(
                          color: RetroTheme.electricGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      _isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: RetroTheme.electricGreen,
                              ),
                            )
                          : Switch(
                              value: _notificationsEnabled ?? true,
                              onChanged: _toggleNotifications,
                              activeColor: RetroTheme.electricGreen,
                              activeTrackColor: RetroTheme.electricGreen.withValues(alpha: 0.5),
                              inactiveThumbColor: RetroTheme.mutedGray,
                              inactiveTrackColor: RetroTheme.mutedGray.withValues(alpha: 0.3),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Privacy Policy Link
                GestureDetector(
                  onTap: _navigateToPrivacyPolicy,
                  child: Container(
                    width: 280,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: RetroTheme.hotPink,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: RetroTheme.hotPink.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'PRIVACY POLICY',
                        style: TextStyle(
                          color: RetroTheme.hotPink,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Feedback Link
                GestureDetector(
                  onTap: _navigateToFeedback,
                  child: Container(
                    width: 280,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: RetroTheme.warningYellow,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: RetroTheme.warningYellow.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'FEEDBACK',
                        style: TextStyle(
                          color: RetroTheme.warningYellow,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // About Section (Expandable)
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
                  child: ExpansionTile(
                    title: const Text(
                      'ABOUT',
                      style: TextStyle(
                        color: RetroTheme.neonCyan,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    trailing: Icon(
                      _aboutExpanded ? Icons.expand_less : Icons.expand_more,
                      color: RetroTheme.neonCyan,
                    ),
                    onExpansionChanged: (expanded) {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        _aboutExpanded = expanded;
                      });
                    },
                    backgroundColor: RetroTheme.darkBlue,
                    collapsedBackgroundColor: RetroTheme.darkBlue,
                    iconColor: RetroTheme.neonCyan,
                    collapsedIconColor: RetroTheme.neonCyan,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: const Text(
                          'BFTV 2025\n\nVersion 1.0.0\n\nThanks for providing music:\nThe Teknoist\nKrest\nAnorak',
                          style: TextStyle(
                            color: RetroTheme.neonCyan,
                            fontSize: 14,
                            letterSpacing: 1,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

