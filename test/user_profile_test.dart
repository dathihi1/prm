import 'package:flutter_test/flutter_test.dart';
import 'package:prm/user_profile.dart';

void main() {
  test('creates a profile from Realtime Database values', () {
    final profile = UserProfile.fromMap('user-1', {
      'email': 'student@example.com',
      'fullName': 'Nguyễn Văn A',
      'phone': '0912345678',
      'address': 'Hà Nội',
      'avatarUrl': 'https://example.com/avatar.jpg',
    });

    expect(profile.uid, 'user-1');
    expect(profile.email, 'student@example.com');
    expect(profile.fullName, 'Nguyễn Văn A');
    expect(profile.phone, '0912345678');
    expect(profile.address, 'Hà Nội');
    expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
  });

  test('treats a blank avatar URL as no avatar', () {
    final profile = UserProfile.fromMap('user-1', {'avatarUrl': ''});

    expect(profile.avatarUrl, isNull);
  });
}
