import 'package:enchiridion/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder createAccountButton() => find.widgetWithText(FilledButton, 'Create Account');

  Future<void> pumpRegisterScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: RegisterScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Create Account stays disabled until the terms are accepted',
      (tester) async {
    await pumpRegisterScreen(tester);

    expect(
      tester.widget<FilledButton>(createAccountButton()).onPressed,
      isNull,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(createAccountButton()).onPressed,
      isNotNull,
    );
  });

  testWidgets('sign-up screen links the terms and the privacy policy',
      (tester) async {
    await pumpRegisterScreen(tester);

    final consentText = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('I agree to'),
      ),
    );
    final plain = consentText.text.toPlainText();

    expect(plain, contains('Terms and Conditions'));
    expect(plain, contains('Privacy Policy'));
    expect(plain, contains('18 or older'));
  });
}
