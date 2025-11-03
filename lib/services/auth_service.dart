import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;
import '../config/constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _tokenKey = 'playback_token';
  static const String _expiryKey = 'playback_token_expiry';
  static const String _ticketKey = 'ticket_number';
  static const String _streamUrlKey = 'stream_url';
  
  String? _deviceId;
  
  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'ios-unknown-${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else {
        _deviceId = 'unknown-${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      _deviceId = 'error-${DateTime.now().millisecondsSinceEpoch}';
    }
    
    return _deviceId!;
  }
  
  Future<bool> validateTicket(String ticketNumber) async {
    try {
      final deviceId = await _getDeviceId();
      final url = Uri.parse('${AppConstants.authApiUrl}/auth/validate-ticket');
      final resp = await http.post(url, 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ticketNumber': ticketNumber, 'deviceId': deviceId}),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final token = data['token'];
        final expiry = data['expiresAt'];
        // Stream URL may be provided by the API, otherwise use null (will need to be set via config)
        final streamUrl = data['streamUrl'] as String?;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_expiryKey, expiry);
        await prefs.setString(_ticketKey, ticketNumber);
        if (streamUrl != null) {
          await prefs.setString(_streamUrlKey, streamUrl);
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error validating ticket: $e');
      return false;
    }
  }
  
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
  
  Future<bool> isTokenValid() async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = prefs.getString(_expiryKey);
    if (expiry == null) return false;
    final expiryDate = DateTime.parse(expiry);
    return DateTime.now().isBefore(expiryDate);
  }
  
  Future<String?> getStreamUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_streamUrlKey);
  }
  
  Future<void> setStreamUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_streamUrlKey, url);
  }
  
  Future<String?> getAuthedHlsUrl() async {
    final token = await getToken();
    final expiry = await SharedPreferences.getInstance().then((p) => p.getString(_expiryKey));
    
    if (token == null || expiry == null) {
      // Return null if no token - caller should handle this
      return null;
    }
    
    // Get stream URL from storage (set via config API or auth response)
    // Fallback to constant URL if not in storage (for backward compatibility)
    var streamUrl = await getStreamUrl();
    if (streamUrl == null) {
      // Use fallback constant URL if not configured dynamically
      streamUrl = AppConstants.hlsManifestUrl;
      print('⚠️ Stream URL not in storage, using fallback: $streamUrl');
    }
    
    final expiryTimestamp = DateTime.parse(expiry).millisecondsSinceEpoch;
    // Add token as query parameter
    final separator = streamUrl.contains('?') ? '&' : '?';
    return '$streamUrl$separator token=$token&expires=$expiryTimestamp';
  }
  
  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_expiryKey);
    await prefs.remove(_ticketKey);
    // Note: Don't remove stream URL - it can be reused if still valid
  }
}
