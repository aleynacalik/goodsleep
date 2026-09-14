import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5118/api';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  static String _familyId = '';
  static String _token = '';
  static String _userId = '';

  static Future<void> initAuth() async {
    _familyId = await _storage.read(key: 'familyId') ?? '';
    _token = await _storage.read(key: 'token') ?? '';
    _userId = await _storage.read(key: 'userId') ?? '';
    if (_token.isNotEmpty) await _refreshIfNeeded();
  }

  static Future<void> _refreshIfNeeded() async {
    try {
      final parts = _token.split('.');
      if (parts.length != 3) return;
      final payload = json.decode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload['exp'] as int?;
      if (exp == null) return;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      if (expiry.difference(DateTime.now()).inDays > 7) return;
      await _doRefresh();
    } catch (_) {}
  }

  static Future<bool> _doRefresh() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Auth/refresh'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        await _storage.write(key: 'token', value: _token);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String get familyId => _familyId;
  static String get userId => _userId;
  static bool get isLoggedIn => _token.isNotEmpty;

  static Future<void> logout() async {
    await _storage.deleteAll();
    _familyId = '';
    _token = '';
    _userId = '';
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  // --- AUTH ---

  static Future<String?> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'email': email, 'password': password}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) return null;
      if (response.statusCode == 409) return 'Bu e-posta adresi zaten kayıtlı.';
      if (response.statusCode == 400) return 'Geçersiz bilgiler. Lütfen kontrol edin.';
      return 'Kayıt başarısız (${response.statusCode}). Lütfen tekrar deneyin.';
    } catch (e) {
      return 'İnternet bağlantınızı kontrol edin.';
    }
  }

  static Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _token = (data['token'] as String?) ?? '';
        final user = data['user'] as Map<String, dynamic>?;
        _userId = (user?['id'] as String?) ?? '';
        _familyId = (user?['familyId'] as String?) ?? '';
        await _storage.write(key: 'token', value: _token);
        await _storage.write(key: 'userId', value: _userId);
        await _storage.write(key: 'familyId', value: _familyId);
        return null;
      }
      if (response.statusCode == 429) return 'Çok fazla giriş denemesi. 15 dakika sonra tekrar deneyin.';
      if (response.statusCode == 401) return 'E-posta veya şifre hatalı.';
      if (response.statusCode == 404) return 'Bu e-posta ile kayıtlı hesap bulunamadı.';
      if (response.statusCode == 400) return 'Geçersiz giriş bilgileri.';
      return 'Giriş başarısız (${response.statusCode}). Lütfen tekrar deneyin.';
    } catch (e) {
      return 'İnternet bağlantınızı kontrol edin.';
    }
  }

  static Future<String?> deleteAccount(String password) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/Auth/account'),
        headers: _headers,
        body: json.encode({'password': password}),
      );
      if (response.statusCode == 204) return null;
      if (response.statusCode == 401) return 'Şifre hatalı.';
      if (response.statusCode == 429) return 'Çok fazla deneme. Lütfen bekleyin.';
      return 'Hesap silinemedi. Lütfen tekrar deneyin.';
    } catch (e) {
      return 'İnternet bağlantınızı kontrol edin.';
    }
  }

  // --- UYKU VERİSİ ---

  static Future<List<dynamic>> getLogs() async {
    if (_familyId.isEmpty) return [];
    try {
      final response = await http.get(
          Uri.parse('$baseUrl/SleepLogs/family/$_familyId'), headers: _headers);
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) {
      if (kDebugMode) debugPrint('Veri çekme hatası: $e');
    }
    return [];
  }

  static Future<bool> addLog(DateTime start, DateTime end, int duration) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/SleepLogs'),
        headers: _headers,
        body: json.encode({
          'familyId': _familyId,
          'startTime': start.toUtc().toIso8601String(),
          'endTime': end.toUtc().toIso8601String(),
          'durationInSeconds': duration,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (kDebugMode) debugPrint('Log ekleme hatası: $e');
      return false;
    }
  }

  static Future<bool> updateLog(String id, DateTime start, DateTime end, int duration) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/SleepLogs/$id'),
        headers: _headers,
        body: json.encode({
          'startTime': start.toUtc().toIso8601String(),
          'endTime': end.toUtc().toIso8601String(),
          'durationInSeconds': duration,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) debugPrint('Log güncelleme hatası: $e');
      return false;
    }
  }

  static Future<bool> deleteLog(String id) async {
    try {
      final response = await http.delete(
          Uri.parse('$baseUrl/SleepLogs/$id'), headers: _headers);
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('Log silme hatası: $e');
      return false;
    }
  }

  // --- AİLE DAVET SİSTEMİ ---

  static Future<String?> generateInvite() async {
    if (_familyId.isEmpty) return null;
    try {
      final response = await http.post(
          Uri.parse('$baseUrl/Family/$_familyId/invite'), headers: _headers);
      if (response.statusCode == 200) {
        return json.decode(response.body)['code'];
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Davet kodu oluşturma hatası: $e');
    }
    return null;
  }

  static Future<bool> joinFamily(String inviteCode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Family/join'),
        headers: _headers,
        body: json.encode({'code': inviteCode}),
      );
      if (response.statusCode == 200) {
        _familyId = json.decode(response.body)['familyId'];
        await _storage.write(key: 'familyId', value: _familyId);
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Aileye katılma hatası: $e');
    }
    return false;
  }

  // --- AİLE PROFİLİ ---

  static Future<Map<String, dynamic>?> getFamilyInfo() async {
    if (_familyId.isEmpty) return null;
    try {
      final response = await http.get(
          Uri.parse('$baseUrl/Family/$_familyId'), headers: _headers);
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) {
      if (kDebugMode) debugPrint('Aile bilgisi çekme hatası: $e');
    }
    return null;
  }

  static Future<bool> updateFamilyInfo(
      String familyName, String babyName, DateTime? birthDate) async {
    if (_familyId.isEmpty) return false;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/Family/$_familyId'),
        headers: _headers,
        body: json.encode({
          'familyName': familyName,
          'babyName': babyName,
          'babyBirthDate': birthDate?.toIso8601String()
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('Aile bilgisi güncelleme hatası: $e');
    }
    return false;
  }

  // --- KOÇ PROGRAMI ---

  static Future<bool> saveCoachData(Map<String, dynamic> data) async {
    if (_familyId.isEmpty) return false;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/Family/$_familyId/coach-progress'),
        headers: _headers,
        body: json.encode(data),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> loadCoachData() async {
    if (_familyId.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/Family/$_familyId/coach-progress'),
        headers: _headers,
      );
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (_) {}
    return null;
  }
}
