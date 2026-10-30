import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'bonus5_firebase_repository.dart';
import 'ongbantat_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? firebaseError;
  try {
    await Firebase.initializeApp();
  } catch (error) {
    firebaseError = error;
  }
  runApp(Bonus5App(firebaseInitializationError: firebaseError));
}

class Bonus5App extends StatefulWidget {
  const Bonus5App({
    this.api,
    this.firebaseRepository,
    this.firebaseInitializationError,
    super.key,
  });

  final OngBanTatApi? api;
  final Bonus5FirebaseRepository? firebaseRepository;
  final Object? firebaseInitializationError;

  @override
  State<Bonus5App> createState() => _Bonus5AppState();
}

class _Bonus5AppState extends State<Bonus5App> {
  late final OngBanTatApi _api;
  late final bool _ownsApi;
  Bonus5FirebaseRepository? _firebaseRepository;

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.api == null;
    _api = widget.api ?? OngBanTatApi();
    if (widget.firebaseInitializationError == null) {
      _firebaseRepository =
          widget.firebaseRepository ?? Bonus5FirebaseRepository();
    }
  }

  @override
  void dispose() {
    if (_ownsApi) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bonus 5',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3457A1)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: Bonus5LoginScreen(
        api: _api,
        firebaseRepository: _firebaseRepository,
        firebaseInitializationError: widget.firebaseInitializationError,
      ),
    );
  }
}

class Bonus5LoginScreen extends StatefulWidget {
  const Bonus5LoginScreen({
    required this.api,
    required this.firebaseRepository,
    this.firebaseInitializationError,
    super.key,
  });

  final OngBanTatApi api;
  final Bonus5FirebaseRepository? firebaseRepository;
  final Object? firebaseInitializationError;

  @override
  State<Bonus5LoginScreen> createState() => _Bonus5LoginScreenState();
}

class _Bonus5LoginScreenState extends State<Bonus5LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captchaKey = GlobalKey<Bonus5CaptchaFieldState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final captcha = _captchaKey.currentState?.captcha;
    if (captcha == null) {
      _message('CAPTCHA chưa tải xong.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final session = await widget.api.login(
        account: _accountController.text,
        password: _passwordController.text,
        captcha: captcha,
        captchaAnswer: _captchaController.text,
      );
      String? syncWarning;
      final firebase = widget.firebaseRepository;
      if (firebase != null && session.user.email.isNotEmpty) {
        try {
          await firebase.signInOrCreate(
            email: session.user.email,
            password: _passwordController.text,
          );
        } catch (error) {
          syncWarning =
              'Đăng nhập API thành công nhưng chưa đồng bộ được Firebase: $error';
        }
      } else if (firebase == null) {
        syncWarning =
            'Đăng nhập API thành công nhưng Firebase chưa được cấu hình.';
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => Bonus5ProfileScreen(
            api: widget.api,
            firebaseRepository: firebase,
            session: session,
            initialWarning: syncWarning,
          ),
        ),
      );
    } on OngBanTatApiException catch (error) {
      _message(error.message);
      await _captchaKey.currentState?.refresh();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openRegister() async {
    final result = await Navigator.of(context).push<Bonus5RegistrationResult>(
      MaterialPageRoute<Bonus5RegistrationResult>(
        builder: (_) => Bonus5RegisterScreen(
          api: widget.api,
          firebaseRepository: widget.firebaseRepository,
        ),
      ),
    );
    if (result != null && mounted) {
      _accountController.text = result.account;
      _passwordController.clear();
      _captchaController.clear();
      await _captchaKey.currentState?.refresh();
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Đăng nhập',
      subtitle: 'Bonus 5 • Ông Bán Tất + Firebase',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (widget.firebaseInitializationError != null)
              const _FirebaseWarning(),
            AuthTextField(
              key: const Key('bonus5LoginAccount'),
              controller: _accountController,
              label: 'Tài khoản',
              icon: Icons.person_outline,
              validator: _required('Vui lòng nhập tài khoản.'),
            ),
            const SizedBox(height: 14),
            AuthTextField(
              key: const Key('bonus5LoginPassword'),
              controller: _passwordController,
              label: 'Mật khẩu',
              icon: Icons.lock_outline,
              obscureText: true,
              validator: _required('Vui lòng nhập mật khẩu.'),
            ),
            const SizedBox(height: 14),
            Bonus5CaptchaField(
              key: _captchaKey,
              api: widget.api,
              controller: _captchaController,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _submitting ? null : _login,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ĐĂNG NHẬP'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _openRegister,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('SIGN UP'),
            ),
          ],
        ),
      ),
    );
  }
}

