import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MagnificationController extends ChangeNotifier {
  static const double minScale = 1.0;
  static const double maxScale = 4.0;
  static const double keyboardStepFactor = 1.25;
  static const double _magnifiedThreshold = 1.01;

  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Size _viewport = Size.zero;

  double get scale => _scale;
  Offset get offset => _offset;
  bool get isMagnified => _scale > _magnifiedThreshold;

  void updateViewport(Size viewport) {
    if (viewport == _viewport) return;
    _viewport = viewport;
    _offset = _constrained(_offset, _scale);
  }

  void zoomAround(Offset focalPoint, double factor) {
    final targetScale = (_scale * factor).clamp(minScale, maxScale);
    if (targetScale == _scale) return;
    final ratio = targetScale / _scale;
    final targetOffset = focalPoint - (focalPoint - _offset) * ratio;
    _apply(targetScale, targetOffset);
  }

  void panBy(Offset delta) {
    if (!isMagnified) return;
    _apply(_scale, _offset + delta);
  }

  void zoomByStep({required bool zoomIn}) {
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    zoomAround(
      center,
      zoomIn ? keyboardStepFactor : 1 / keyboardStepFactor,
    );
  }

  void reset() {
    if (_scale == 1.0 && _offset == Offset.zero) return;
    _scale = 1.0;
    _offset = Offset.zero;
    notifyListeners();
  }

  void _apply(double scale, Offset offset) {
    if (scale <= _magnifiedThreshold) {
      reset();
      return;
    }
    _scale = scale;
    _offset = _constrained(offset, scale);
    notifyListeners();
  }

  Offset _constrained(Offset offset, double scale) {
    if (scale <= _magnifiedThreshold) return Offset.zero;
    return Offset(
      offset.dx.clamp(_viewport.width * (1 - scale), 0.0),
      offset.dy.clamp(_viewport.height * (1 - scale), 0.0),
    );
  }
}

class AppZoomController {
  AppZoomController._();

  static final AppZoomController instance = AppZoomController._();

  final MagnificationController magnification = MagnificationController();
  bool isDoubleTapZoomEnabled = false;
}

class AppZoomScope extends StatelessWidget {
  final Widget child;

  const AppZoomScope({super.key, required this.child});

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    final magnifier = AppZoomController.instance.magnification;
    const zoomInKeys = [
      LogicalKeyboardKey.equal,
      LogicalKeyboardKey.add,
      LogicalKeyboardKey.numpadAdd,
    ];
    const zoomOutKeys = [
      LogicalKeyboardKey.minus,
      LogicalKeyboardKey.numpadSubtract,
    ];
    const resetKeys = [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.numpad0,
    ];
    final bindings = <ShortcutActivator, VoidCallback>{};
    for (final useControl in [true, false]) {
      for (final key in zoomInKeys) {
        bindings[SingleActivator(key, control: useControl, meta: !useControl)] =
            () => magnifier.zoomByStep(zoomIn: true);
      }
      for (final key in zoomOutKeys) {
        bindings[SingleActivator(key, control: useControl, meta: !useControl)] =
            () => magnifier.zoomByStep(zoomIn: false);
      }
      for (final key in resetKeys) {
        bindings[SingleActivator(key, control: useControl, meta: !useControl)] =
            magnifier.reset;
      }
    }
    return bindings;
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _shortcuts(),
      child: _MagnifierViewport(
        controller: AppZoomController.instance,
        child: child,
      ),
    );
  }
}

class _MagnifierViewport extends StatefulWidget {
  final AppZoomController controller;
  final Widget child;

  const _MagnifierViewport({required this.controller, required this.child});

  @override
  State<_MagnifierViewport> createState() => _MagnifierViewportState();
}

class _MagnifierViewportState extends State<_MagnifierViewport> {
  static const Duration _doubleTapWindow = Duration(milliseconds: 300);
  static const double _tapSlop = 24;
  static const double _doubleTapRadius = 48;
  static const double _doubleTapFactor = 2.0;

  final Map<int, Offset> _pointers = {};
  Offset? _tapDownPosition;
  bool _tapMoved = false;
  bool _multiTouchDuringTap = false;
  Offset? _previousTapPosition;
  Timer? _doubleTapWindowTimer;

  @override
  void dispose() {
    _doubleTapWindowTimer?.cancel();
    super.dispose();
  }

  MagnificationController get _magnifier => widget.controller.magnification;

