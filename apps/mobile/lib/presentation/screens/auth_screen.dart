import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: size.height - MediaQuery.paddingOf(context).top,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  _BrandingSection(theme: theme, isDark: isDark),
                  const SizedBox(height: 32),
                  _AuthCard(theme: theme, isDark: isDark),
                  const SizedBox(height: 32),
                  _FooterSection(theme: theme),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandingSection extends StatelessWidget {
  const _BrandingSection({required this.theme, required this.isDark});

  final ThemeData theme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.theme, required this.isDark});

  final ThemeData theme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E6E1),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: ClerkErrorListener(child: ClerkAuthentication()),
            ),
          ),
        )
        .animate(delay: 500.ms)
        .fadeIn(duration: 600.ms)
        .slideY(
          begin: 0.15,
          end: 0,
          duration: 600.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 32, height: 0.5, color: context.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: context.textTertiary,
              ),
            ),
            Container(width: 32, height: 0.5, color: context.divider),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Your data stays private and secure',
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.textTertiary,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ).animate(delay: 800.ms).fadeIn(duration: 500.ms);
  }
}
