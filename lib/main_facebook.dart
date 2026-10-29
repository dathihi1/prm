import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'captcha_canvas.dart';
import 'facebook_auth_api.dart';
import 'firebase_notification_service.dart';
import 'firebase_profile_repository.dart';
import 'profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? initializationError;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (error) {
    initializationError = error;
  }
  runApp(FacebookApp(initializationError: initializationError));
}

class FacebookApp extends StatelessWidget {
  const FacebookApp({this.initializationError, super.key});

  final Object? initializationError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Facebook Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: initializationError == null
          ? const FirebaseAuthGate()
          : FirebaseSetupScreen(error: initializationError!),
    );
  }
}

class FirebaseAuthGate extends StatelessWidget {
  const FirebaseAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return const FacebookLoginScreen();
        return ProfileScreen(
          user: user,
          repository: FirebaseProfileRepository(),
        );
      },
    );
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cần cấu hình Firebase')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 72, color: Color(0xFF2B4E8C)),
            const SizedBox(height: 20),
            const Text(
              'Chưa tìm thấy cấu hình Firebase cho ứng dụng Android.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Chạy “flutterfire configure” hoặc đặt google-services.json vào android/app rồi mở lại ứng dụng.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class FacebookLoginScreen extends StatefulWidget {
  const FacebookLoginScreen({super.key});

  @override
  State<FacebookLoginScreen> createState() => _FacebookLoginScreenState();
}

class _FacebookLoginScreenState extends State<FacebookLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _captchaController = TextEditingController();
  late final FacebookAuthApi _authApi;
  Timer? _captchaExpirationTimer;

  FacebookCaptcha? _captcha;
  String? _captchaError;
  bool _isLoadingCaptcha = false;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _authApi = FacebookAuthApi();
    _loadCaptcha();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    _captchaExpirationTimer?.cancel();
    _authApi.close();
    super.dispose();
  }

  Future<void> _loadCaptcha() async {
    _captchaExpirationTimer?.cancel();
    setState(() {
      _isLoadingCaptcha = true;
      _captchaError = null;
      _captcha = null;
      _captchaController.clear();
    });

    try {
      final captcha = await _authApi.createCaptcha();
      if (!mounted) return;
      setState(() => _captcha = captcha);
      _captchaExpirationTimer = Timer(
        Duration(seconds: captcha.expiresInSeconds),
        () {
          if (mounted && _captcha?.id == captcha.id) {
            _loadCaptcha();
          }
        },
      );
    } on FacebookAuthException catch (error) {
      if (!mounted) return;
      setState(() => _captchaError = error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoadingCaptcha = false);
      }
    }
  }

  Future<void> _login() => _authenticate(createAccount: false);

  Future<void> _signUp() => _authenticate(createAccount: true);

  Future<void> _authenticate({required bool createAccount}) async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _captchaController.text.trim().isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ tài khoản, mật khẩu và CAPTCHA.');
      return;
    }
    final captcha = _captcha;
    if (captcha == null) {
      _showMessage('CAPTCHA chưa sẵn sàng. Vui lòng tải lại.');
      return;
    }

    setState(() => _isLoggingIn = true);
    try {
      await _authApi.verifyCaptcha(
        captchaId: captcha.id,
        captchaAnswer: _captchaController.text.trim(),
      );
      if (createAccount) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on FacebookAuthException catch (error) {
      if (mounted) _showMessage(error.message);
    } on FirebaseAuthException catch (error) {
      if (mounted) _showMessage(_firebaseAuthMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
        await _loadCaptcha();
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Nhập email để nhận liên kết đặt lại mật khẩu.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) _showMessage('Đã gửi email đặt lại mật khẩu.');
    } on FirebaseAuthException catch (error) {
      if (mounted) _showMessage(_firebaseAuthMessage(error));
    }
  }

  String _firebaseAuthMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Email không hợp lệ.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Email hoặc mật khẩu không đúng.',
      'email-already-in-use' => 'Email này đã được đăng ký.',
      'weak-password' => 'Mật khẩu cần có ít nhất 6 ký tự.',
      'network-request-failed' => 'Không thể kết nối Firebase.',
      _ => error.message ?? 'Xác thực Firebase không thành công.',
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF2B4E8C);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 100),

                    // Facebook Logo
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'f',
                          style: TextStyle(
                            color: backgroundColor,
                            fontSize: 54,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Language Selector
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'English',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          ' • ',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          'Change',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 50),

                    // Email or Phone Field
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      cursorColor: Colors.white,
                      decoration: const InputDecoration(
                        hintText: 'Email or Phone',
                        hintStyle: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white38),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Password Field
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      cursorColor: Colors.white,
                      decoration: const InputDecoration(
                        hintText: 'Password',
                        hintStyle: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white38),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // CAPTCHA is generated and validated by the backend.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: _isLoadingCaptcha
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: backgroundColor,
                                        ),
                                      )
                                    : _captcha == null
                                    ? const Text(
                                        'Không tải được',
                                        style: TextStyle(
                                          color: backgroundColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : CaptchaCanvas(
                                        key: const Key('facebookCaptchaCanvas'),
                                        text: _captcha!.text,
                                      ),
                              ),
                              if (_captchaError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _captchaError!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tải CAPTCHA mới',
                          onPressed: _isLoadingCaptcha ? null : _loadCaptcha,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      key: const Key('facebookCaptchaInput'),
                      controller: _captchaController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      cursorColor: Colors.white,
                      decoration: const InputDecoration(
                        hintText: 'Enter CAPTCHA',
                        hintStyle: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white38),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // LOG IN Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed:
                            _isLoggingIn ||
                                _isLoadingCaptcha ||
                                _captcha == null
                            ? null
                            : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF33539E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
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
                                'LOG IN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Sign Up Link
                    GestureDetector(
                      onTap: _isLoggingIn ? null : _signUp,
                      child: const Text(
                        'Sign Up for Facebook',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Section: Forgot Password? and Help Icon
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 28),
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: _forgotPassword,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.8),
                    ),
                    child: const Center(
                      child: Text(
                        '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
