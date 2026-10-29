import 'dart:math';

import 'package:flutter/material.dart';

import 'instagram_auth_api.dart';

void main() {
  runApp(const InstagramApp());
}

class InstagramApp extends StatelessWidget {
  const InstagramApp({super.key, this.authApi});

  final InstagramAuthApi? authApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Instagram Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: InstagramLoginScreen(authApi: authApi),
    );
  }
}

class InstagramLoginScreen extends StatefulWidget {
  const InstagramLoginScreen({super.key, this.authApi});

  final InstagramAuthApi? authApi;

  @override
  State<InstagramLoginScreen> createState() => _InstagramLoginScreenState();
}

class _InstagramLoginScreenState extends State<InstagramLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _captchaController = TextEditingController();
  final Random _random = Random.secure();

  late final InstagramAuthApi _authApi;
  late final bool _ownsAuthApi;
  late String _captchaText;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _ownsAuthApi = widget.authApi == null;
    _authApi = widget.authApi ?? InstagramAuthApi();
    _captchaText = _createCaptchaText();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    if (_ownsAuthApi) _authApi.close();
    super.dispose();
  }

  String _createCaptchaText() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List<String>.generate(
      6,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  void _refreshCaptcha() {
    setState(() {
      _captchaText = _createCaptchaText();
      _captchaController.clear();
    });
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final captchaAnswer = _captchaController.text.trim();

    if (username.isEmpty || password.isEmpty || captchaAnswer.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ tài khoản, mật khẩu và CAPTCHA.');
      return;
    }

    // INTENTIONALLY INSECURE FOR THE DEMO: this CAPTCHA result is calculated
    // on the client and the API trusts it. Overwriting it with true bypasses
    // CAPTCHA without knowing the visible text.
    bool isCaptchaValid = captchaAnswer.toUpperCase() == _captchaText;
    // isCaptchaValid = true; // Bỏ comment dòng này sẽ bypass CAPTCHA.

    setState(() => _isLoggingIn = true);
    try {
      await _authApi.login(
        account: username,
        password: password,
        captchaVerified: isCaptchaValid,
      );
      if (mounted) _showMessage('Đăng nhập Instagram thành công.');
    } on InstagramAuthException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
        _refreshCaptcha();
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF381B6C), // Deep Purple
              Color(0xFF7B2382), // Purple Magenta
              Color(0xFFBD2E72), // Magenta Red
              Color(0xFFE24342), // Red Orange
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Column(
                    children: [
                      const SizedBox(height: 160),

                      // Chữ Instagram nghiêng dạng thư pháp bằng Transform.skewX
                      Transform(
                        transform: Matrix4.skewX(-0.25),
                        alignment: Alignment.center,
                        child: const Text(
                          'Instagram',
                          style: TextStyle(
                            fontSize: 54,
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Username Field
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          controller: _usernameController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            hintText: 'Username',
                            hintStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Password Field
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            hintText: 'Password',
                            hintStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Intentionally exposed as plain Text, not a Canvas/image.
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                _captchaText,
                                key: const Key('instagramCaptchaText'),
                                style: const TextStyle(
                                  color: Color(0xFF7B2382),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Tạo CAPTCHA mới',
                            onPressed: _refreshCaptcha,
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          key: const Key('instagramCaptchaInput'),
                          controller: _captchaController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            hintText: 'Enter CAPTCHA',
                            hintStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Log In Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _isLoggingIn ? null : _login,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white10,
                            side: const BorderSide(
                              color: Colors.white30,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: _isLoggingIn
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Log In',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Forgot login details
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                          children: [
                            TextSpan(text: 'Forgot your login details? '),
                            TextSpan(
                              text: 'Get help signing in.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // OR Divider
                      Row(
                        children: [
                          Expanded(
                            child: Container(height: 1, color: Colors.white24),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(height: 1, color: Colors.white24),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Log in with Facebook
                      GestureDetector(
                        onTap: () {},
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const Center(
                                child: Text(
                                  'f',
                                  style: TextStyle(
                                    color: Color(0xFF381B6C),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Log in with Facebook',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // Bottom Footer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18.0),
                decoration: const BoxDecoration(
                  color: Colors.black12,
                  border: Border(
                    top: BorderSide(color: Colors.white24, width: 1),
                  ),
                ),
                child: Center(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                      children: [
                        TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Sign up.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
