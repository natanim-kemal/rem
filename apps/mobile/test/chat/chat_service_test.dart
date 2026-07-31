import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rem/core/services/chat_service.dart';
import 'package:rem/core/services/chat_stream_client.dart';
import 'package:rem/data/database/database.dart';

void main() {
  late AppDatabase db;
  late ChatService service;

  ChatStreamClient clientWith(MockClient mock) {
    return ChatStreamClient(
      siteUrl: 'https://test.convex.site',
      tokenProvider: () => 'token',
      client: mock,
    );
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<String> seedConversation() async {
    await db.insertItem(
      ItemsCompanion.insert(
        id: 'item_1',
        userId: 'user_1',
        type: 'link',
        title: 'Article',
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    final conversation = await db.getOrCreateConversationForItem('item_1');
    return conversation.id;
  }

  test('persists user message and streamed assistant reply', () async {
    final mock = MockClient(
      (request) async => http.Response(
        'data: {"choices":[{"delta":{"content":"An"}}]}\n\n'
        'data: {"choices":[{"delta":{"content":"swer"}}]}\n\n'
        'data: [DONE]\n\n',
        200,
      ),
    );
    service = ChatService(db: db, streamClient: clientWith(mock));

    final conversationId = await seedConversation();
    await service.sendMessage(
      conversationId: conversationId,
      itemId: 'item_1',
      text: 'Hello',
    );

    final messages = await db.getLastMessages(conversationId, limit: 10);
    expect(messages.length, 2);
    expect(messages[0].role, 'user');
    expect(messages[0].content, 'Hello');
    expect(messages[0].status, 'complete');
    expect(messages[1].role, 'assistant');
    expect(messages[1].content, 'Answer');
    expect(messages[1].status, 'complete');
    expect(service.isStreaming, isFalse);
  });

  test('marks assistant message failed on gateway error', () async {
    final mock = MockClient(
      (request) async => http.Response('{"error":"bad key"}', 401),
    );
    service = ChatService(db: db, streamClient: clientWith(mock));

    final conversationId = await seedConversation();
    await service.sendMessage(
      conversationId: conversationId,
      itemId: 'item_1',
      text: 'Hello',
    );

    final messages = await db.getLastMessages(conversationId, limit: 10);
    expect(messages[1].role, 'assistant');
    expect(messages[1].status, 'failed');
    expect(messages[1].content, contains('configuration'));
  });

  test('retryLast deletes failed message and re-streams', () async {
    final mock = MockClient(
      (request) async => http.Response(
        'data: {"choices":[{"delta":{"content":"Recovered"}}]}\n\n'
        'data: [DONE]\n\n',
        200,
      ),
    );
    service = ChatService(db: db, streamClient: clientWith(mock));

    final conversationId = await seedConversation();
    await service.sendMessage(
      conversationId: conversationId,
      itemId: 'item_1',
      text: 'Hello',
    );

    final before = await db.getLastMessages(conversationId, limit: 10);
    expect(before[1].status, 'complete');

    await db.updateMessage(before[1].id, content: 'boom', status: 'failed');
    await service.retryLast(conversationId: conversationId, itemId: 'item_1');

    final after = await db.getLastMessages(conversationId, limit: 10);
    expect(after.length, 2);
    expect(after[1].content, 'Recovered');
    expect(after[1].status, 'complete');
  });
}
