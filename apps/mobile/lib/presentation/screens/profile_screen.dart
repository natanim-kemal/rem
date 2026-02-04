import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import 'auth_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeNotifier = ref.read(themeModeProvider.notifier);
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 24),

              GestureDetector(
                onTap: () {
                  if (authState.isAuthenticated) {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (context) => CupertinoActionSheet(
                        title: Text('Signed in as ${authState.displayName}'),
                        actions: [
                          CupertinoActionSheetAction(
                            isDestructiveAction: true,
                            onPressed: () {
                              ref.read(authProvider.notifier).signOut();
                              Navigator.pop(context);
                            },
                            child: const Text('Sign Out'),
                          ),
                        ],
                        cancelButton: CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      if (authState.isAuthenticated &&
                          authState.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: CachedNetworkImage(
                            imageUrl: authState.imageUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => CircleAvatar(
                              radius: 32,
                              backgroundColor: context.textTertiary,
                              child: const CupertinoActivityIndicator(),
                            ),
                          ),
                        )
                      else
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: context.textTertiary,
                          child: const Icon(
                            CupertinoIcons.person_fill,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authState.isAuthenticated
                                  ? authState.displayName
                                  : 'Sign in',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              authState.isAuthenticated
                                  ? authState.email ?? 'Synced'
                                  : 'Sync your data across devices',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chevron_right,
                        color: context.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              _SettingsSection(
                title: 'Preferences',
                children: [
                  _SettingsTile(
                    icon: CupertinoIcons.bell,
                    title: 'Notifications',
                    trailing: CupertinoSwitch(
                      value: true,
                      activeTrackColor: Theme.of(context).colorScheme.primary,
                      onChanged: (value) {},
                    ),
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.moon,
                    title: 'Dark Mode',
                    trailing: CupertinoSwitch(
                      value: isDarkMode,
                      activeTrackColor: Theme.of(context).colorScheme.primary,
                      onChanged: (value) {
                        themeNotifier.toggleTheme();
                      },
                    ),
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.clock,
                    title: 'Daily Digest',
                    value: '9:00 AM',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _SettingsSection(
                title: 'Data',
                children: [
                  _SettingsTile(
                    icon: CupertinoIcons.arrow_down_circle,
                    title: 'Export Data',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.trash,
                    title: 'Clear Cache',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _SettingsSection(
                title: 'About',
                children: [
                  _SettingsTile(
                    icon: CupertinoIcons.info_circle,
                    title: 'Version',
                    value: '1.0.0',
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.doc_text,
                    title: 'Privacy Policy',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.hand_raised,
                    title: 'Terms of Service',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(height: 1, indent: 52, color: context.divider),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title),
      trailing:
          trailing ??
          (value != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value!,
                      style: TextStyle(color: context.textSecondary),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: context.textTertiary,
                      ),
                    ],
                  ],
                )
              : onTap != null
              ? Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: context.textTertiary,
                )
              : null),
      onTap: onTap,
    );
  }
}
