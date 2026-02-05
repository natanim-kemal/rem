import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'presentation/screens/shell_screen.dart';
import 'presentation/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(ProviderScope(child: const RemApp()));
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

class _AuthStateSync extends ConsumerWidget {
  const _AuthStateSync();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClerkAuthBuilder(
      signedInBuilder: (context, authState) {
        _syncAuthState(context, ref);
        return const ShellScreen();
      },
      signedOutBuilder: (context, authState) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final currentState = ref.read(authProvider);
          if (currentState.isAuthenticated) {
            ref.read(authProvider.notifier).signOut();
          }
        });
        return const ShellScreen();
      },
    );
  }

  void _syncAuthState(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final clerkAuth = ClerkAuth.of(context, listen: false);
      final user = clerkAuth.user;

      if (user != null) {
        String? token;
        try {
          final sessionToken = await clerkAuth.sessionToken(
            templateName: 'convex',
          );
          token = sessionToken.jwt;
        } catch (e) {
          debugPrint('Error getting Convex token: $e');
        }

        final currentState = ref.read(authProvider);
        if (!currentState.isAuthenticated || currentState.userId != user.id) {
          ref
              .read(authProvider.notifier)
              .setAuthFromClerk(
                userId: user.id,
                token: token ?? '',
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                imageUrl: user.imageUrl,
              );
        }
      }
    });
  }
}