class Bonus5RegisterScreen extends StatefulWidget {
  const Bonus5RegisterScreen({
    required this.api,
    required this.firebaseRepository,
    super.key,
  });

  final OngBanTatApi api;
  final Bonus5FirebaseRepository? firebaseRepository;

  @override
  State<Bonus5RegisterScreen> createState() => _Bonus5RegisterScreenState();
}

class _Bonus5RegisterScreenState extends State<Bonus5RegisterScreen> {
  static final _accountPattern = RegExp(
    r'^[a-zA-Z0-9](?:[._](?![._])|[a-zA-Z0-9])+[a-zA-Z0-9]$',
  );
  static final _passwordPattern = RegExp(
    r'^(?=.*\d)(?=.*[a-zA-Z])[a-zA-Z0-9]{6,}$',
  );
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _formKey = GlobalKey<FormState>();
  final _captchaKey = GlobalKey<Bonus5CaptchaFieldState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _captchaController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final captcha = _captchaKey.currentState?.captcha;
    if (captcha == null) {
      _message('CAPTCHA chưa tải xong.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final apiMessage = await widget.api.register(
        account: _accountController.text,
        password: _passwordController.text,
        email: _emailController.text,
        captcha: captcha,
        captchaAnswer: _captchaController.text,
      );
      String message = apiMessage;
      final firebase = widget.firebaseRepository;
      if (firebase != null) {
        try {
          await firebase.signInOrCreate(
            email: _emailController.text,
            password: _passwordController.text,
          );
          await firebase.saveProfile(
            account: _accountController.text.trim(),
            profile: OngBanTatUser(
              id: 0,
              account: _accountController.text.trim(),
              email: _emailController.text.trim(),
              name: '',
              phone: '',
              gender: 'other',
              description: '',
            ),
          );
          await firebase.signOut();
          message = '$message Đã lưu bản đăng ký lên Firebase.';
        } catch (error) {
          message = '$message Tuy nhiên chưa đồng bộ được Firebase: $error';
        }
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đăng ký hoàn tất'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đăng nhập'),
            ),
          ],
        ),
      );
      if (mounted) {
        Navigator.pop(
          context,
          Bonus5RegistrationResult(
            account: _accountController.text.trim(),
            email: _emailController.text.trim(),
          ),
        );
      }
    } on OngBanTatApiException catch (error) {
      _message(error.message);
      await _captchaKey.currentState?.refresh();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Đăng ký',
      subtitle: 'Tạo tài khoản Ông Bán Tất',
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthTextField(
              key: const Key('bonus5RegisterAccount'),
              controller: _accountController,
              label: 'Account (*)',
              icon: Icons.person_outline,
              validator: (value) {
                if (!_accountPattern.hasMatch(value?.trim() ?? '')) {
                  return 'Tối thiểu 3 ký tự; chỉ chữ, số, dấu chấm hoặc gạch dưới.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AuthTextField(
              key: const Key('bonus5RegisterPassword'),
              controller: _passwordController,
              label: 'Password (*)',
              icon: Icons.lock_outline,
              obscureText: true,
              validator: (value) {
                if (!_passwordPattern.hasMatch(value ?? '')) {
                  return 'Ít nhất 6 ký tự, gồm cả chữ và số, không ký tự đặc biệt.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AuthTextField(
              key: const Key('bonus5RegisterEmail'),
              controller: _emailController,
              label: 'Email (*)',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) => _emailPattern.hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Email không đúng định dạng.',
            ),
            const SizedBox(height: 14),
            Bonus5CaptchaField(
              key: _captchaKey,
              api: widget.api,
              controller: _captchaController,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _register,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1),
                label: const Text('GỬI THÔNG TIN ĐĂNG KÝ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Bonus5RegistrationResult {
  const Bonus5RegistrationResult({required this.account, required this.email});

  final String account;
  final String email;
}

class Bonus5ProfileScreen extends StatefulWidget {
  const Bonus5ProfileScreen({
    required this.api,
    required this.firebaseRepository,
    required this.session,
    this.initialWarning,
    super.key,
  });

  final OngBanTatApi api;
  final Bonus5FirebaseRepository? firebaseRepository;
  final OngBanTatSession session;
  final String? initialWarning;

  @override
  State<Bonus5ProfileScreen> createState() => _Bonus5ProfileScreenState();
}

class _Bonus5ProfileScreenState extends State<Bonus5ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  OngBanTatUser? _profile;
  String _gender = 'other';
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialWarning != null) _message(widget.initialWarning!);
    });
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.api.getUser(widget.session);
      _apply(profile);
      try {
        await widget.firebaseRepository?.saveProfile(
          profile: profile,
          account: widget.session.user.account,
        );
      } catch (error) {
        if (mounted) {
          _message('Đã tải hồ sơ nhưng chưa đồng bộ Firebase: $error');
        }
      }
    } on OngBanTatApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(OngBanTatUser profile) {
    _profile = profile;
    _nameController.text = profile.name;
    _phoneController.text = profile.phone;
    _descriptionController.text = profile.description;
    _gender = {'male', 'female', 'other'}.contains(profile.gender)
        ? profile.gender
        : 'other';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _profile == null) return;
    setState(() => _saving = true);
    try {
      final message = await widget.api.updateUser(
        session: widget.session,
        name: _nameController.text,
        phone: _phoneController.text,
        gender: _gender,
        description: _descriptionController.text,
      );
      final updated = _profile!.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        gender: _gender,
        description: _descriptionController.text.trim(),
      );
      _profile = updated;
      try {
        await widget.firebaseRepository?.saveProfile(
          profile: updated,
          account: widget.session.user.account,
        );
        _message('$message Đã đồng bộ Firebase.');
      } catch (error) {
        _message('$message Chưa đồng bộ được Firebase: $error');
      }
    } on OngBanTatApiException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _saving = true);
    try {
      try {
        await widget.api.logout(widget.session);
      } catch (_) {
        // Local logout must remain available if the remote session expired.
      }
      await widget.firebaseRepository?.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => Bonus5LoginScreen(
            api: widget.api,
            firebaseRepository: widget.firebaseRepository,
          ),
        ),
        (_) => false,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin người dùng'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _saving ? null : _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    initialValue: _profile!.id.toString(),
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Mã tài khoản',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: _profile!.email,
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    key: const Key('bonus5ProfileName'),
                    controller: _nameController,
                    label: 'Họ và tên',
                    icon: Icons.badge_outlined,
                    validator: _required('Vui lòng nhập họ tên.'),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Giới tính',
                      prefixIcon: Icon(Icons.wc),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Nam')),
                      DropdownMenuItem(value: 'female', child: Text('Nữ')),
                      DropdownMenuItem(value: 'other', child: Text('Khác')),
                    ],
                    onChanged: (value) => setState(() => _gender = value!),
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    key: const Key('bonus5ProfilePhone'),
                    controller: _phoneController,
                    label: 'Số điện thoại',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('bonus5ProfileDescription'),
                    controller: _descriptionController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: const Text('CẬP NHẬT VÀ ĐỒNG BỘ FIREBASE'),
                  ),
                ],
              ),
            ),
    );
  }
}

