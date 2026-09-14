import 'dart:math' as math;

import 'package:flutter/widgets.dart';

double bottomViewportInset(
  BuildContext context, {
  bool includeKeyboard = false,
  double extra = 0,
}) {
  final mediaQuery = MediaQuery.of(context);
  final keyboardInset = includeKeyboard ? mediaQuery.viewInsets.bottom : 0.0;
  return math.max(mediaQuery.viewPadding.bottom, keyboardInset) + extra;
}
