import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prm/instagram_auth_api.dart';
import 'package:prm/main_instagram.dart';

void main() {
  testWidgets('logs in using local credentials and frontend CAPTCHA', (
    tester,
  ) async {
    final api = _FakeInstagramAuthApi();
    await tester.pumpWidget(InstagramApp(authApi: api));

    final captchaWidget = tester.widget<Text>(
      find.byKey(const Key('instagramCaptchaText')),
    );
    final captcha = captchaWidget.data!;
    expect(captcha, hasLength(6));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'instagram');
    await tester.enterText(fields.at(1), 'Instagram@123');
    await tester.enterText(
      find.byKey(const Key('instagramCaptchaInput')),
      captcha.toLowerCase(),
    );

    final loginButton = find.widgetWithText(OutlinedButton, 'Log In');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập Instagram thành công.'), findsOneWidget);
  });
}

class _FakeInstagramAuthApi extends InstagramAuthApi {
  _FakeInstagramAuthApi() : super(baseUrl: 'http://unused');

  @override
  Future<void> login({
    required String account,
    required String password,
    required bool captchaVerified,
  }) async {
    if (!captchaVerified) {
      throw const InstagramAuthException('CAPTCHA không đúng.');
    }
    if (account != 'instagram' || password != 'Instagram@123') {
      throw const InstagramAuthException('Tài khoản hoặc mật khẩu không đúng.');
    }
  }

  @override
  void close() {}
}
