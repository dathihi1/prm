import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'firebase_notification_service.dart';
import 'firebase_profile_repository.dart';
import 'user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.user,
    required this.repository,
    super.key,
  });

  final User user;
  final FirebaseProfileRepository repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _avatarBytes;
  String _avatarContentType = 'image/jpeg';
  String? _avatarUrl;
  bool _hasLoadedProfile = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await FirebaseNotificationService.instance.initialize(
        onToken: (token) =>
            widget.repository.saveFcmToken(uid: widget.user.uid, token: token),
      );
    } catch (error) {
      if (mounted) _showMessage('Không thể bật thông báo: $error');
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _applyProfile(UserProfile profile) {
    if (_hasLoadedProfile) return;
    _hasLoadedProfile = true;
    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phone;
    _addressController.text = profile.address;
    _avatarUrl = profile.avatarUrl;
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarBytes = bytes;
      _avatarContentType = image.mimeType ?? 'image/jpeg';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      var avatarUrl = _avatarUrl;
      if (_avatarBytes != null) {
        avatarUrl = await widget.repository.uploadAvatar(
          uid: widget.user.uid,
          bytes: _avatarBytes!,
          contentType: _avatarContentType,
        );
      }

      await widget.repository.saveProfile(
        user: widget.user,
        fullName: _fullNameController.text,
        phone: _phoneController.text,
        address: _addressController.text,
        avatarUrl: avatarUrl,
      );

      if (!mounted) return;
      setState(() {
        _avatarUrl = avatarUrl;
        _avatarBytes = null;
      });
      _showMessage('Đã cập nhật thông tin cá nhân.');
    } on FirebaseException catch (error) {
      if (mounted) _showMessage(error.message ?? 'Không thể lưu thông tin.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.repository.removeFcmToken(widget.user.uid);
      await FirebaseNotificationService.instance.dispose();
    } finally {
      await FirebaseAuth.instance.signOut();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile>(
      stream: widget.repository.watchProfile(widget.user),
      builder: (context, snapshot) {
        if (snapshot.hasData) _applyProfile(snapshot.data!);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Thông tin cá nhân'),
            actions: [
              IconButton(
                tooltip: 'Đăng xuất',
                onPressed: _isSaving ? null : _signOut,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body:
              snapshot.connectionState == ConnectionState.waiting &&
                  !_hasLoadedProfile
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 58,
                              backgroundColor: const Color(0xFFE7ECF8),
                              foregroundImage: _avatarBytes != null
                                  ? MemoryImage(_avatarBytes!)
                                  : (_avatarUrl?.isNotEmpty ?? false)
                                  ? NetworkImage(_avatarUrl!)
                                  : null,
                              child:
                                  _avatarBytes == null &&
                                      (_avatarUrl?.isEmpty ?? true)
                                  ? const Icon(
                                      Icons.person,
                                      size: 64,
                                      color: Color(0xFF2B4E8C),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: IconButton.filled(
                                tooltip: 'Chọn avatar',
                                onPressed: _isSaving ? null : _pickAvatar,
                                icon: const Icon(Icons.camera_alt),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.user.email ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          key: const Key('profileFullName'),
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Vui lòng nhập họ tên.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('profilePhone'),
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại',
                            prefixIcon: Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final phone = value?.trim() ?? '';
                            if (phone.isEmpty) {
                              return 'Vui lòng nhập số điện thoại.';
                            }
                            if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(phone)) {
                              return 'Số điện thoại không hợp lệ.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('profileAddress'),
                          controller: _addressController,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Địa chỉ',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Vui lòng nhập địa chỉ.'
                              : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            key: const Key('saveProfileButton'),
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(_isSaving ? 'ĐANG LƯU...' : 'CẬP NHẬT'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
