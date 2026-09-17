import 'package:flutter/material.dart';

/// Renders plain clinical text with meaningful line breaks and bullets.
/// A Markdown parser could silently consume stray emphasis characters in drug
/// names or formulas, so the source text is kept literal.
class ExplanationText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const ExplanationText({super.key, required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    final content = text.trim();
    if (content.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    final paragraphs = content.split(RegExp(r'\n{2,}'));
    final bulletPattern = RegExp(r'^\s*[-•–]\s+(.+)$');

    for (final paragraph in paragraphs) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      final plainLines = <String>[];
      var previousWasBullet = false;

      void flushPlainLines() {
        if (plainLines.isEmpty) return;
        children.add(Text(plainLines.join('\n'), style: style));
        plainLines.clear();
      }

      for (final line in paragraph.split('\n')) {
        final bullet = bulletPattern.firstMatch(line);
        if (bullet == null) {
          plainLines.add(line);
          previousWasBullet = false;
          continue;
        }

        flushPlainLines();
        if (previousWasBullet) children.add(const SizedBox(height: 4));
        children.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 18, child: Text('•', style: style)),
            Expanded(child: Text(bullet.group(1)!, style: style)),
          ],
        ));
        previousWasBullet = true;
      }
      flushPlainLines();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
