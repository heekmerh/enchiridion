import 'package:flutter/material.dart';

/// Splits [text] on the `**bold**` markers generated content uses for the
/// source's own emphasis, returning spans styled from [base].
List<TextSpan> emphasisSpans(String text, TextStyle base) {
  final spans = <TextSpan>[];
  final parts = text.split('**');
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].isEmpty) continue;
    final bold = i.isOdd && i < parts.length - 1;
    spans.add(TextSpan(
      text: bold || i.isEven ? parts[i] : '**${parts[i]}',
      style: bold ? base.copyWith(fontWeight: FontWeight.w700) : base,
    ));
  }
  return spans;
}

/// A [Text.rich] of [text] with its `**bold**` emphasis applied.
class EmphasisText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const EmphasisText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(children: emphasisSpans(text, style)));
  }
}
