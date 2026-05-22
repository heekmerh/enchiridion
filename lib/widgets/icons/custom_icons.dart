import 'package:flutter/material.dart';

class CustomIcons {
  static Widget menu({double size = 24, Color? color}) {
    return Icon(Icons.menu, size: size, color: color);
  }

  static Widget close({double size = 24, Color? color}) {
    return Icon(Icons.close, size: size, color: color);
  }

  static Widget settings({double size = 24, Color? color}) {
    return Icon(Icons.settings, size: size, color: color);
  }

  static Widget bookmark({double size = 24, Color? color, bool filled = false}) {
    return Icon(
      filled ? Icons.bookmark : Icons.bookmark_border,
      size: size,
      color: color,
    );
  }

  static Widget search({double size = 24, Color? color}) {
    return Icon(Icons.search, size: size, color: color);
  }

  static Widget chevronLeft({double size = 24, Color? color}) {
    return Icon(Icons.chevron_left, size: size, color: color);
  }

  static Widget chevronRight({double size = 24, Color? color}) {
    return Icon(Icons.chevron_right, size: size, color: color);
  }
}
