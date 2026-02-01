import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ApiService {
  // ✅ Production API on Render
  // Change to localhost:5201 to use local backend with court CRUD
  // static const String baseUrl = 'http://localhost:5201/api';
  // static const String baseUrl = 'http://10.0.2.2:5201/api'; // Emulator
  static const String baseUrl = 'https://test1-wxri.onrender.com/api';

  // ===== AUTH =====

  static Future<String?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      return token;
    }
    return null;
  }

  static Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    print('📝 Registering user: $email');
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
      }),
    );

    print('📝 Register response: ${response.statusCode}');
    if (response.statusCode != 200 && response.statusCode != 201) {
      print('❌ Register failed: ${response.body}');
    }

    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>?> me() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return null;

    final res = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<bool> updateProfile({
    required int memberId,
    required String fullName,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    final token = await _getToken();
    if (token == null) return false;

    final response = await http.put(
      Uri.parse('$baseUrl/member/$memberId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'avatarUrl': avatarUrl,
      }),
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await _getToken();
    if (token == null) return false;

    final response = await http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    return response.statusCode == 200;
  }

  // ===== COURTS & BOOKINGS =====

  static Future<List<dynamic>> getCourts() async {
    final token = await _getToken();
    if (token == null) return [];

    print('🏟️ Fetching courts: $baseUrl/court');
    final response = await http.get(
      Uri.parse('$baseUrl/court'),
      headers: {'Authorization': 'Bearer $token'},
    );

    print('🏟️ Get courts response: ${response.statusCode}');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      print('❌ Get courts failed: ${response.body}');
      return [];
    }
  }

  static Future<bool> createCourt({
    required String name,
    required String location,
    required double pricePerHour,
  }) async {
    final token = await _getToken();
    if (token == null) return false;

    print('🏟️ Creating court: $name at $location, price: $pricePerHour');

    final response = await http.post(
      Uri.parse('$baseUrl/court'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'description': location, 
        'pricePerHour': pricePerHour,
        'isActive': true,
      }),
    );

    print('🏟️ Create court response: ${response.statusCode}');
    if (response.statusCode == 403) {
      print('❌ ERROR 403: Permission Denied. User is NOT an Admin.');
    } else if (response.statusCode == 405) {
      print('❌ ERROR 405: Method Not Allowed. Route: $baseUrl/court');
    } else if (response.statusCode != 200 && response.statusCode != 201) {
      print('❌ Create court failed: ${response.body}');
    }

    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> updateCourt({
    required int courtId,
    required String name,
    required String location,
    required double pricePerHour,
  }) async {
    final token = await _getToken();
    if (token == null) return false;

    print('🏟️ Updating court $courtId: $name');

    final response = await http.put(
      Uri.parse('$baseUrl/court/$courtId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'description': location, // Backend uses 'description'
        'pricePerHour': pricePerHour,
        'isActive': true,
      }),
    );

    print('🏟️ Update court response: ${response.statusCode}');
    if (response.statusCode != 200 && response.statusCode != 204) {
      print('❌ Update court failed: ${response.body}');
    }

    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> deleteCourt(int courtId) async {
    final token = await _getToken();
    if (token == null) return false;

    print('🏟️ Deleting court $courtId');

    final response = await http.delete(
      Uri.parse('$baseUrl/court/$courtId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    print('🏟️ Delete court response: ${response.statusCode}');
    if (response.statusCode != 200 && response.statusCode != 204) {
      print('❌ Delete court failed: ${response.body}');
    }

    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<List<dynamic>> getMembers() async {
    final token = await _getToken();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse('$baseUrl/member'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print('👥 Get members response: ${res.statusCode}');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['items'] as List<dynamic>;
    } else {
      print('❌ Get members failed: ${res.body}');
      return [];
    }
  }

  static Future<List<dynamic>> getBookingsCalendar({
    required DateTime from,
    required DateTime to,
  }) async {
    final token = await _getToken();
    if (token == null) return [];

    final uri = Uri.parse(
      '$baseUrl/booking/calendar?from=${from.toIso8601String()}&to=${to.toIso8601String()}',
    );

    print('📅 Fetching calendar: $uri');
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    print('📅 Get calendar response: ${res.statusCode}');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    } else {
      print('❌ Get calendar failed: ${res.body}');
      return [];
    }
  }

  static Future<List<dynamic>> getMyBookings() async {
    final token = await _getToken();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse('$baseUrl/booking/my-bookings'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  static Future<bool> createBooking({
    required int courtId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final token = await _getToken();
    if (token == null) {
      print('❌ createBooking: No token available');
      return false;
    }

    print('📅 Creating booking: Court=$courtId, Start=$startTime, End=$endTime');
    
    final response = await http.post(
      Uri.parse('$baseUrl/booking'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'courtId': courtId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      }),
    );

    print('📅 Booking response: ${response.statusCode}');
    if (response.statusCode != 200) {
      print('❌ Booking failed: ${response.body}');
    }

    return response.statusCode == 200;
  }

  static Future<bool> cancelBooking(int id) async {
    final token = await _getToken();
    if (token == null) return false;

    final response = await http.post(
      Uri.parse('$baseUrl/booking/cancel/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  }

  // ===== WALLET =====

  static Future<bool> deposit({
    required double amount,
    String? description,
  }) async {
    final token = await _getToken();
    if (token == null) return false;

    final res = await http.post(
      Uri.parse('$baseUrl/wallet/deposit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amount': amount, 'description': description}),
    );

    return res.statusCode == 200;
  }

  static Future<List<dynamic>> walletTransactions() async {
    final token = await _getToken();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse('$baseUrl/wallet/transactions'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  static Future<List<dynamic>> adminAllTransactions() async {
    final token = await _getToken();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse('$baseUrl/wallet/admin/all'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  static Future<List<dynamic>> getTournaments({String? status}) async {
    final token = await _getToken();
    if (token == null) return [];

    var url = '$baseUrl/tournament';
    if (status != null) url += '?status=$status';

    final res = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  static Future<bool> createTournament({
    required String name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    required double entryFee,
    required int maxPlayers,
    required String type,
  }) async {
    final token = await _getToken();
    if (token == null) return false;

    print('🏆 Creating tournament: $name');

    final response = await http.post(
      Uri.parse('$baseUrl/tournament'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'description': description ?? '',
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'entryFee': entryFee,
        'maxPlayers': maxPlayers,
        'type': type,
      }),
    );

    print('🏆 Create tournament response: ${response.statusCode}');
    if (response.statusCode != 200 && response.statusCode != 201) {
      print('❌ Create tournament failed: ${response.body}');
    }

    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> updateTournament({
    required int tournamentId,
    required String name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    required double entryFee,
    required int maxPlayers,
    required String type,
  }) async {
    final token = await _getToken();
    if (token == null) return false;

    print('🏆 Updating tournament $tournamentId: $name');

    final response = await http.put(
      Uri.parse('$baseUrl/tournament/$tournamentId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'description': description ?? '',
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'entryFee': entryFee,
        'maxPlayers': maxPlayers,
        'type': type,
      }),
    );

    print('🏆 Update tournament response: ${response.statusCode}');
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> deleteTournament(int tournamentId) async {
    final token = await _getToken();
    if (token == null) return false;

    print('🏆 Deleting tournament $tournamentId');

    final response = await http.delete(
      Uri.parse('$baseUrl/tournament/$tournamentId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    print('🏆 Delete tournament response: ${response.statusCode}');
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> joinTournament({
    required int tournamentId,
    required String? groupName,
    required int teamSize,
  }) async {
    final token = await _getToken();
    if (token == null) return false;

    final res = await http.post(
      Uri.parse('$baseUrl/tournament/$tournamentId/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'groupName': groupName, 'teamSize': teamSize}),
    );
    return res.statusCode == 200;
  }

  // ===== ADMIN (đơn giản) =====

  static Future<List<dynamic>> adminAllBookings() async {
    final token = await _getToken();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse('$baseUrl/booking'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  static Future<List<dynamic>> getNotifications() async {
    final token = await _getToken();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse('$baseUrl/notification'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      // Support both casing styles
      return (body['items'] ?? body['Items'] ?? []) as List<dynamic>;
    }
    return [];
  }

  static Future<int> getUnreadNotificationCount() async {
    final token = await _getToken();
    if (token == null) return 0;

    final res = await http.get(
      Uri.parse('$baseUrl/notification'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return (body['unreadCount'] ?? body['UnreadCount'] ?? 0) as int;
    }
    return 0;
  }


  // =================
  // Challenges
  // =================

  static Future<String?> createChallenge({int? opponentId, required DateTime scheduledTime}) async {
    final token = await _getToken();
    if (token == null) return 'Not authenticated';

    try {
      final uri = Uri.parse('$baseUrl/match/create-challenge');
      print('⚔️ Calling Create Challenge: $uri');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'opponentId': opponentId,
          'scheduledTime': scheduledTime.toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null; // Success
      } else {
        print('❌ Create Challenge Failed: ${response.statusCode} - ${response.body}');
        if (response.statusCode == 405) return 'Error 405: Method Not Allowed. URL: $uri';
        if (response.statusCode == 403) return 'Error 403: Permission Denied (Forbidden).';
        return 'Failed: ${response.statusCode} ${response.body}';
      }
    } catch (e) {
      return 'Network Error: $e';
    }
  }

  static Future<List<dynamic>> getChallenges() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      print('⚔️ Fetching challenges: $baseUrl/match/challenges');
      final response = await http.get(
        Uri.parse('$baseUrl/match/challenges'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('⚔️ Get challenges response: ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Get challenges failed: ${response.body}');
      }
    } catch (e) {
      print('Error fetching challenges: $e');
    }
    return [];
  }

  static Future<String?> acceptChallenge(int matchId) async {
    final token = await _getToken();
    if (token == null) return 'Not authenticated';

    final response = await http.post(
      Uri.parse('$baseUrl/match/$matchId/accept'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return null; // Success
    } else {
      return 'Failed: ${response.statusCode} ${response.body}';
    }
  }


  static Future<List<dynamic>> searchMembers(String query) async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/member?search=$query&pageSize=10'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['items'] as List<dynamic>;
      }
    } catch (e) {
      print('Error searching members: $e');
    }
    return [];
  }

  // ===== Helpers =====

  // ===== Unified Notifications =====

  // Now fully Server-Side Managed ("Real" Notifications)
  static Future<List<dynamic>> getUnifiedNotifications() async {
    return await getNotifications();
  }

  static Future<bool> markAllNotificationsAsRead() async {
    final token = await _getToken();
    if (token == null) return false;

    final res = await http.post(
      Uri.parse('$baseUrl/notification/read-all'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return res.statusCode == 200;
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
  // ===== DIAGNOSTICS =====
  static Future<Map<String, dynamic>> checkServerStatus() async {
    try {
      // 1. Try Ping first (Sanity Check)
      final ping = await http.get(Uri.parse('$baseUrl/ping')); 
      
      final response = await http.get(Uri.parse('$baseUrl/diagnostics'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'error': 'Failed to connect: ${response.statusCode}',
          'ping_status': ping.statusCode,
          'ping_body': ping.body
        };
      }
    } catch (e) {
      return {'error': 'Connection error: $e'};
    }
  }
}
