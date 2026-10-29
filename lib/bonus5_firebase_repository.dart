import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'ongbantat_api.dart';

/// Mirrors Bonus 5 profile data to Firebase.
/// Passwords and Ông Bán Tất access tokens are deliberately never persisted.
class Bonus5FirebaseRepository {
  Bonus5FirebaseRepository({FirebaseAuth? auth, FirebaseDatabase? database})
    : _auth = auth ?? FirebaseAuth.instance,
      _database = database ?? FirebaseDatabase.instance;

  final FirebaseAuth _auth;
  final FirebaseDatabase _database;

  User? get currentUser => _auth.currentUser;

  Future<User> signInOrCreate({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user!;
    } on FirebaseAuthException catch (error) {
      if (error.code != 'user-not-found' &&
          error.code != 'invalid-credential' &&
          error.code != 'invalid-login-credentials') {
        rethrow;
      }
    }

    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user!;
    } on FirebaseAuthException catch (error) {
      if (error.code != 'email-already-in-use') rethrow;
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user!;
    }
  }

  Future<void> saveProfile({
    required OngBanTatUser profile,
    String? account,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw StateError('Chưa đăng nhập Firebase để đồng bộ hồ sơ.');
    }
    await _database.ref('users/${firebaseUser.uid}/bonus5').update({
      'ongBanTatUserId': profile.id,
      'account': account ?? profile.account,
      'email': profile.email,
      'name': profile.name,
      'phone': profile.phone,
      'gender': profile.gender,
      'description': profile.description,
      'source': 'ongbantat.io.vn',
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> signOut() => _auth.signOut();
}