  List<Offset> get _pinchPoints => _pointers.values.take(2).toList();

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 1) {
      _tapDownPosition = event.localPosition;
      _tapMoved = false;
      _multiTouchDuringTap = false;
    } else {
      _multiTouchDuringTap = true;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final previousPosition = _pointers[event.pointer];
    if (previousPosition == null) return;
    final tapDown = _tapDownPosition;
    if (tapDown != null &&
        (event.localPosition - tapDown).distance > _tapSlop) {
      _tapMoved = true;
    }
    if (_pointers.length != 2) {
      _pointers[event.pointer] = event.localPosition;
      return;
    }
    final previousPoints = _pinchPoints;
    _pointers[event.pointer] = event.localPosition;
    final currentPoints = _pinchPoints;
    final previousDistance = (previousPoints[0] - previousPoints[1]).distance;
    final currentDistance = (currentPoints[0] - currentPoints[1]).distance;
    final previousMidpoint = (previousPoints[0] + previousPoints[1]) / 2;
    final currentMidpoint = (currentPoints[0] + currentPoints[1]) / 2;
    if (previousDistance > 0) {
      _magnifier.zoomAround(
          previousMidpoint, currentDistance / previousDistance);
    }
    _magnifier.panBy(currentMidpoint - previousMidpoint);
  }

  void _onPointerUp(PointerUpEvent event) {
    final wasLastPointer = _pointers.length == 1;
    _pointers.remove(event.pointer);
    if (!wasLastPointer) return;
    if (_tapMoved || _multiTouchDuringTap) {
      _forgetPreviousTap();
      return;
    }
    _registerTap(event.localPosition);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    _forgetPreviousTap();
  }

  void _forgetPreviousTap() {
    _doubleTapWindowTimer?.cancel();
    _doubleTapWindowTimer = null;
  }

  void _registerTap(Offset position) {
    if (!widget.controller.isDoubleTapZoomEnabled) return;
    final previousPosition = _previousTapPosition;
    final isDoubleTap = _doubleTapWindowTimer != null &&
        previousPosition != null &&
        (position - previousPosition).distance <= _doubleTapRadius;
    if (isDoubleTap) {
      _forgetPreviousTap();
      if (_magnifier.isMagnified) {
        _magnifier.reset();
      } else {
        _magnifier.zoomAround(position, _doubleTapFactor);
      }
      return;
    }
    _doubleTapWindowTimer?.cancel();
    _doubleTapWindowTimer = Timer(_doubleTapWindow, _forgetPreviousTap);
    _previousTapPosition = position;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScaleEvent) {
      _magnifier.zoomAround(event.localPosition, event.scale);
      return;
    }
    if (event is PointerScrollEvent && _magnifier.isMagnified) {
      _magnifier.panBy(Offset(-event.scrollDelta.dx, 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      onPointerSignal: _onPointerSignal,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _magnifier.updateViewport(constraints.biggest);
          return ListenableBuilder(
            listenable: _magnifier,
            builder: (context, _) {
              final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRect(
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translateByDouble(
                            _magnifier.offset.dx, _magnifier.offset.dy, 0, 1)
                        ..scaleByDouble(
                            _magnifier.scale, _magnifier.scale, 1, 1),
                      child: widget.child,
                    ),
                  ),
                  if (_magnifier.isMagnified)
                    Positioned(
                      left: 12,
                      bottom: bottomInset + 16,
                      child: _MagnificationPill(magnifier: _magnifier),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _MagnificationPill extends StatelessWidget {
  final MagnificationController magnifier;

  const _MagnificationPill({required this.magnifier});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      shape: const StadiumBorder(),
      color: colorScheme.surface,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('zoom-out'),
            icon: const Icon(Icons.remove, semanticLabel: 'Zoom out'),
            onPressed: () => magnifier.zoomByStep(zoomIn: false),
          ),
          Text('${(magnifier.scale * 100).round()}%'),
          IconButton(
            key: const Key('zoom-in'),
            icon: const Icon(Icons.add, semanticLabel: 'Zoom in'),
            onPressed: magnifier.scale >= MagnificationController.maxScale
                ? null
                : () => magnifier.zoomByStep(zoomIn: true),
          ),
          IconButton(
            key: const Key('zoom-reset'),
            icon: const Icon(Icons.zoom_out_map, semanticLabel: 'Reset zoom'),
            onPressed: magnifier.reset,
          ),
        ],
      ),
    );
  }
}
