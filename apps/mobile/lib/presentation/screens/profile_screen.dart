import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/data_providers.dart';
import '../../data/models/notification_preferences.dart';
import '../../data/sync/sync_engine.dart';
import 'auth_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _showDailyDigestPicker(
    BuildContext context,
    NotificationPreferences preferences,
    String? userId,
    SyncEngine syncEngine,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController(text: preferences.dailyDigestTime);
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Daily Digest Time'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(controller: controller, placeholder: 'HH:MM'),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              final value = controller.text.trim();
              if (userId != null && value.isNotEmpty) {
                await syncEngine.updateNotificationPreferences(
                  userId,
                  preferences.copyWith(dailyDigestTime: value),
                );
                ref.invalidate(userByClerkIdStreamProvider(userId));
                ref
                    .read(notificationPrefsCacheProvider.notifier)
                    .set(preferences.copyWith(dailyDigestTime: value));
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDailyCapPicker(
    BuildContext context,
    NotificationPreferences preferences,
    String? userId,
    SyncEngine syncEngine,
    WidgetRef ref,
  ) async {
    int selected = preferences.maxPerDay;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 240,
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: CupertinoPicker(
                itemExtent: 36,
                scrollController: FixedExtentScrollController(
                  initialItem: selected - 1,
                ),
                onSelectedItemChanged: (index) {
                  selected = index + 1;
                },
                children: List.generate(
                  10,
                  (index) => Center(child: Text('${index + 1} per day')),
                ),
              ),
            ),
            CupertinoButton(
              child: const Text('Save'),
              onPressed: () async {
                if (userId != null) {
                  await syncEngine.updateNotificationPreferences(
                    userId,
                    preferences.copyWith(maxPerDay: selected),
                  );
                  ref.invalidate(userByClerkIdStreamProvider(userId));
                  ref
                      .read(notificationPrefsCacheProvider.notifier)
                      .set(preferences.copyWith(maxPerDay: selected));
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuietHoursPicker(
    BuildContext context,
    NotificationPreferences preferences,
    String? userId,
    SyncEngine syncEngine,
    WidgetRef ref,
  ) async {
    final startController = TextEditingController(
      text: preferences.quietHoursStart,
    );
    final endController = TextEditingController(
      text: preferences.quietHoursEnd,
    );

    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Quiet Hours'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: startController,
              placeholder: 'Start (HH:MM)',
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: endController,
              placeholder: 'End (HH:MM)',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              if (userId != null) {
                await syncEngine.updateNotificationPreferences(
                  userId,
                  preferences.copyWith(
                    quietHoursStart: startController.text.trim(),
                    quietHoursEnd: endController.text.trim(),
                  ),
                );
                ref.invalidate(userByClerkIdStreamProvider(userId));
                ref
                    .read(notificationPrefsCacheProvider.notifier)
                    .set(
                      preferences.copyWith(
                        quietHoursStart: startController.text.trim(),
                        quietHoursEnd: endController.text.trim(),
                      ),
                    );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotificationHistory(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Notification History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ref
                    .watch(notificationHistoryProvider(30))
                    .when(
                      data: (items) {
                        if (items.isEmpty) {
                          return const Center(
                            child: Text('No notifications yet'),
                          );
                        }
                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, index) => Divider(
                            height: 1,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          itemBuilder: (context, index) {
                            final item = items[index] as Map<String, dynamic>;
                            final sentAt = item['sentAt'] as int?;
                            final timestamp = sentAt != null
                                ? DateTime.fromMillisecondsSinceEpoch(sentAt)
                                : null;
                            return ListTile(
                              title: Text(item['title']?.toString() ?? ''),
                              subtitle: Text(item['body']?.toString() ?? ''),
                              trailing: timestamp != null
                                  ? Text(
                                      '${timestamp.month}/${timestamp.day}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    )
                                  : null,
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CupertinoActivityIndicator()),
                      error: (e, _) =>
                          Center(child: Text('Failed to load: $e')),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final authState = ref.read(authProvider);
    final userId = authState.userId;

    if (userId == null) {
      _showError(context, 'Please sign in to export your data');
      return;
    }

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );

    try {
      final db = ref.read(databaseProvider);
      final items = await db.getItemsByUserId(userId);
      final tags = await db.getTagsByUserId(userId);

      final exportData = {
        'exported_at': DateTime.now().toIso8601String(),
        'user_id': userId,
        'items': items
            .map(
              (item) => {
                'id': item.id,
                'title': item.title,
                'url': item.url,
                'description': item.description,
                'thumbnail_url': item.thumbnailUrl,
                'type': item.type,
                'status': item.status,
                'priority': item.priority,
                'tags': item.tags,
                'estimated_read_time': item.estimatedReadTime,
                'created_at': item.createdAt,
                'updated_at': item.updatedAt,
              },
            )
            .toList(),
        'tags': tags
            .map((tag) => {'id': tag.id, 'name': tag.name, 'color': tag.color})
            .toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      if (context.mounted) {
        Navigator.pop(context);

        await showCupertinoModalPopup(
          context: context,
          builder: (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Export Data',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Your data has been prepared. Copy it to save elsewhere.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          jsonString,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoButton.filled(
                    child: const Text('Copy to Clipboard'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: jsonString));
                      Navigator.pop(context);
                      _showSuccess(context, 'Data copied to clipboard');
                    },
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  child: const Text('Close'),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showError(context, 'Failed to export data: $e');
      }
    }
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all local data including saved items and settings. '
          'Your data on the server will not be affected. '
          'Are you sure you want to continue?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) =>
            const Center(child: CupertinoActivityIndicator()),
      );

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (context.mounted) {
          Navigator.pop(context);
          _showSuccess(context, 'Cache cleared successfully');
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          _showError(context, 'Failed to clear cache: $e');
        }
      }
    }
  }

  Future<void> _sendTestNotification(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final authState = ref.read(authProvider);
    if (authState.userId == null) {
      _showError(context, 'Please sign in first');
      return;
    }

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CupertinoActivityIndicator()),
    );

    try {
      final db = ref.read(databaseProvider);
      final user = await db.getUserByClerkId(authState.userId!);
      if (user == null) {
        if (context.mounted) {
          Navigator.pop(context);
          _showError(context, 'User not found. Try logging out and back in.');
        }
        return;
      }

      final notificationService = ref.read(notificationServiceProvider);
      final convex = ref.read(convexClientProvider);

      String? freshToken;
      try {
        freshToken = await notificationService.getFreshToken();
        if (freshToken != null) {
          convex
              .mutation('users:registerPushToken', {
                'token': freshToken,
                'platform': 'android',
              })
              .catchError((e) => debugPrint('Push token register warning: $e'));
        }
      } catch (e) {
        debugPrint('Failed to get fresh token: $e');
      }

      await convex.action('notifications:sendTestNotification', {
        'userId': user.id,
        ...?freshToken != null ? {'fcmToken': freshToken} : null,
      });

      if (context.mounted) {
        Navigator.pop(context);
        _showSuccess(context, 'Test notification sent!');
      }
    } catch (e) {
      debugPrint('Failed to send test notification: $e');
      if (context.mounted) {
        Navigator.pop(context);
        _showError(context, 'Failed to send test: $e');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeNotifier = ref.read(themeModeProvider.notifier);
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;
    final authState = ref.watch(authProvider);
    final notificationService = ref.watch(notificationServiceProvider);
    final syncEngine = ref.watch(syncEngineProvider);

    final timezoneOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    final userFuture = authState.userId != null
        ? ref.watch(userByClerkIdStreamProvider(authState.userId!))
        : const AsyncValue.data(null);

    final cachedPrefs = ref.watch(notificationPrefsCacheProvider);
    final NotificationPreferences preferences =
        cachedPrefs ??
        userFuture.when(
          data: (user) {
            if (user == null) {
              return NotificationPreferences.defaults().copyWith(
                timezoneOffsetMinutes: timezoneOffsetMinutes,
              );
            }

            try {
              final decoded =
                  jsonDecode(user.notificationPreferences)
                      as Map<String, dynamic>;
              return NotificationPreferences.fromJson(
                decoded,
              ).copyWith(timezoneOffsetMinutes: timezoneOffsetMinutes);
            } catch (_) {
              return NotificationPreferences.defaults().copyWith(
                timezoneOffsetMinutes: timezoneOffsetMinutes,
              );
            }
          },
          loading: () => NotificationPreferences.defaults().copyWith(
            timezoneOffsetMinutes: timezoneOffsetMinutes,
          ),
          error: (_, _) => NotificationPreferences.defaults().copyWith(
            timezoneOffsetMinutes: timezoneOffsetMinutes,
          ),
        );

    final gender = ref.watch(profileGenderProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'profile',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(width: 120),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  if (authState.isAuthenticated) {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (context) => CupertinoActionSheet(
                        title: Text(
                          'Signed in as ${authState.displayName}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        actions: [
                          CupertinoActionSheetAction(
                            onPressed: () {
                              ref.read(authProvider.notifier).signOut();
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Sign Out',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.orange.shade700),
                            ),
                          ),
                        ],
                        cancelButton: CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          gender == 'F'
                              ? 'assets/images/female.png'
                              : 'assets/images/male.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.divider),
                        ),
                        child: DropdownButton<String>(
                          value: gender,
                          underline: const SizedBox.shrink(),
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          icon: Icon(
                            CupertinoIcons.chevron_down,
                            color: context.textTertiary,
                            size: 14,
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            ref
                                .read(profileGenderProvider.notifier)
                                .setGender(value);
                          },
                          items: const [
                            DropdownMenuItem(value: 'M', child: Text('M')),
                            DropdownMenuItem(value: 'F', child: Text('F')),
                          ],
                        ),
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
                      value: preferences.enabled,
                      activeTrackColor: Theme.of(context).colorScheme.primary,
                      onChanged: (value) async {
                        if (value) {
                          final granted = await notificationService
                              .ensurePermissions();
                          if (!granted) return;
                        }

                        final updated = preferences.copyWith(enabled: value);

                        if (value && authState.userId != null) {
                          final token = await notificationService
                              .getFreshToken();
                          if (token != null && token.isNotEmpty) {
                            try {
                              await syncEngine.convex.mutation(
                                'users:registerPushToken',
                                {'token': token, 'platform': 'android'},
                              );
                            } catch (e) {
                              debugPrint('Failed to register push token: $e');
                            }
                          }
                        }

                        if (authState.userId != null) {
                          await syncEngine.updateNotificationPreferences(
                            authState.userId!,
                            updated,
                          );
                          ref.invalidate(
                            userByClerkIdStreamProvider(authState.userId!),
                          );
                          ref
                              .read(notificationPrefsCacheProvider.notifier)
                              .set(updated);
                        }
                      },
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
                    value: preferences.dailyDigestTime,
                    onTap: () => _showDailyDigestPicker(
                      context,
                      preferences,
                      authState.userId,
                      syncEngine,
                      ref,
                    ),
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.bell,
                    title: 'Daily Cap',
                    value: '${preferences.maxPerDay} per day',
                    onTap: () => _showDailyCapPicker(
                      context,
                      preferences,
                      authState.userId,
                      syncEngine,
                      ref,
                    ),
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.moon_zzz,
                    title: 'Quiet Hours',
                    value:
                        '${preferences.quietHoursStart} - ${preferences.quietHoursEnd}',
                    onTap: () => _showQuietHoursPicker(
                      context,
                      preferences,
                      authState.userId,
                      syncEngine,
                      ref,
                    ),
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.list_bullet,
                    title: 'Notification History',
                    onTap: () => _showNotificationHistory(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _SettingsSection(
                title: 'Data',
                children: [
                  _SettingsTile(
                    icon: CupertinoIcons.bell,
                    title: 'Test Notification',
                    trailing: GestureDetector(
                      onTap: () => _sendTestNotification(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2FBF9A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Test',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.arrow_down_circle,
                    title: 'Export Data',
                    onTap: () => _exportData(context, ref),
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.trash,
                    title: 'Clear Cache',
                    onTap: () => _clearCache(context, ref),
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
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.hand_raised,
                    title: 'Terms of Service',
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const TermsOfServiceScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Center(
                child: GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse('https://t.me/devnatanim');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2FBF9A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF2FBF9A).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.telegram,
                          color: const Color(0xFF2FBF9A),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          't.me/devnatanim',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF2FBF9A),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: context.textSecondary),
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
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      trailing:
          trailing ??
          (value != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.textSecondary,
                      ),
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
