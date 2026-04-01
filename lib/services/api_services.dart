import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'local_db_service.dart';
import 'package:flutter/foundation.dart';
import '../utils/api_constants.dart';

class ApiService {
  // --- ENVIRONMENT ROUTING ---
  static const String liveBaseUrl = 'https://bettergym.online/bettergym_api';
  static const String localBaseUrl = 'http://192.168.100.14/bettergym_api';

  static String? _activeBaseUrl;

  static Future<String> getBaseUrl() async {
    if (_activeBaseUrl != null) return _activeBaseUrl!;

    try {
      final response = await http.get(Uri.parse('$liveBaseUrl/login.php')).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200 || response.statusCode == 405) { 
        debugPrint("ROUTING: Connected to LIVE server.");
        _activeBaseUrl = liveBaseUrl;
        return _activeBaseUrl!;
      }
    } catch (e) {
      debugPrint("ROUTING: Live server unreachable. Falling back to XAMPP.");
    }

    _activeBaseUrl = localBaseUrl;
    return _activeBaseUrl!;
  }

  // --- AUTHENTICATION ---
  static Future<Map<String, dynamic>> login({required String username, required String password}) async {
    final baseUrl = await getBaseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl/login.php'),
      body: {'username': username, 'password': password},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> register({
    required String username, required String password, required String email,
    required String firstName, required String lastName, required String birthday,
  }) async {
    final baseUrl = await getBaseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl/register.php'),
      body: {
        'username': username, 'password': password, 'email': email,
        'first_name': firstName, 'last_name': lastName, 'birthday': birthday,
      },
    );
    return jsonDecode(response.body);
  }

  // --- THE SYNC ENGINE ---
  static Future<void> syncOfflineData() async {
    try {
      final unsynced = await LocalDBService.instance.getUnsyncedSessions();
      if (unsynced.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getInt('user_id');

      if (token == null || userId == null) {
        debugPrint('SYNC ABORTED: Missing authentication constraints.');
        return; 
      }

      for (var sessionPayload in unsynced) {
        // Inject auth and format keys for the PHP script
        sessionPayload['auth_token'] = token;
        sessionPayload['user_id'] = userId;
        
        // PHP script looks for session_id at the root level
        if (!sessionPayload.containsKey('session_id')) {
           sessionPayload['session_id'] = sessionPayload['id']; 
        }

        final response = await http.post(
          Uri.parse('https://YOUR_DOMAIN.com/api/sync_session.php'), // UPDATE THIS URL
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(sessionPayload),
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['status'] == 'success') {
            // ONLY mark as synced if the server explicitly confirms atomic insertion
            await LocalDBService.instance.markSessionSynced(sessionPayload['id']);
          } else {
            debugPrint('SYNC REJECTED BY SERVER: ${result['message']}');
          }
        } else {
          debugPrint('SYNC HTTP ERROR: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('SYNC FATAL EXCEPTION: $e');
      // Fails silently. Will retry on next UI trigger.
    }
  }

  static Future<Map<String, dynamic>?> pullSettings() async {
    try {
      final baseUrl = await getBaseUrl();
      final prefs = await SharedPreferences.getInstance();
      
      String? userId = prefs.getInt('user_id')?.toString();
      String? token = prefs.getString('auth_token');

      if (userId == null || token == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/get_settings.php'), // You will need to create this PHP script
        body: {'user_id': userId, 'auth_token': token},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("SETTINGS PULL ERROR: $e");
    }
    return null;
  }
  static Future<void> pushSettings({
    required int prepTime,
    required int restTime,
    required bool voiceEnabled,
    required double feedbackVolume,
    required double beepsVolume,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      final int? userId = prefs.getInt('user_id');

      if (token == null || userId == null) {
        debugPrint("ApiService: Aborting settings sync. Missing credentials.");
        return;
      }

      // Note: We are NOT using jsonEncode here to strictly match your PHP $_POST expectations
      final response = await http.post(
        Uri.parse(ApiConstants.updateSettingsEndpoint), // Ensure this constant exists in api_constants.dart
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          "auth_token": token,
          "user_id": userId.toString(),
          "prep_time": prepTime.toString(),
          "rest_time": restTime.toString(),
          "voice_enabled": voiceEnabled ? "1" : "0", 
          "feedback_volume": feedbackVolume.toString(),
          "beeps_volume": beepsVolume.toString(),
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint("ApiService: Settings synchronized to cloud.");
      } else {
        debugPrint("ApiService: Server rejected settings sync - HTTP ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("ApiService: Settings network failure - $e");
    }
  }
}