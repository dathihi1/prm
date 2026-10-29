class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.address,
    this.avatarUrl,
  });

  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final String address;
  final String? avatarUrl;

  factory UserProfile.fromMap(String uid, Map<Object?, Object?>? data) {
    String read(String key) => data?[key]?.toString() ?? '';

    return UserProfile(
      uid: uid,
      email: read('email'),
      fullName: read('fullName'),
      phone: read('phone'),
      address: read('address'),
      avatarUrl: read('avatarUrl').isEmpty ? null : read('avatarUrl'),
    );
  }
}
