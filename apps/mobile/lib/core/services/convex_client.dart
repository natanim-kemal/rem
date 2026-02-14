import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ConvexClient {
  final String baseUrl;
  String? _authToken;

  ConvexClient({String? url}) : baseUrl = url ?? AppConfig.convexUrl;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

  Future<dynamic> query(
    String functionPath, [
    Map<String, dynamic>? args,
  ]) async {
    return _call('query', functionPath, args);
  }

  Future<dynamic> mutation(
    String functionPath, [
    Map<String, dynamic>? args,
  ]) async {
    return _call('mutation', functionPath, args);
  }

  Future<dynamic> action(
    String functionPath, [
    Map<String, dynamic>? args,
  ]) async {
    return _call('action', functionPath, args);
  }

  Future<dynamic> _call(
    String type,
    String path,
    Map<String, dynamic>? args,
  ) async {
    final uri = Uri.parse('$baseUrl/api/$type');

    final headers = <String, String>{'Content-Type': 'application/json'};

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    final body = jsonEncode({
      'path': path,
      'args': args ?? {},
      'format': 'json',
    });

    try {
      final response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return data['value'];
        } else {
          throw ConvexException(data['errorMessage'] ?? 'Unknown error');
        }
      } else {
        throw ConvexException('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (e is ConvexException) rethrow;
      throw ConvexException('Network error: $e');
    }
  }
}

class ConvexException implements Exception {
  final String message;
  ConvexException(this.message);

  @override
  String toString() => 'ConvexException: $message';
}
