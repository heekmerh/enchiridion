import 'package:enchiridion/providers/settings_provider.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:enchiridion/widgets/common/app_zoom_scope.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _screenSize = Size(800, 600);

MagnificationController get _magnifier =>
    AppZoomController.instance.magnification;

Future<SettingsProvider> _pumpScope(
  WidgetTester tester, {
  VoidCallback? onButtonPressed,
}) async {
  tester.view.physicalSize = _screenSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService(await SharedPreferences.getInstance());
  final settings = SettingsProvider(storage);
  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: MaterialApp(
        builder: (context, child) => AppZoomScope(child: child!),
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Builder(
                builder: (context) => Text(
                  'scaled ${MediaQuery.textScalerOf(context).scale(10)}',
                ),
              ),
              Positioned(
                left: 100,
                top: 100,
                child: ElevatedButton(
                  onPressed: onButtonPressed ?? () {},
                  child: const Text('Target'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return settings;
}

Future<void> _pinchOut(WidgetTester tester) async {
  final first = await tester.startGesture(const Offset(300, 300));
  final second = await tester.startGesture(const Offset(400, 300));
  await first.moveTo(const Offset(250, 300));
  await second.moveTo(const Offset(450, 300));
  await first.up();
  await second.up();
  await tester.pump();
}

void main() {
  setUp(() {
    AppZoomController.instance.isDoubleTapZoomEnabled = false;
    _magnifier.reset();
  });

  group('MagnificationController', () {
    test('keeps the focal point fixed while zooming', () {
      final magnifier = MagnificationController()
        ..updateViewport(const Size(800, 600));
      const focal = Offset(300, 200);

      magnifier.zoomAround(focal, 2);

      final contentPointUnderFocal =
          (focal - magnifier.offset) / magnifier.scale;
      expect(contentPointUnderFocal.dx, closeTo(300, 0.001));
      expect(contentPointUnderFocal.dy, closeTo(200, 0.001));
      expect(magnifier.scale, 2);
    });

    test('limits scale and returns to identity at 1x', () {
      final magnifier = MagnificationController()
        ..updateViewport(const Size(800, 600));

      magnifier.zoomAround(const Offset(400, 300), 100);
      expect(magnifier.scale, MagnificationController.maxScale);

      magnifier.zoomAround(const Offset(400, 300), 0.001);
      expect(magnifier.scale, 1);
      expect(magnifier.offset, Offset.zero);
      expect(magnifier.isMagnified, isFalse);
    });

    test('never pans past the edges of the content', () {
      final magnifier = MagnificationController()
        ..updateViewport(const Size(800, 600));
      magnifier.zoomAround(const Offset(0, 0), 2);

      magnifier.panBy(const Offset(5000, 5000));
      expect(magnifier.offset, Offset.zero);

      magnifier.panBy(const Offset(-5000, -5000));
      expect(magnifier.offset, const Offset(-800, -600));
    });

    test('ignores panning while not magnified', () {
      final magnifier = MagnificationController()
        ..updateViewport(const Size(800, 600));

      magnifier.panBy(const Offset(50, 50));

      expect(magnifier.offset, Offset.zero);
    });

    test('keyboard steps zoom about the screen centre', () {
      final magnifier = MagnificationController()
        ..updateViewport(const Size(800, 600));

      magnifier.zoomByStep(zoomIn: true);

      expect(magnifier.scale, MagnificationController.keyboardStepFactor);
      magnifier.zoomByStep(zoomIn: false);
      expect(magnifier.isMagnified, isFalse);
    });
  });

  group('outside the reader', () {
    testWidgets(
        'pinching magnifies the whole screen without changing text size',
        (tester) async {
      final settings = await _pumpScope(tester);

      await _pinchOut(tester);

      expect(_magnifier.isMagnified, isTrue);
      expect(settings.settings.fontSize, 100);
      expect(find.text('scaled 10.0'), findsOneWidget);
    });

    testWidgets('two-finger drag pans the magnified view', (tester) async {
      await _pumpScope(tester);
      await _pinchOut(tester);
      final offsetBeforePan = _magnifier.offset;

      final first = await tester.startGesture(const Offset(300, 300));
      final second = await tester.startGesture(const Offset(400, 300));
      await first.moveBy(const Offset(40, 30));
      await second.moveBy(const Offset(40, 30));
      await first.up();
      await second.up();
      await tester.pump();

      expect(_magnifier.offset, isNot(offsetBeforePan));
    });

    testWidgets('taps land on the right control while magnified',
        (tester) async {
      var pressCount = 0;
      await _pumpScope(tester, onButtonPressed: () => pressCount++);
      _magnifier.zoomAround(Offset.zero, 2);
      await tester.pump();

      await tester.tap(find.text('Target'));
      await tester.pump();

      expect(pressCount, 1);
    });

    testWidgets('double tap does not magnify or change the text size',
        (tester) async {
      final settings = await _pumpScope(tester);

      await tester.tapAt(const Offset(500, 400));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(500, 400));
      await tester.pump();

      expect(settings.settings.fontSize, 100);
      expect(_magnifier.isMagnified, isFalse);
    });

    testWidgets('trackpad pinch magnifies toward the pointer', (tester) async {
      await _pumpScope(tester);
      final pointer = TestPointer(1, PointerDeviceKind.trackpad);

      await tester.sendEventToBinding(pointer.hover(const Offset(260, 340)));
      await tester.sendEventToBinding(pointer.scale(1.5));
      await tester.pump();

      expect(_magnifier.scale, closeTo(1.5, 0.001));
    });

    testWidgets('ctrl plus and ctrl zero magnify and reset', (tester) async {
      await _pumpScope(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);

      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
      expect(_magnifier.isMagnified, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pump();
      expect(_magnifier.isMagnified, isFalse);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    });

    testWidgets('on-screen controls appear only while magnified and reset it',
        (tester) async {
      await _pumpScope(tester);
      expect(find.byKey(const Key('zoom-reset')), findsNothing);

      _magnifier.zoomAround(Offset.zero, 2);
      await tester.pump();
      expect(find.byKey(const Key('zoom-reset')), findsOneWidget);
      expect(find.text('200%'), findsOneWidget);

      await tester.tap(find.byKey(const Key('zoom-in')));
      await tester.pump();
      expect(_magnifier.scale, greaterThan(2));

      await tester.tap(find.byKey(const Key('zoom-reset')));
      await tester.pump();
      expect(find.byKey(const Key('zoom-reset')), findsNothing);
      expect(_magnifier.isMagnified, isFalse);
    });
  });

  group('inside the reader', () {
    setUp(() {
      AppZoomController.instance.isDoubleTapZoomEnabled = true;
    });

    testWidgets('pinching magnifies like a picture and leaves text untouched',
        (tester) async {
      final settings = await _pumpScope(tester);

      await _pinchOut(tester);

      expect(_magnifier.isMagnified, isTrue);
      expect(settings.settings.fontSize, 100);
      expect(find.text('scaled 10.0'), findsOneWidget);
    });

    testWidgets('double tap magnifies around the tapped point', (tester) async {
      final settings = await _pumpScope(tester);
      const tapPoint = Offset(500, 420);

      await tester.tapAt(tapPoint);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(tapPoint);
      await tester.pump();

      expect(_magnifier.scale, 2);
      final contentPointUnderTap =
          (tapPoint - _magnifier.offset) / _magnifier.scale;
      expect(contentPointUnderTap.dx, closeTo(tapPoint.dx, 0.001));
      expect(contentPointUnderTap.dy, closeTo(tapPoint.dy, 0.001));
      expect(settings.settings.fontSize, 100);
    });

    testWidgets('double tap while magnified resets', (tester) async {
      await _pumpScope(tester);
      _magnifier.zoomAround(Offset.zero, 2);
      await tester.pump();

      await tester.tapAt(const Offset(500, 420));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(500, 420));
      await tester.pump();

      expect(_magnifier.isMagnified, isFalse);
    });

    testWidgets('slow or distant second tap is not a double tap',
        (tester) async {
      await _pumpScope(tester);

      await tester.tapAt(const Offset(500, 420));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tapAt(const Offset(500, 420));
      await tester.pump();
      expect(_magnifier.isMagnified, isFalse);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.tapAt(const Offset(100, 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(700, 500));
      await tester.pump();
      expect(_magnifier.isMagnified, isFalse);
    });

    testWidgets('a drag followed by a tap is not a double tap', (tester) async {
      await _pumpScope(tester);

      final finger = await tester.startGesture(const Offset(400, 300));
      await finger.moveBy(const Offset(0, -200));
      await finger.up();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(400, 100));
      await tester.pump();

      expect(_magnifier.isMagnified, isFalse);
    });
  });
}
