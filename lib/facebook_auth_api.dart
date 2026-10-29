import 'dart:async';
import 'dart:convert';
import 'dart:io';

class FacebookCaptcha {
  const FacebookCaptcha({
    required this.id,
    required this.text,
    required this.expiresInSeconds,
  });

  final String id;
  final String text;
  final int expiresInSeconds;
}

class FacebookAuthApi {
  FacebookAuthApi({
    String? baseUrl,
    HttpClient? client,
    this.requestTimeout = const Duration(seconds: 5),
  }) : baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'FACEBOOK_API_URL',
             defaultValue: 'http://10.0.2.2:8080',
           ),
       _client = client ?? HttpClient() {
    _client.connectionTimeout = requestTimeout;
  }

  final String baseUrl;
  final HttpClient _client;
  final Duration requestTimeout;

  Future<FacebookCaptcha> createCaptcha() async {
    final response = await _send('GET', '/api/facebook/captcha');
    return FacebookCaptcha(
      id: response['captchaId'] as String,
      text: response['captchaText'] as String,
      expiresInSeconds: response['expiresInSeconds'] as int,
    );
  }

  Future<void> login({
    required String account,
    required String password,
    required String captchaId,
    required String captchaAnswer,
  }) async {
    await _send(
      'POST',
      '/api/facebook/login',
      body: <String, String>{
        'account': account,
        'password': password,
        'captchaId': captchaId,
        'captchaAnswer': captchaAnswer,
      },
    );
  }

  /// Validates the one-time CAPTCHA before Firebase Authentication is called.
  Future<void> verifyCaptcha({
    required String captchaId,
    required String captchaAnswer,
  }) async {
    await _send(
      'POST',
      '/api/facebook/captcha/verify',
      body: <String, String>{
        'captchaId': captchaId,
        'captchaAnswer': captchaAnswer,
      },
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final request = await _client
          .openUrl(method, Uri.parse('$baseUrl$path'))
          .timeout(requestTimeout);
      request.headers.contentType = ContentType.json;
      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(requestTimeout);
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(requestTimeout);
      final data = responseBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FacebookAuthException(
          data['message'] as String? ?? 'Yêu cầu không thành công.',
        );
      }
      return data;
    } on FacebookAuthException {
      rethrow;
    } on SocketException {
      throw const FacebookAuthException(
        'Không thể kết nối tới máy chủ. Hãy kiểm tra backend đang chạy.',
      );
    } on TimeoutException {
      throw const FacebookAuthException(
        'Máy chủ không phản hồi. Hãy chạy lại backend rồi thử lại.',
      );
    } on FormatException {
      throw const FacebookAuthException('Phản hồi từ máy chủ không hợp lệ.');
    }
  }

  void close() => _client.close(force: true);
}

class FacebookAuthException implements Exception {
  const FacebookAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
