import 'package:flutter/material.dart';

/// Lets code outside the widget tree reach the Navigator. Needed by
/// `InAppStudyPromptHost`, which sits in [MaterialApp.builder] above the
/// Navigator it constructs, so `Navigator.of(context)` on its own context
/// throws "no Navigator found".
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
