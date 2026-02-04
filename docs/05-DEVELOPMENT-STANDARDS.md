# REM - Development Standards

> Code style, testing, and development practices for the REM application (Flutter + Convex)

---

## 1. Flutter/Dart Code Style

### Formatting

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    missing_required_param: error
    missing_return: error
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - avoid_print
    - avoid_type_to_string
    - cancel_subscriptions
    - close_sinks
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_locals
    - require_trailing_commas
    - sort_constructors_first
    - unawaited_futures
    - use_key_in_widget_constructors
```

### Auto-format on Save
```bash
# Run format
dart format .

# Check format (CI)
dart format --set-exit-if-changed .
```

---

## 2. Naming Conventions

### Dart Naming

| Type | Convention | Example |
|------|------------|---------|
| Classes | PascalCase | `ItemRepository` |
| Extensions | PascalCase | `StringExtension` |
| Functions/Methods | camelCase | `fetchItems()` |
| Variables | camelCase | `itemCount` |
| Constants | camelCase | `defaultTimeout` |
| Private | Prefix `_` | `_privateMethod()` |
| Files | snake_case | `item_repository.dart` |
| Folders | snake_case | `data_sources/` |

### Widget Naming

```dart
// ✅ Good
class ItemCard extends StatelessWidget { }
class ItemListView extends StatelessWidget { }
class AddItemDialog extends StatelessWidget { }

// ❌ Bad
class ItemWidget extends StatelessWidget { }
class AddItem extends StatelessWidget { }
```

### Provider Naming (Riverpod)

```dart
// ✅ Good
@riverpod
class ItemsNotifier extends _$ItemsNotifier { }

// Auto-generated: itemsNotifierProvider

@riverpod
Future<List<Item>> filteredItems(FilteredItemsRef ref) { }

// Auto-generated: filteredItemsProvider
```

---

## 3. Project Structure

### Clean Architecture Layers

```
lib/
├── core/              # Shared utilities, no business logic
│   ├── config/        # Environment, constants
│   ├── errors/        # Custom exceptions
│   ├── network/       # HTTP client, interceptors
│   └── utils/         # Helper functions
│
├── data/              # Data layer (repositories impl, DTOs)
│   ├── models/        # Data models (with JSON serialization)
│   ├── repositories/  # Repository implementations
│   └── services/      # External service clients (Convex)
│
├── domain/            # Business logic (pure Dart)
│   ├── entities/      # Domain entities
│   ├── repositories/  # Repository interfaces
│   └── usecases/      # Use cases (optional)
│
├── presentation/      # UI layer
│   ├── providers/     # Riverpod providers
│   ├── screens/       # Full page widgets
│   ├── widgets/       # Reusable components
│   └── theme/         # Colors, typography, themes
│
└── l10n/              # Localization
```

---

## 4. Data Models with Freezed

```dart
// lib/data/models/item.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'item.freezed.dart';
part 'item.g.dart';

@freezed
class Item with _$Item {
  const factory Item({
    required String id,
    required String title,
    String? url,
    @Default(ItemStatus.unread) ItemStatus status,
    @Default(Priority.medium) Priority priority,
    @Default([]) List<String> tags,
    required DateTime createdAt,
  }) = _Item;

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
}

@JsonEnum()
enum ItemStatus { unread, inProgress, read, archived }

@JsonEnum()
enum Priority { high, medium, low }
```

---

## 5. State Management (Riverpod)

### Provider Pattern

```dart
// lib/presentation/providers/items_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'items_provider.g.dart';

// Async notifier for CRUD operations
@riverpod
class ItemsNotifier extends _$ItemsNotifier {
  @override
  Future<List<Item>> build() async {
    return ref.read(itemRepositoryProvider).getItems();
  }

  Future<void> addItem(CreateItemRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(itemRepositoryProvider).createItem(request);
      return ref.read(itemRepositoryProvider).getItems();
    });
  }
}

// Simple state provider
@riverpod
class ItemFilter extends _$ItemFilter {
  @override
  ItemStatus? build() => null;

  void setFilter(ItemStatus? value) => state = value;
}
```

### UI Consumption

```dart
// lib/presentation/screens/home_screen.dart
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemsNotifierProvider);

    return itemsAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => ErrorWidget(error: e),
      data: (items) => ItemListView(items: items),
    );
  }
}
```

---

## 6. Testing Strategy

### Test Pyramid

```
        ┌─────────┐
        │   E2E   │  ← 10%: Full app flows
        ├─────────┤
        │  Widget │  ← 30%: Component tests
        ├─────────┤
        │  Unit   │  ← 60%: Logic tests
        └─────────┘
