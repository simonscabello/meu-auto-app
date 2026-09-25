import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Fails when any text on screen broke its lines badly: a word cut in two
/// ("Consum / o"), or a line holding one or two characters on their own
/// ("37,65 / L").
///
/// A layout test only proves nothing overflowed; these are the breaks a
/// person actually saw on a 360dp phone while every overflow test passed.
void expectCleanLineBreaks(WidgetTester tester) {
  final problems = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
    // The render object keeps its painter private; an identical one laid
    // out at the width it was given breaks at the same places.
    final painter = TextPainter(
      text: paragraph.text,
      textAlign: paragraph.textAlign,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      maxLines: paragraph.maxLines,
      locale: paragraph.locale,
      strutStyle: paragraph.strutStyle,
      textWidthBasis: paragraph.textWidthBasis,
      textHeightBehavior: paragraph.textHeightBehavior,
    )..layout(maxWidth: paragraph.constraints.maxWidth);
    final lines = painter.computeLineMetrics();
    if (lines.length < 2) {
      painter.dispose();
      continue;
    }
    final text = paragraph.text.toPlainText(includePlaceholders: false);

    final starts = [
      for (final line in lines)
        painter
            .getPositionForOffset(
              Offset(line.left + 1, line.baseline - line.ascent / 2),
            )
            .offset,
    ];
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i];
      final end = i + 1 < starts.length ? starts[i + 1] : text.length;
      if (start < 0 || start > text.length || end < start) continue;
      if (i > 0 && start > 0 && start < text.length) {
        final before = text[start - 1];
        final after = text[start];
        if (_wordChar.hasMatch(before) && _wordChar.hasMatch(after)) {
          problems.add('word cut in "$text" at ${start - 1}|$start');
        }
      }
      final content = text.substring(start, end).replaceAll(' ', ' ').trim();
      if (content.isNotEmpty && content.length <= 2) {
        problems.add('"$content" alone on a line of "$text"');
      }
    }
    painter.dispose();
  }
  expect(problems, isEmpty, reason: problems.join('\n'));
}
