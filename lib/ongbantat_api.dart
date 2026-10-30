import 'dart:async';
import 'dart:convert';
import 'dart:io';

class OngBanTatCaptcha {
  const OngBanTatCaptcha({required this.id, required this.svg});

  final int id;
  final String svg;

  String answer(String value) => '$id|${value.trim()}';
}

class OngBanTatUser {
  const OngBanTatUser({
    required this.id,
    required this.account,
    required this.email,
    required this.name,
    required this.phone,
    required this.gender,
    required this.description,
  });

  factory OngBanTatUser.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString() ?? '';

    return OngBanTatUser(
      id: _asInt(json['id']),
      account: text('account'),
      email: text('email'),
      name: text('name'),
      phone: text('phone'),
      gender: text('gender').isEmpty ? 'other' : text('gender'),
      description: text('description'),
    );
  }

  final int id;
  final String account;
  final String email;
  final String name;
  final String phone;
  final String gender;
  final String description;

  OngBanTatUser copyWith({
    String? name,
    String? phone,
    String? gender,
    String? description,
  }) {
    return OngBanTatUser(
      id: id,
      account: account,
      email: email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      description: description ?? this.description,
    );
  }
}

class OngBanTatSession {
  const OngBanTatSession({required this.token, required this.user});

  final String token;
  final OngBanTatUser user;
}

class OngBanTatApi {
  OngBanTatApi({
    String? baseUrl,
    HttpClient? client,
    this.requestTimeout = const Duration(seconds: 15),
  }) : baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'ONGBANTAT_API_URL',
             defaultValue: 'https://backend.ongbantat.io.vn',
           ),
       _client = client ?? HttpClient() {
    _client.connectionTimeout = requestTimeout;
  }

  final String baseUrl;
  final HttpClient _client;
  final Duration requestTimeout;

  String? _publicToken;

  Future<OngBanTatCaptcha> createCaptcha() async {
    final data = await _request(
      'GET',
      '/api/auth/create-captcha',
      apiVersion: 'public',
    );
    return OngBanTatCaptcha(
      id: _asInt(data['id']),
      svg: data['data']?.toString() ?? '',
    );
  }

  Future<String> register({
    required String account,
    required String password,
    required String email,
    required OngBanTatCaptcha captcha,
    required String captchaAnswer,
  }) async {
    final token = await _loadPublicToken();
    final data = await _request(
      'POST',
      '/api/auth/register',
      query: const {'page': '29', 'api': 'sign-up'},
      authorization: token,
      body: {
        'account': account.trim(),
        'password': password,
        'email': email.trim(),
        'captcha': captcha.answer(captchaAnswer),
      },
    );
    return data['message']?.toString() ?? 'Đăng ký thành công.';
  }

  Future<OngBanTatSession> login({
    required String account,
    required String password,
    required OngBanTatCaptcha captcha,
    required String captchaAnswer,
  }) async {
    final data = await _request(
      'POST',
      '/api/auth/sign-in/account',
      apiVersion: 'public',
      body: {
        'account': account.trim(),
        'password': password,
        'captcha': captcha.answer(captchaAnswer),
      },
    );
    final userJson = _asStringMap(data['user']);
    return OngBanTatSession(
      token: data['token']?.toString() ?? '',
      user: OngBanTatUser.fromJson(userJson),
    );
  }

  Future<OngBanTatUser> getUser(OngBanTatSession session) async {
    final data = await _request(
      'GET',
      '/api/user',
      query: {
        'page': '16',
        'api': 'find',
        'queryInput': jsonEncode({'id': session.user.id}),
      },
      authorization: session.token,
    );
    final users = data['data'];
    if (users is! List || users.isEmpty) {
      throw const OngBanTatApiException('Không tìm thấy thông tin người dùng.');
    }
    return OngBanTatUser.fromJson(_asStringMap(users.first));
  }

  Future<String> updateUser({
    required OngBanTatSession session,
    required String name,
    required String phone,
    required String gender,
    required String description,
  }) async {
    final data = await _request(
      'PATCH',
      '/api/user/${session.user.id}',
      query: const {'page': '16', 'api': 'update'},
      authorization: session.token,
      body: {
        'name': name.trim(),
        'phone': phone.trim(),
        'gender': gender,
        'description': description.trim(),
      },
    );
    return data['message']?.toString() ?? 'Cập nhật thành công.';
  }

  Future<void> logout(OngBanTatSession session) async {
    await _request(
      'POST',
      '/api/auth/logout',
      query: const {'page': '16', 'api': 'logout'},
      authorization: session.token,
      body: const {},
    );
  }

  Future<String> _loadPublicToken() async {
    if (_publicToken != null) return _publicToken!;
    final data = await _request('GET', '/api/admin/get-fe-conf');
    final confs = _asStringMap(data['confs']);
    final token = confs['PUBLIC_USER_TOKEN']?.toString() ?? '';
    if (token.isEmpty) {
      throw const OngBanTatApiException(
        'Máy chủ không cung cấp token đăng ký công khai.',
      );
    }
    _publicToken = token;
    return token;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String apiVersion = 'pageid',
    String? authorization,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
      final request = await _client
          .openUrl(method, uri)
          .timeout(requestTimeout);
      request.headers.set('api-version', apiVersion);
      request.headers.set('Authorization', authorization ?? 'customer');
      request.headers.contentType = ContentType.json;
      if (body != null) request.write(jsonEncode(body));

      final response = await request.close().timeout(requestTimeout);
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(requestTimeout);
      final decoded = responseBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseBody);
      final data = _asStringMap(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OngBanTatApiException(
          data['message']?.toString() ?? 'Yêu cầu không thành công.',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on OngBanTatApiException {
      rethrow;
    } on SocketException {
      throw const OngBanTatApiException('Không thể kết nối tới máy chủ.');
    } on TimeoutException {
      throw const OngBanTatApiException('Máy chủ phản hồi quá chậm.');
    } on FormatException {
      throw const OngBanTatApiException('Phản hồi từ máy chủ không hợp lệ.');
    }
  }

  void close() => _client.close(force: true);
}

class OngBanTatApiException implements Exception {
  const OngBanTatApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

int _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic> _asStringMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}
