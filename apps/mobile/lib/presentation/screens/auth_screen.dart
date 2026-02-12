import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import '../theme/app_theme.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              Text(
                'rem',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to sync your data',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              ClerkErrorListener(child: const ClerkAuthentication()),

              const SizedBox(height: 24),

              _BenefitItem(
                icon: CupertinoIcons.cloud,
                title: 'Sync across devices',
              ),
              const SizedBox(height: 8),
              _BenefitItem(icon: CupertinoIcons.bell, title: 'Smart reminders'),
              const SizedBox(height: 8),
              _BenefitItem(
                icon: CupertinoIcons.chart_bar,
                title: 'Track progress',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _BenefitItem({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: context.textSecondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
        ),
      ],
    );
  }
}
