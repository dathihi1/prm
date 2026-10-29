import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class FacebookAuthServer {
  FacebookAuthServer({
    this.account = 'facebook@example.com',
    this.password = 'Facebook@123',
    this.instagramAccount = 'instagram',
    this.instagramPassword = 'Instagram@123',
    this.captchaLifetime = const Duration(minutes: 2),
    Random? random,
  }) : _random = random ?? Random.secure();

  final String account;
  final String password;
  final String instagramAccount;
  final String instagramPassword;
  final Duration captchaLifetime;
  final Random _random;
  final Map<String, _CaptchaRecord> _captchas = <String, _CaptchaRecord>{};

  HttpServer? _server;

  int get port => _server?.port ?? 0;
  int get activeCaptchaCount => _captchas.length;

  Future<void> start({InternetAddress? address, int port = 8080}) async {
    _server = await HttpServer.bind(address ?? InternetAddress.anyIPv4, port);
    _server!.listen(_handleRequest);
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
    for (final record in _captchas.values) {
      record.expirationTimer.cancel();
    }
    _captchas.clear();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _addCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    try {
      if (request.method == 'GET' && request.uri.path == '/health') {
        await _json(request.response, HttpStatus.ok, {'status': 'ok'});
        return;
      }

      if (request.method == 'GET' &&
          request.uri.path == '/api/facebook/captcha') {
        _removeExpiredCaptchas();
        final captcha = _createCaptcha();
        await _json(request.response, HttpStatus.ok, {
          'captchaId': captcha.id,
          'captchaText': captcha.answer,
          'expiresInSeconds': captchaLifetime.inSeconds,
        });
        return;
      }

      if (request.method == 'POST' &&
          request.uri.path == '/api/facebook/login') {
        await _handleLogin(request);
        return;
      }

      if (request.method == 'POST' &&
          request.uri.path == '/api/facebook/captcha/verify') {
        await _handleCaptchaVerification(request);
        return;
      }

      if (request.method == 'POST' &&
          request.uri.path == '/api/instagram/login') {
        await _handleInstagramLogin(request);
        return;
      }

      await _json(request.response, HttpStatus.notFound, {
        'message': 'Không tìm thấy API.',
      });
    } on FormatException {
      await _json(request.response, HttpStatus.badRequest, {
        'message': 'Dữ liệu gửi lên không hợp lệ.',
      });
    } catch (_) {
      await _json(request.response, HttpStatus.internalServerError, {
        'message': 'Máy chủ gặp lỗi.',
      });
    }
  }

  Future<void> _handleLogin(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final captchaId = (data['captchaId'] as String? ?? '').trim();
    final captchaAnswer = (data['captchaAnswer'] as String? ?? '').trim();

    // CAPTCHA is removed before validation so every challenge is one-time use.
    final record = _takeCaptcha(captchaId);
    final captchaIsValid =
        record != null &&
        DateTime.now().isBefore(record.expiresAt) &&
        _constantTimeEquals(
          record.answer.toUpperCase(),
          captchaAnswer.toUpperCase(),
        );

    if (!captchaIsValid) {
      await _json(request.response, HttpStatus.unauthorized, {
        'message': 'CAPTCHA không đúng hoặc đã hết hạn.',
      });
      return;
    }

    final accountIsValid = _constantTimeEquals(
      account,
      data['account'] as String? ?? '',
    );
    final passwordIsValid = _constantTimeEquals(
      password,
      data['password'] as String? ?? '',
    );

    if (!accountIsValid || !passwordIsValid) {
      await _json(request.response, HttpStatus.unauthorized, {
        'message': 'Tài khoản hoặc mật khẩu không đúng.',
      });
      return;
    }

    await _json(request.response, HttpStatus.ok, {
      'success': true,
      'message': 'Đăng nhập Facebook thành công.',
    });
  }

  Future<void> _handleCaptchaVerification(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final captchaId = (data['captchaId'] as String? ?? '').trim();
    final captchaAnswer = (data['captchaAnswer'] as String? ?? '').trim();

    // The challenge is always consumed, whether the answer is right or wrong.
    final record = _takeCaptcha(captchaId);
    final captchaIsValid =
        record != null &&
        DateTime.now().isBefore(record.expiresAt) &&
        _constantTimeEquals(
          record.answer.toUpperCase(),
          captchaAnswer.toUpperCase(),
        );

    if (!captchaIsValid) {
      await _json(request.response, HttpStatus.unauthorized, {
        'message': 'CAPTCHA không đúng hoặc đã hết hạn.',
      });
      return;
    }

    await _json(request.response, HttpStatus.ok, {'success': true});
  }

  Future<void> _handleInstagramLogin(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    // INTENTIONALLY INSECURE FOR THE DEMO:
    // The server trusts a boolean calculated by the client instead of checking
    // a server-owned CAPTCHA challenge. Changing this value to true bypasses
    // the CAPTCHA check.
    if (data['captchaVerified'] != true) {
      await _json(request.response, HttpStatus.unauthorized, {
        'message': 'CAPTCHA không đúng.',
      });
      return;
    }

    final accountIsValid = _constantTimeEquals(
      instagramAccount,
      data['account'] as String? ?? '',
    );
    final passwordIsValid = _constantTimeEquals(
      instagramPassword,
      data['password'] as String? ?? '',
    );

    if (!accountIsValid || !passwordIsValid) {
      await _json(request.response, HttpStatus.unauthorized, {
        'message': 'Tài khoản hoặc mật khẩu không đúng.',
      });
      return;
    }

    await _json(request.response, HttpStatus.ok, {
      'success': true,
      'message': 'Đăng nhập Instagram thành công.',
    });
  }

  _CreatedCaptcha _createCaptcha() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String randomText(int length) => List<String>.generate(
      length,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();

    var id = randomText(24);
    while (_captchas.containsKey(id)) {
      id = randomText(24);
    }
    final answer = randomText(6);
    final expiresAt = DateTime.now().add(captchaLifetime);
    final expirationTimer = Timer(captchaLifetime, () {
      _captchas.remove(id);
    });
    _captchas[id] = _CaptchaRecord(
      answer: answer,
      expiresAt: expiresAt,
      expirationTimer: expirationTimer,
    );
    return _CreatedCaptcha(id: id, answer: answer);
  }

  _CaptchaRecord? _takeCaptcha(String id) {
    final record = _captchas.remove(id);
    record?.expirationTimer.cancel();
    return record;
  }

  void _removeExpiredCaptchas() {
    final now = DateTime.now();
    final expiredIds = _captchas.entries
        .where((entry) => !now.isBefore(entry.value.expiresAt))
        .map((entry) => entry.key)
        .toList();
    for (final id in expiredIds) {
      _takeCaptcha(id);
    }
  }

  bool _constantTimeEquals(String expected, String actual) {
    var difference = expected.length ^ actual.length;
    final length = max(expected.length, actual.length);
    for (var index = 0; index < length; index++) {
      final expectedCode = index < expected.length
          ? expected.codeUnitAt(index)
          : 0;
      final actualCode = index < actual.length ? actual.codeUnitAt(index) : 0;
      difference |= expectedCode ^ actualCode;
    }
    return difference == 0;
  }

  void _addCorsHeaders(HttpResponse response) {
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type');
  }

  Future<void> _json(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await response.close();
  }
}

class _CaptchaRecord {
  const _CaptchaRecord({
    required this.answer,
    required this.expiresAt,
    required this.expirationTimer,
  });

  final String answer;
  final DateTime expiresAt;
  final Timer expirationTimer;
}

class _CreatedCaptcha {
  const _CreatedCaptcha({required this.id, required this.answer});

  final String id;
  final String answer;
}
