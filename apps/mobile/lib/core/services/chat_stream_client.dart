import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatStreamResult {
  final int statusCode;
  final String? errorMessage;
  final Stream<String> tokens;

  const ChatStreamResult({
    required this.statusCode,
    this.errorMessage,
    this.tokens = const Stream.empty(),
  });
}

class ChatStreamClient {
  final String siteUrl;
  final String? Function() tokenProvider;
  final http.Client _client;

  ChatStreamClient({
    required this.siteUrl,
    required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<ChatStreamResult> streamCompletions({
    required String itemId,
    required List<Map<String, String>> history,
    String? modelId,
    bool webSearch = false,
  }) async {
    final token = tokenProvider();
    if (token == null || token.isEmpty) {
      return const ChatStreamResult(
        statusCode: 401,
        errorMessage: 'You are not signed in.',
      );
    }

    final uri = Uri.parse('$siteUrl/chat/stream');
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token'
      ..body = jsonEncode({
        'itemId': itemId,
        'history': history,
        if (modelId != null && modelId.isNotEmpty) 'modelId': modelId,
        'webSearch': webSearch,
      });

    final http.StreamedResponse response;
    try {
      response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      return const ChatStreamResult(
        statusCode: 0,
        errorMessage:
            'No internet connection. Check your network and try again.',
      );
    }

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      return ChatStreamResult(
        statusCode: response.statusCode,
        errorMessage: _mapError(response.statusCode, body),
      );
    }

    final tokenStream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .expand(_tokensFromLine);
    return ChatStreamResult(statusCode: 200, tokens: tokenStream);
  }

  List<String> _tokensFromLine(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('data:')) return const [];
    final payload = trimmed.substring(5).trim();
    if (payload.isEmpty || payload == '[DONE]') return const [];
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) return const [];
      final first = choices.first as Map<String, dynamic>;
      final delta = first['delta'] as Map<String, dynamic>?;
      final content = delta?['content'] ?? first['text'];
      if (content is! String || content.isEmpty) return const [];
      return [content];
    } catch (_) {
      return const [];
    }
  }

  String _mapError(int statusCode, String body) {
    String? serverError;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        serverError = decoded['error'] as String;
      }
    } catch (_) {}
    switch (statusCode) {
      case 401:
        return 'Chat service configuration error. Please try again later.';
      case 429:
        return serverError ?? 'Too many active chats. Try again in a moment.';
      case 404:
        return serverError ??
            'This item is not available for chat yet. Sync the app and try again.';
      case 503:
        return serverError ?? 'Chat is not configured yet.';
      default:
        return serverError ?? 'Chat failed (HTTP $statusCode). Try again.';
    }
  }
}
