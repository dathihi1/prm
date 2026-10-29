import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prm/ongbantat_api.dart';

void main() {
  late HttpServer server;
  late OngBanTatApi api;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    api = OngBanTatApi(baseUrl: 'http://127.0.0.1:${server.port}');
  });

  tearDown(() async {
    api.close();
    await server.close(force: true);
  });

  test('loads server CAPTCHA and formats its answer', () async {
    server.listen((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/api/auth/create-captcha');
      expect(request.headers.value('api-version'), 'public');
      _json(request.response, {
        'id': 123,
        'data': '<svg xmlns="http://www.w3.org/2000/svg"></svg>',
      });
    });

    final captcha = await api.createCaptcha();

    expect(captcha.id, 123);
    expect(captcha.answer(' aB12 '), '123|aB12');
  });

  test('registers with public token and page 29 metadata', () async {
    var requestNumber = 0;
    server.listen((request) async {
      requestNumber++;
      if (requestNumber == 1) {
        expect(request.uri.path, '/api/admin/get-fe-conf');
        _json(request.response, {
          'confs': {'PUBLIC_USER_TOKEN': 'bearer public-token'},
        });
        return;
      }

      expect(request.method, 'POST');
      expect(request.uri.path, '/api/auth/register');
      expect(request.uri.queryParameters['page'], '29');
      expect(request.uri.queryParameters['api'], 'sign-up');
      expect(request.headers.value('Authorization'), 'bearer public-token');
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      expect(body, {
        'account': 'student.01',
        'password': 'abc123',
        'email': 'student@example.com',
        'captcha': '42|Z9X8',
      });
      _json(request.response, {'message': 'Đăng ký thành công'});
    });

    final message = await api.register(
      account: 'student.01',
      password: 'abc123',
      email: 'student@example.com',
      captcha: const OngBanTatCaptcha(id: 42, svg: '<svg/>'),
      captchaAnswer: 'Z9X8',
    );

    expect(message, 'Đăng ký thành công');
    expect(requestNumber, 2);
  });

  test('logs in then reads and updates the current profile', () async {
    var requestNumber = 0;
    server.listen((request) async {
      requestNumber++;
      switch (requestNumber) {
        case 1:
          expect(request.uri.path, '/api/auth/sign-in/account');
          expect(request.headers.value('api-version'), 'public');
          final body = jsonDecode(await utf8.decoder.bind(request).join());
          expect(body['captcha'], '7|AB12');
          _json(request.response, {
            'token': 'bearer user-token',
            'user': {
              'id': 99,
              'account': 'student01',
              'email': 'student@example.com',
            },
          });
        case 2:
          expect(request.method, 'GET');
          expect(request.uri.path, '/api/user');
          expect(request.headers.value('Authorization'), 'bearer user-token');
          expect(request.uri.queryParameters['page'], '16');
          expect(jsonDecode(request.uri.queryParameters['queryInput']!), {
            'id': 99,
          });
          _json(request.response, {
            'data': [
              {
                'id': 99,
                'account': 'student01',
                'email': 'student@example.com',
                'name': 'Nguyễn Văn A',
                'phone': '0900000000',
                'gender': 'male',
                'description': 'Sinh viên',
              },
            ],
          });
        case 3:
          expect(request.method, 'PATCH');
          expect(request.uri.path, '/api/user/99');
          expect(request.uri.queryParameters['api'], 'update');
          final body = jsonDecode(await utf8.decoder.bind(request).join());
          expect(body['name'], 'Nguyễn Văn B');
          expect(body.containsKey('email'), isFalse);
          _json(request.response, {'message': 'Cập nhật thành công'});
      }
    });

    final session = await api.login(
      account: 'student01',
      password: 'abc123',
      captcha: const OngBanTatCaptcha(id: 7, svg: '<svg/>'),
      captchaAnswer: 'AB12',
    );
    final profile = await api.getUser(session);
    final message = await api.updateUser(
      session: session,
      name: 'Nguyễn Văn B',
      phone: profile.phone,
      gender: profile.gender,
      description: profile.description,
    );

    expect(session.user.id, 99);
    expect(profile.name, 'Nguyễn Văn A');
    expect(message, 'Cập nhật thành công');
  });

  test('exposes the API error message', () async {
    server.listen((request) async {
      request.response.statusCode = HttpStatus.badRequest;
      _json(request.response, {'message': 'Invalid captcha!'});
    });

    expect(
      () => api.createCaptcha(),
      throwsA(
        isA<OngBanTatApiException>().having(
          (error) => error.message,
          'message',
          'Invalid captcha!',
        ),
      ),
    );
  });
}

void _json(HttpResponse response, Map<String, dynamic> body) {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  response.close();
}