class Bonus5CaptchaField extends StatefulWidget {
  const Bonus5CaptchaField({
    required this.api,
    required this.controller,
    super.key,
  });

  final OngBanTatApi api;
  final TextEditingController controller;

  @override
  State<Bonus5CaptchaField> createState() => Bonus5CaptchaFieldState();
}

class Bonus5CaptchaFieldState extends State<Bonus5CaptchaField> {
  OngBanTatCaptcha? captcha;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      captcha = null;
      widget.controller.clear();
    });
    try {
      final result = await widget.api.createCaptcha();
      if (mounted) setState(() => captcha = result);
    } on OngBanTatApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _loading
                    ? const CircularProgressIndicator()
                    : captcha == null
                    ? Text(_error ?? 'Không tải được CAPTCHA')
                    : SvgPicture.string(
                        captcha!.svg,
                        height: 50,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            IconButton(
              tooltip: 'Tạo CAPTCHA mới',
              onPressed: _loading ? null : refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('bonus5CaptchaInput'),
          controller: widget.controller,
          maxLength: 4,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Mã CAPTCHA (*)',
            prefixIcon: Icon(Icons.verified_user_outlined),
            counterText: '',
          ),
          validator: _required('Vui lòng nhập CAPTCHA.'),
        ),
      ],
    );
  }
}

class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF23395D), Color(0xFF3457A1), Color(0xFF6C63A8)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  elevation: 12,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showBack)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              tooltip: 'Quay lại',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                            ),
                          ),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}

class _FirebaseWarning extends StatelessWidget {
  const _FirebaseWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: const Text(
        'Chưa cấu hình Firebase. API Ông Bán Tất vẫn dùng được nhưng dữ liệu chưa được đồng bộ.',
      ),
    );
  }
}

String? Function(String?) _required(String message) {
  return (value) => (value?.trim().isEmpty ?? true) ? message : null;
}
