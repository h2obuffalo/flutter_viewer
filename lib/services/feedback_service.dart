import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;
import '../config/constants.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  Future<bool> submitFeedback({
    required String feedbackText,
    String? email,
    String? name,
  }) async {
    try {
      // Get app version
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;

      // Get platform
      String platform;
      if (Platform.isIOS) {
        platform = 'iOS';
      } else if (Platform.isAndroid) {
        platform = 'Android';
      } else {
        platform = 'Unknown';
      }

      final url = Uri.parse('${AppConstants.lineupApiUrl}/lineup/feedback/submit');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'BFTV-Mobile/1.0.0',
        },
        body: jsonEncode({
          'feedback_text': feedbackText,
          'email': email?.trim().isEmpty == true ? null : email?.trim(),
          'name': name?.trim().isEmpty == true ? null : name?.trim(),
          'app_version': appVersion,
          'platform': platform,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }

      print('Feedback submission failed with status: ${response.statusCode}');
      print('Response body: ${response.body}');
      return false;
    } catch (e) {
      print('Error submitting feedback: $e');
      return false;
    }
  }
}

