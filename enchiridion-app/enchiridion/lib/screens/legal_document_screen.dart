import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/about_config.dart';
import '../utils/bottom_inset.dart';

enum LegalDocument {
  terms(
    title: 'Terms and Conditions',
    assetPath: 'assets/legal/terms.md',
    websiteUrl: AboutConfig.termsUrl,
  ),
  privacy(
    title: 'Privacy Policy',
    assetPath: 'assets/legal/privacy.md',
    websiteUrl: AboutConfig.privacyPolicyUrl,
  );

  const LegalDocument({
    required this.title,
    required this.assetPath,
    required this.websiteUrl,
  });

  final String title;
  final String assetPath;
  final String websiteUrl;

  static LegalDocument? fromWebsiteUrl(String url) {
    for (final document in values) {
      if (document.websiteUrl == url) return document;
    }
    return null;
  }
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  static Future<void> open(BuildContext context, LegalDocument document) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  Future<void> _handleLinkTap(BuildContext context, String? href) async {
    if (href == null) return;
    final linkedDocument = LegalDocument.fromWebsiteUrl(href);
    if (linkedDocument != null) {
      await LegalDocumentScreen.open(context, linkedDocument);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(href),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: href));
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
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(document.assetPath),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load this document.'));
          }
          final markdown = snapshot.data;
          if (markdown == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Markdown(
            data: markdown,
            selectable: true,
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24 + bottomViewportInset(context),
            ),
            onTapLink: (text, href, title) => _handleLinkTap(context, href),
          );
        },
      ),
    );
  }
}
