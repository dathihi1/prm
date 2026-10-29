import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'user_profile.dart';

class FirebaseProfileRepository {
  FirebaseProfileRepository({
    FirebaseDatabase? database,
    FirebaseStorage? storage,
  }) : _database = database ?? FirebaseDatabase.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseDatabase _database;
  final FirebaseStorage _storage;

  DatabaseReference _userRef(String uid) => _database.ref('users/$uid');

  Stream<UserProfile> watchProfile(User user) {
    return _userRef(user.uid).child('profile').onValue.map((event) {
      final value = event.snapshot.value;
      final map = value is Map<Object?, Object?> ? value : null;
      final profile = UserProfile.fromMap(user.uid, map);
      return UserProfile(
        uid: user.uid,
        email: profile.email.isEmpty ? user.email ?? '' : profile.email,
        fullName: profile.fullName,
        phone: profile.phone,
        address: profile.address,
        avatarUrl: profile.avatarUrl,
      );
    });
  }

  Future<void> saveProfile({
    required User user,
    required String fullName,
    required String phone,
    required String address,
    String? avatarUrl,
  }) async {
    await _userRef(user.uid).child('profile').update({
      'uid': user.uid,
      'email': user.email ?? '',
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'avatarUrl': avatarUrl ?? '',
      'updatedAt': ServerValue.timestamp,
    });

    if (fullName.trim().isNotEmpty && user.displayName != fullName.trim()) {
      await user.updateDisplayName(fullName.trim());
    }
    if (avatarUrl != null && user.photoURL != avatarUrl) {
      await user.updatePhotoURL(avatarUrl);
    }
  }

  Future<String> uploadAvatar({
    required String uid,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final extension = contentType == 'image/png' ? 'png' : 'jpg';
    final reference = _storage.ref('users/$uid/avatar.$extension');
    await reference.putData(bytes, SettableMetadata(contentType: contentType));
    return reference.getDownloadURL();
  }

  Future<void> saveFcmToken({
    required String uid,
    required String token,
  }) async {
    await _userRef(uid).child('messaging').update({
      'fcmToken': token,
      'platform': 'android',
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> removeFcmToken(String uid) async {
    await _userRef(uid).child('messaging').remove();
  }
}