```

### Unit Tests

```dart
// test/data/repositories/item_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConvexClient extends Mock implements ConvexClient {}

void main() {
  late ItemRepository repository;
  late MockConvexClient mockClient;

  setUp(() {
    mockClient = MockConvexClient();
    repository = ItemRepositoryImpl(client: mockClient);
  });

  group('getItems', () {
    test('returns list of items on success', () async {
      when(() => mockClient.getItems()).thenAnswer(
        (_) async => [testItem],
      );

      final result = await repository.getItems();

      expect(result, [testItem]);
      verify(() => mockClient.getItems()).called(1);
    });
  });
}
```

### Widget Tests

```dart
// test/presentation/widgets/item_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ItemCard displays title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ItemCard(item: testItem),
      ),
    );

    expect(find.text('Test Item'), findsOneWidget);
  });

  testWidgets('ItemCard calls onTap when pressed', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ItemCard(
          item: testItem,
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(ItemCard));
    expect(tapped, isTrue);
  });
}
```

### Integration Tests

```dart
// integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full add item flow', (tester) async {
    await tester.pumpWidget(const RemApp());
    await tester.pumpAndSettle();

    // Tap add button
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Enter title
    await tester.enterText(find.byType(TextField), 'New Item');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify item appears
    expect(find.text('New Item'), findsOneWidget);
  });
}
```

### Coverage

```bash
# Run tests with coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# CI threshold: 70%
```

---

## 7. Git Conventions

### Branch Naming

```
feature/add-item-dialog
fix/notification-not-showing
refactor/improve-item-card
docs/update-readme
```

### Commit Messages (Conventional Commits)

```
feat(items): add swipe to archive gesture
fix(auth): handle token expiration
refactor(providers): migrate to riverpod 2.0
test(item_card): add widget tests
docs(readme): update setup instructions
chore(deps): bump flutter version
```

### Pull Request Template

```markdown
<!-- .github/PULL_REQUEST_TEMPLATE.md -->
## Summary

## Type
- [ ] ✨ Feature
- [ ] 🐛 Bug fix
- [ ] ♻️ Refactor
- [ ] 📝 Documentation

## Screenshots (if UI change)

## Testing
- [ ] Unit tests added/updated
- [ ] Widget tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] `dart analyze` passes
- [ ] `flutter test` passes
```

---

## 8. Error Handling

### Custom Exceptions

```dart
// lib/core/errors/app_exceptions.dart
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Network error']);
}

class AuthException extends AppException {
  const AuthException([super.message = 'Authentication error']);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}
```

### Result Type (Optional)

```dart
// Using fpdart for functional programming
import 'package:fpdart/fpdart.dart';

typedef AppResult<T> = Either<AppException, T>;

class ItemRepository {
  Future<AppResult<List<Item>>> getItems() async {
    try {
      final items = await client.getItems();
      return Right(items);
    } on DioException catch (e) {
      return Left(NetworkException(e.message ?? 'Unknown error'));
    }
  }
}
```

---

## 9. Performance Guidelines

### Widget Optimization

```dart
// ✅ Use const constructors
const SizedBox(height: 16);
const Text('Hello');

// ✅ Extract static widgets
class _StaticHeader extends StatelessWidget {
  const _StaticHeader();
  
  @override
  Widget build(BuildContext context) => const Text('Header');
}

// ✅ Use equatable for models (freezed does this automatically)
@freezed
class Item with _$Item { ... }
```

### List Performance

```dart
// ✅ Use ListView.builder for large lists
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemCard(item: items[index]),
);

// ✅ Add itemExtent for fixed-height items
ListView.builder(
  itemCount: items.length,
  itemExtent: 80,
  itemBuilder: (context, index) => ItemCard(item: items[index]),
);
```

### Image Caching

```dart
// ✅ Use cached_network_image
CachedNetworkImage(
  imageUrl: item.thumbnailUrl,
  placeholder: (_, __) => const Shimmer(),
  errorWidget: (_, __, ___) => const Icon(Icons.error),
);
```

---

## 10. Convex (TypeScript) Standards

```typescript
// convex/items.ts

// ✅ Use validators for all args
export const createItem = mutation({
  args: {
    title: v.string(),
    url: v.optional(v.string()),
    type: v.union(v.literal("link"), v.literal("image")),
  },
  handler: async (ctx, args) => {
    // ✅ Always check auth
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthenticated");
    
    // ✅ Validate input
    if (args.title.length > 500) {
      throw new Error("Title too long");
    }
    
    // ✅ Use transactions
    return await ctx.db.insert("items", { ... });
  },
});
```

---

*Document Version: 3.0 (Flutter + Convex)*  
*Last Updated: 2026-02-03*
