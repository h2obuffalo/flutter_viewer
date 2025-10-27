import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/ticket.dart';
import '../config/constants.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _ticketKey = 'ticket_data';
  static const String _tokenKey = 'auth_token';

  Future<Map<String, dynamic>> validateTicket(String ticketNumber) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.authApiUrl}/auth/validate-ticket'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ticket_number': ticketNumber}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Store ticket data securely
        final ticket = Ticket.fromJson(data['ticket'] as Map<String, dynamic>);
        await _storage.write(key: _ticketKey, value: jsonEncode(ticket.toJson()));
        
        // Store auth token
        if (data['token'] != null) {
          await _storage.write(key: _tokenKey, value: data['token'] as String);
        }
        
        return {'success': true, 'ticket': ticket};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['message'] ?? 'Invalid ticket'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Ticket?> getStoredTicket() async {
    try {
      final ticketData = await _storage.read(key: _ticketKey);
      if (ticketData != null) {
        final data = jsonDecode(ticketData) as Map<String, dynamic>;
        return Ticket.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<bool> isAuthenticated() async {
    final ticket = await getStoredTicket();
    if (ticket == null) return false;
    
    // Check if ticket is expired
    if (ticket.isExpired) {
      await logout();
      return false;
    }
    
    return true;
  }

  Future<void> logout() async {
    await _storage.delete(key: _ticketKey);
    await _storage.delete(key: _tokenKey);
    
    // Call logout API
    try {
      final token = await getAuthToken();
      if (token != null) {
        await http.post(
          Uri.parse('${AppConstants.authApiUrl}/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (e) {
      // Ignore logout errors
    }
  }

  // Refresh session if needed
  Future<bool> refreshSession() async {
    try {
      final ticket = await getStoredTicket();
      if (ticket == null) return false;
      
      final token = await getAuthToken();
      if (token == null) return false;
      
      final response = await http.post(
        Uri.parse('${AppConstants.authApiUrl}/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newTicket = Ticket.fromJson(data['ticket'] as Map<String, dynamic>);
        await _storage.write(key: _ticketKey, value: jsonEncode(newTicket.toJson()));
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
}
