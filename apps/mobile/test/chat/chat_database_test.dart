import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rem/data/database/database.dart';

void main() {
  test('creates conversation and messages and reads them back', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

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
    expect(conversation.itemId, 'item_1');

    await db.insertMessage(
      ChatMessagesCompanion.insert(
        id: 'm1',
        conversationId: conversation.id,
        role: 'user',
        content: 'Hello',
        createdAt: 1,
      ),
    );
    await db.insertMessage(
      ChatMessagesCompanion.insert(
        id: 'm2',
        conversationId: conversation.id,
        role: 'assistant',
        content: 'Hi there',
        status: const Value('complete'),
        createdAt: 2,
      ),
    );

    final messages = await db.getLastMessages(conversation.id, limit: 10);
    expect(messages.length, 2);
    expect(messages.first.role, 'user');
    expect(messages.last.content, 'Hi there');

    await db.updateMessage('m2', content: 'Updated', status: 'complete');
    final updated = await db.getLastMessage(conversation.id);
    expect(updated!.content, 'Updated');

    await db.deleteMessage('m1');
    expect(await db.getLastMessages(conversation.id, limit: 10), hasLength(1));
  });

  test('getOrCreateConversationForItem is idempotent per item', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final first = await db.getOrCreateConversationForItem('item_x');
    final second = await db.getOrCreateConversationForItem('item_x');
    expect(first.id, second.id);
  });
}
