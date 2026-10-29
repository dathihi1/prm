import 'dart:async';
import 'dart:convert';
import 'dart:io';

class InstagramAuthApi {
  InstagramAuthApi({
    String? baseUrl,
    HttpClient? client,
    this.requestTimeout = const Duration(seconds: 5),
  }) : baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'INSTAGRAM_API_URL',
             defaultValue: 'http://10.0.2.2:8080',
           ),
       _client = client ?? HttpClient() {
    _client.connectionTimeout = requestTimeout;
  }

  final String baseUrl;
  final HttpClient _client;
  final Duration requestTimeout;

  Future<void> login({
    required String account,
    required String password,
    required bool captchaVerified,
  }) async {
    try {
      final request = await _client
          .postUrl(Uri.parse('$baseUrl/api/instagram/login'))
          .timeout(requestTimeout);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'account': account,
          'password': password,
          // Intentionally insecure: the backend trusts this client-side flag.
          'captchaVerified': captchaVerified,
        }),
      );

      final response = await request.close().timeout(requestTimeout);
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(requestTimeout);
      final data = responseBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw InstagramAuthException(
          data['message'] as String? ?? 'Yêu cầu không thành công.',
        );
      }
    } on InstagramAuthException {
      rethrow;
    } on SocketException {
      throw const InstagramAuthException(
        'Không thể kết nối tới máy chủ. Hãy kiểm tra backend đang chạy.',
      );
    } on TimeoutException {
      throw const InstagramAuthException(
        'Máy chủ không phản hồi. Hãy chạy lại backend rồi thử lại.',
      );
    } on FormatException {
      throw const InstagramAuthException('Phản hồi từ máy chủ không hợp lệ.');
    }
  }

  void close() => _client.close(force: true);
}

class InstagramAuthException implements Exception {
  const InstagramAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
