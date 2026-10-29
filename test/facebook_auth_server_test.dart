import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prm/facebook_auth_api.dart';
import 'package:prm/instagram_auth_api.dart';

import '../backend/facebook_auth_server.dart';

void main() {
  late FacebookAuthServer server;
  late FacebookAuthApi api;
  late InstagramAuthApi instagramApi;

  setUp(() async {
    server = FacebookAuthServer();
    await server.start(address: InternetAddress.loopbackIPv4, port: 0);
    api = FacebookAuthApi(baseUrl: 'http://127.0.0.1:${server.port}');
    instagramApi = InstagramAuthApi(baseUrl: 'http://127.0.0.1:${server.port}');
  });

  tearDown(() async {
    api.close();
    instagramApi.close();
    await server.close();
  });

  test('accepts the demo credentials with the matching CAPTCHA id', () async {
    final captcha = await api.createCaptcha();

    await api.login(
      account: 'facebook@example.com',
      password: 'Facebook@123',
      captchaId: captcha.id,
      captchaAnswer: captcha.text.toLowerCase(),
    );
  });

  test('a CAPTCHA can only be used once', () async {
    final captcha = await api.createCaptcha();

    await api.login(
      account: 'facebook@example.com',
      password: 'Facebook@123',
      captchaId: captcha.id,
      captchaAnswer: captcha.text,
    );

    expect(
      () => api.login(
        account: 'facebook@example.com',
        password: 'Facebook@123',
        captchaId: captcha.id,
        captchaAnswer: captcha.text,
      ),
      throwsA(
        isA<FacebookAuthException>().having(
          (error) => error.message,
          'message',
          contains('CAPTCHA'),
        ),
      ),
    );
  });

  test('validates CAPTCHA independently before Firebase login', () async {
    final captcha = await api.createCaptcha();

    await api.verifyCaptcha(
      captchaId: captcha.id,
      captchaAnswer: captcha.text.toLowerCase(),
    );

    expect(
      () =>
          api.verifyCaptcha(captchaId: captcha.id, captchaAnswer: captcha.text),
      throwsA(isA<FacebookAuthException>()),
    );
  });

  test('rejects incorrect credentials even with a valid CAPTCHA', () async {
    final captcha = await api.createCaptcha();

    expect(
      () => api.login(
        account: 'wrong@example.com',
        password: 'wrong-password',
        captchaId: captcha.id,
        captchaAnswer: captcha.text,
      ),
      throwsA(
        isA<FacebookAuthException>().having(
          (error) => error.message,
          'message',
          contains('Tài khoản'),
        ),
      ),
    );
  });

  test('automatically removes a CAPTCHA when its lifetime ends', () async {
    final expiringServer = FacebookAuthServer(
      captchaLifetime: const Duration(milliseconds: 30),
    );
    await expiringServer.start(address: InternetAddress.loopbackIPv4, port: 0);
    final expiringApi = FacebookAuthApi(
      baseUrl: 'http://127.0.0.1:${expiringServer.port}',
    );

    try {
      await expiringApi.createCaptcha();
      expect(expiringServer.activeCaptchaCount, 1);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(expiringServer.activeCaptchaCount, 0);
    } finally {
      expiringApi.close();
      await expiringServer.close();
    }
  });

  test('Instagram API intentionally trusts a client-side true flag', () async {
    await instagramApi.login(
      account: 'instagram',
      password: 'Instagram@123',
      captchaVerified: true,
    );
  });

  test('Instagram API rejects the client-side false flag', () async {
    expect(
      () => instagramApi.login(
        account: 'instagram',
        password: 'Instagram@123',
        captchaVerified: false,
      ),
      throwsA(
        isA<InstagramAuthException>().having(
          (error) => error.message,
          'message',
          contains('CAPTCHA'),
        ),
      ),
    );
  });
}
