import 'package:flutter/material.dart';

/// Lets code that runs outside the widget tree reach the Navigator.
///
/// `InAppStudyPromptHost` needs this: it sits in [MaterialApp.builder] — a
/// position *above* the Navigator that `builder` constructs, not below it.
/// Its own [State.context] is therefore not a descendant of any Navigator,
/// so `Navigator.of(context)` called with that context throws "no Navigator
/// found" the first time it actually runs. `rootNavigatorKey.currentState`
/// resolves to the Navigator's own state, which accepts pushes directly.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
