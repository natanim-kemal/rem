import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Policy for rem',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Last updated: February 2026',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                '1. Information We Collect',
                '''We collect the following information when you use rem:

• Account Information: Your name, email address, and authentication details through Clerk.
• Content Data: Articles, links, images, videos, books, and notes you save to your vault.
• Usage Data: Reading progress, tags, and organizational preferences.
• Device Information: Device type, operating system, and app version for debugging.
• Notification Preferences: Your preferred notification settings and timezone.''',
              ),
              _buildSection(
                context,
                '2. How We Use Your Information',
                '''We use your information to:

• Provide the core read-later and content organization service.
• Sync your data across devices you own.
• Send notifications about saved items (if enabled).
• Generate reading statistics and insights.
• Improve app performance and fix bugs.''',
              ),
              _buildSection(
                context,
                '3. Data Storage & Security',
                '''• Your data is stored securely using Convex and Firebase infrastructure.
• We use industry-standard encryption for data in transit and at rest.
• Your content is associated with your account and not shared with other users.
• We do not sell your personal information to third parties.''',
              ),
              _buildSection(
                context,
                '4. Third-Party Services',
                '''rem uses the following third-party services:

• Clerk: For authentication and account management.
• Convex: For data storage and synchronization.
• Firebase: For push notifications and analytics.
• Google Fonts: For typography (DM Sans).''',
              ),
              _buildSection(context, '5. Your Rights', '''You have the right to:

• Export your data at any time from the Profile screen.
• Delete your account and all associated data.
• Modify your notification preferences.
• Request information about your stored data.'''),
              _buildSection(
                context,
                '6. Data Retention',
                '''• We retain your data as long as you maintain an active account.
• Deleted items are permanently removed from our servers.
• You can request complete account deletion at any time.''',
              ),
              _buildSection(
                context,
                '7. Contact Us',
                '''If you have questions about this Privacy Policy, please contact us through our Telegram channel: t.me/devnatanim''',
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
