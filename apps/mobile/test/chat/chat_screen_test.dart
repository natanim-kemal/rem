import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rem/core/services/chat_service.dart';
import 'package:rem/core/services/chat_stream_client.dart';
import 'package:rem/data/database/database.dart';
import 'package:rem/presentation/screens/chat_screen.dart';
import 'package:rem/providers/chat_providers.dart';
import 'package:rem/providers/data_providers.dart';

void main() {
  Future<AppDatabase> buildDb() async {
    final db = AppDatabase(NativeDatabase.memory());
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
    return db;
  }

  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
  }

  testWidgets('sends a message and renders the reply', (tester) async {
    final db = await buildDb();
    addTearDown(db.close);

    final mock = MockClient(
      (request) async => http.Response(
        'data: {"choices":[{"delta":{"content":"Reply"}}]}\n\n'
        'data: [DONE]\n\n',
        200,
      ),
    );
    final service = ChatService(
      db: db,
      streamClient: ChatStreamClient(
        siteUrl: 'https://test.convex.site',
        tokenProvider: () => 'token',
        client: mock,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          chatServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
          home: ChatScreen(item: {'id': 'item_1', 'title': 'Article'}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoTextField), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField), 'Hello');
    await tester.tap(find.byIcon(CupertinoIcons.arrow_up));
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Reply'), findsOneWidget);

    await drainTimers(tester);
  });

  testWidgets('shows a failed bubble with retry on gateway error', (
    tester,
  ) async {
    final db = await buildDb();
    addTearDown(db.close);

    final mock = MockClient(
      (request) async => http.Response('{"error":"bad key"}', 401),
    );
    final service = ChatService(
      db: db,
      streamClient: ChatStreamClient(
        siteUrl: 'https://test.convex.site',
        tokenProvider: () => 'token',
        client: mock,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          chatServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
          home: ChatScreen(item: {'id': 'item_1', 'title': 'Article'}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(CupertinoTextField), 'Hello');
    await tester.tap(find.byIcon(CupertinoIcons.arrow_up));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);

    await drainTimers(tester);
  });
}
