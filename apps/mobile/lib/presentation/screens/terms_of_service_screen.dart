import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Terms of Service',
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
                'Terms of Service for rem',
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
                '1. Acceptance of Terms',
                '''By using rem, you agree to these Terms of Service. If you do not agree, please do not use the app. We reserve the right to modify these terms at any time, and will notify users of significant changes.''',
              ),
              _buildSection(
                context,
                '2. Description of Service',
                '''rem is a read-later and content organization app that allows you to:

• Save articles, links, images, videos, books, and notes.
• Organize content with tags and priority levels.
• Track reading progress and statistics.
• Receive notifications about saved items.
• Sync data across multiple devices.''',
              ),
              _buildSection(
                context,
                '3. User Accounts',
                '''• You must create an account to use rem.
• You are responsible for maintaining the confidentiality of your account credentials.
• You must provide accurate and complete information when creating an account.
• You may not use another person's account without permission.''',
              ),
              _buildSection(
                context,
                '4. Acceptable Use',
                '''You agree not to use rem to:

• Store or share illegal, harmful, or infringing content.
• Attempt to gain unauthorized access to the service.
• Interfere with other users' access to the service.
• Use automated systems to access the service without permission.
• Upload viruses or malicious code.''',
              ),
              _buildSection(
                context,
                '5. Content Ownership',
                '''• You retain ownership of all content you save to rem.
• By using the service, you grant us a license to store and process your content solely for the purpose of providing the service.
• We do not claim ownership of your saved articles, notes, or other content.''',
              ),
              _buildSection(
                context,
                '6. Service Availability',
                '''• We strive to maintain 99% uptime but do not guarantee uninterrupted service.
• We may perform maintenance that temporarily disrupts service.
• We reserve the right to modify or discontinue features with reasonable notice.''',
              ),
              _buildSection(
                context,
                '7. Limitation of Liability',
                '''• rem is provided "as is" without warranties of any kind.
• We are not liable for any loss of data, though we maintain backups.
• Our total liability is limited to the amount you paid for the service (which is currently free).''',
              ),
              _buildSection(
                context,
                '8. Termination',
                '''• You may delete your account at any time.
• We may suspend or terminate accounts that violate these terms.
• Upon termination, your data will be deleted within 30 days.''',
              ),
              _buildSection(
                context,
                '9. Governing Law',
                '''These terms are governed by the laws of your jurisdiction. Any disputes will be resolved through arbitration or in the courts of your jurisdiction.''',
              ),
              _buildSection(
                context,
                '10. Contact',
                '''For questions about these Terms of Service, contact us through our Telegram channel: t.me/devnatanim''',
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
