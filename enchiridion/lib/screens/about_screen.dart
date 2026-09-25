import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/about_config.dart';
import '../utils/bottom_inset.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static Uri _asUri(String url) {
    if (url.startsWith(RegExp(r'https?://|mailto:'))) return Uri.parse(url);
    if (url.contains('@') && !url.contains(' ')) {
      return Uri.parse('mailto:$url');
    }
    return Uri.parse('https://$url');
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    bool opened = false;
    try {
      opened = await launchUrl(
        _asUri(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: url));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About Enchiridion')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + bottomViewportInset(context),
        ),
        children: [
          const _Section(
            title: 'About the App',
            child: Text(AboutConfig.aboutAppBlurb),
          ),
          _Section(
            title: 'About the Author',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AboutConfig.authorName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _EmailRow(
                  email: AboutConfig.authorEmail,
                  onOpen: () => _openLink(context, AboutConfig.authorEmail),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Co-Author',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AboutConfig.coAuthorName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _Section(
            title: 'App Developer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AboutConfig.appDeveloperName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _EmailRow(
                  email: AboutConfig.developerEmail,
                  onOpen: () => _openLink(context, AboutConfig.developerEmail),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Get a Physical Copy',
            child: _LinkRow(
              url: AboutConfig.physicalCopyUrl,
              label: 'Order the print edition',
              icon: Icons.menu_book_outlined,
              onOpen: () => _openLink(context, AboutConfig.physicalCopyUrl),
            ),
          ),
          _Section(
            title: 'Website',
            child: _LinkRow(
              url: AboutConfig.websiteUrl,
              label: 'Visit the website',
              icon: Icons.language_outlined,
              onOpen: () => _openLink(context, AboutConfig.websiteUrl),
            ),
          ),
          _Section(
            title: 'Legal',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LinkRow(
                  url: AboutConfig.termsUrl,
                  label: 'Terms and Conditions',
                  icon: Icons.gavel_outlined,
                  onOpen: () => _openLink(context, AboutConfig.termsUrl),
                ),
                const SizedBox(height: 16),
                _LinkRow(
                  url: AboutConfig.privacyPolicyUrl,
                  label: 'Privacy Policy',
                  icon: Icons.privacy_tip_outlined,
                  onOpen: () => _openLink(context, AboutConfig.privacyPolicyUrl),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Copyright & Data Protection',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(AboutConfig.copyrightNotice),
                const SizedBox(height: 8),
                const Text(
                  'Your account holds your email address, display name, role, '
                  'and profile photo. Your study activity — answers, review '
                  'progress, points, and statistics — is stored on your device '
                  'and, when you are signed in, synced to your account so it '
                  'follows you across devices. Your reading notes, pinned '
                  'notes, bookmarks, clips, and reading settings sync too, '
                  'so moving to a new device loses nothing. Payments are '
                  'processed on our website; Enchiridion never sees or stores '
                  'your card or bank details.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'You may request a copy, correction, or deletion of your '
                  'personal data at any time. Deleting your account removes '
                  'your profile, study records, and access entitlements.',
                ),
                const SizedBox(height: 8),
                Text(
                  'Data-protection contact: ${AboutConfig.contactEmail}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _EmailRow extends StatelessWidget {
  final String email;
  final VoidCallback onOpen;

  const _EmailRow({required this.email, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.email_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String url;
  final String label;
  final IconData icon;
  final VoidCallback onOpen;

  const _LinkRow({
    required this.url,
    required this.label,
    required this.icon,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(url, style: theme.textTheme.bodySmall),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onOpen,
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
      ],
    );
  }
}
