import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'presentation/screens/shell_screen.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/data_providers.dart';
import 'core/config/app_config.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(ProviderScope(child: RemApp()));
}

class RemApp extends ConsumerWidget {
  const RemApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return ClerkAuth(
      config: ClerkAuthConfig(publishableKey: AppConfig.clerkPublishableKey),
      child: MaterialApp(
        title: 'rem',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: const _AuthStateSync(),
      ),
    );
  }
}

class _AuthStateSync extends ConsumerStatefulWidget {
  const _AuthStateSync();

  @override
  ConsumerState<_AuthStateSync> createState() => _AuthStateSyncState();
}

class _AuthStateSyncState extends ConsumerState<_AuthStateSync> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.initialize();
    _notificationService.onAction = _handleNotificationAction;
  }

  void _handleNotificationAction(String? payload) {
    if (payload == null) return;

    debugPrint('Notification action: $payload');

    final params = Uri.splitQueryString(payload);
    final itemId = params['itemId'];
    final action = params['action'];

    if (itemId == null) return;

    switch (action) {
      case 'mark_read':
        _handleMarkRead(itemId);
        break;
      case 'snooze_30':
        _handleSnooze(itemId);
        break;
      case 'lower_priority':
        _handleLowerPriority(itemId);
        break;
      case 'open_unread_list':
        break;
    }
  }

  void _handleMarkRead(String itemId) async {
    try {
      final syncEngine = ref.read(syncEngineProvider);
      await syncEngine.updateItemStatus(itemId, 'read');
    } catch (e) {
      debugPrint('Error marking item as read: $e');
    }
  }

  void _handleSnooze(String itemId) async {
    try {
      final syncEngine = ref.read(syncEngineProvider);
      await syncEngine.snoozeItem(itemId, const Duration(minutes: 30));
      _notificationService.snoozeNotification(minutes: 30, itemId: itemId);
    } catch (e) {
      debugPrint('Error snoozing item: $e');
    }
  }

  void _handleLowerPriority(String itemId) async {
    try {
      final syncEngine = ref.read(syncEngineProvider);
      await syncEngine.updateItemPriority(itemId, 'low');
    } catch (e) {
      debugPrint('Error lowering priority: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClerkAuthBuilder(
      signedInBuilder: (context, authState) {
        _syncAuthState(context);
        return const ShellScreen();
      },
      signedOutBuilder: (context, authState) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final currentState = ref.read(authProvider);
          if (currentState.isAuthenticated) {
            ref.read(authProvider.notifier).signOut();
          }
        });
        return const AuthScreen();
      },
    );
  }

  void _syncAuthState(BuildContext context) {
    final clerkAuth = ClerkAuth.of(context, listen: false);
    final user = clerkAuth.user;

    if (user != null) {
      clerkAuth
          .sessionToken(templateName: 'convex')
          .then((sessionToken) {
            final token = sessionToken.jwt;
            final currentState = ref.read(authProvider);
            if (!currentState.isAuthenticated ||
                currentState.userId != user.id) {
              ref
                  .read(authProvider.notifier)
                  .setAuthFromClerk(
                    userId: user.id,
                    token: token,
                    email: user.email,
                    firstName: user.firstName,
                    lastName: user.lastName,
                    imageUrl: user.imageUrl,
                  );
            }
          })
          .catchError((e) {
            debugPrint('Error getting Convex token: $e');
            final currentState = ref.read(authProvider);
            if (!currentState.isAuthenticated ||
                currentState.userId != user.id) {
              ref
                  .read(authProvider.notifier)
                  .setAuthFromClerk(
                    userId: user.id,
                    token: '',
                    email: user.email,
                    firstName: user.firstName,
                    lastName: user.lastName,
                    imageUrl: user.imageUrl,
                  );
            }
          });
    }
  }
}
