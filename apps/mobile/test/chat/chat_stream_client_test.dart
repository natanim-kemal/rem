import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rem/core/services/chat_stream_client.dart';

void main() {
  ChatStreamClient clientWith(MockClient mock) {
    return ChatStreamClient(
      siteUrl: 'https://test.convex.site',
      tokenProvider: () => 'token',
      client: mock,
    );
  }

  test('sends auth header and parses SSE content tokens', () async {
    final mock = MockClient((request) async {
      expect(request.url.toString(), 'https://test.convex.site/chat/stream');
      expect(request.headers['Authorization'], 'Bearer token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['itemId'], 'item_1');
      const sse =
          'data: {"choices":[{"delta":{"content":"Hel"}}]}\n\n'
          'data: {"choices":[{"delta":{"content":"lo"}}]}\n\n'
          'data: [DONE]\n\n';
      return http.Response(sse, 200);
    });

    final result = await clientWith(
      mock,
    ).streamCompletions(itemId: 'item_1', history: const []);
    expect(result.statusCode, 200);
    expect(await result.tokens.toList(), ['Hel', 'lo']);
  });

  test('maps gateway 401 to a friendly message', () async {
    final mock = MockClient(
      (request) async => http.Response('{"error":"bad key"}', 401),
    );
    final result = await clientWith(
      mock,
    ).streamCompletions(itemId: 'item_1', history: const []);
    expect(result.statusCode, 401);
    expect(result.errorMessage, contains('configuration'));
  });

  test('surfaces a friendly message when offline', () async {
    final mock = MockClient(
      (request) async => throw Exception('connection refused'),
    );
    final result = await clientWith(
      mock,
    ).streamCompletions(itemId: 'item_1', history: const []);
    expect(result.statusCode, 0);
    expect(result.errorMessage, contains('internet'));
  });
}
