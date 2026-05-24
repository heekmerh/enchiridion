import 'package:flutter/material.dart';
import '../icons/custom_icons.dart';

enum DrawerPosition { left, right }

class CustomDrawer extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final String title;
  final Widget child;
  final DrawerPosition position;
  final Widget? headerLeading;

  const CustomDrawer({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.title,
    required this.child,
    this.position = DrawerPosition.left,
    this.headerLeading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Backdrop
        if (isOpen)
          GestureDetector(
            onTap: onClose,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isOpen ? 1.0 : 0.0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),

        // Drawer Panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: 0,
          bottom: 0,
          left: position == DrawerPosition.left
              ? (isOpen ? 0 : -320)
              : null,
          right: position == DrawerPosition.right
              ? (isOpen ? 0 : -320)
              : null,
          child: Material(
            elevation: 16,
            color: theme.colorScheme.surface,
            child: SizedBox(
              width: 320,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (headerLeading != null) ...[
                              headerLeading!,
                              const SizedBox(width: 10),
                            ],
                            Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: CustomIcons.close(
                            color: theme.iconTheme.color?.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content — extra bottom padding so the reader footer
                  // (prev/next nav bar, ~72 px) never covers the last item
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
