import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prm/captcha_canvas.dart';

void main() {
  testWidgets('renders the Facebook CAPTCHA with a CustomPainter', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 240, child: CaptchaCanvas(text: 'ABC123')),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('ABC123'), findsNothing);

    final captcha = tester.widget<CaptchaCanvas>(find.byType(CaptchaCanvas));
    expect(captcha.text, 'ABC123');
  });
}
