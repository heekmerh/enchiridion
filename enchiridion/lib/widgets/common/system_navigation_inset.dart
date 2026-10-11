import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SystemNavigationInset extends StatelessWidget {
  const SystemNavigationInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final navigationBarHeight = mediaQuery.viewPadding.bottom;
    final keyboardAboveNavigationBar = math.max(
      0.0,
      mediaQuery.viewInsets.bottom - navigationBarHeight,
    );
    final navigationIconBrightness = theme.brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: navigationIconBrightness,
      ),
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Padding(
          padding: EdgeInsets.only(bottom: navigationBarHeight),
          child: MediaQuery(
            data: mediaQuery.copyWith(
              padding: mediaQuery.padding.copyWith(bottom: 0),
              viewPadding: mediaQuery.viewPadding.copyWith(bottom: 0),
              viewInsets: mediaQuery.viewInsets.copyWith(
                bottom: keyboardAboveNavigationBar,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
