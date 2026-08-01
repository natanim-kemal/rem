import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rem/data/database/database.dart';
import 'package:rem/presentation/screens/chat_sessions_screen.dart';
import 'package:rem/providers/auth_provider.dart';
import 'package:rem/providers/data_providers.dart';

void main() {
  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
  }

  testWidgets('shows empty state with a New Chat button', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authProvider.overrideWithBuild(
            (ref, notifier) =>
                const AuthState(isAuthenticated: true, userId: 'user_1'),
          ),
          userByClerkIdProvider.overrideWith(
            (ref, clerkId) async => User(
              id: 'user_1',
              convexId: 'convex_user_1',
              clerkId: clerkId,
              email: 'a@b.c',
              displayName: 'A',
              avatarUrl: null,
              isPremium: false,
              notificationPreferences: '{}',
              createdAt: 1,
              updatedAt: 1,
              syncStatus: 'synced',
            ),
          ),
        ],
        child: const MaterialApp(home: ChatSessionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('New Chat'), findsNWidgets(2));
    expect(find.text('Chat with your saved items'), findsOneWidget);

    await drainTimers(tester);
  });
}
