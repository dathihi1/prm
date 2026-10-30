# Facebook Login + Firebase Profile + FCM

Màn hình Facebook sử dụng:

- Firebase Authentication (Email/Password) để đăng ký, đăng nhập, đăng xuất và đặt lại mật khẩu.
- Firebase Realtime Database để lưu/cập nhật họ tên, số điện thoại, địa chỉ, URL avatar và mã đăng ký FCM.
- Firebase Storage để lưu file avatar. Firestore là cơ sở dữ liệu tài liệu, không nên dùng để lưu trực tiếp file ảnh.
- Firebase Cloud Messaging và local notification để nhận thông báo ở foreground, background và terminated.
- CAPTCHA dùng một lần được backend tạo và xác minh trước khi gọi Firebase Auth.

## 1. Cấu hình Firebase

1. Tạo Firebase project và thêm Android app với package name `com.example.prm`.
2. Tải `google-services.json` vào `android/app/google-services.json`.
3. Trong **Authentication > Sign-in method**, bật **Email/Password**.
4. Tạo **Realtime Database** và **Storage**.
5. Cài Firebase CLI, đăng nhập rồi deploy rules có sẵn:

```powershell
firebase use --add
firebase deploy --only database,storage
```

Có thể dùng FlutterFire CLI thay cho bước tải file thủ công:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

Không commit `google-services.json` nếu repository được chia sẻ công khai.

## 2. Chạy backend CAPTCHA

```powershell
dart run backend/server.dart
```

Android Emulator truy cập máy host qua `http://10.0.2.2:8080`. Với thiết bị thật, truyền IP LAN của máy chạy backend:

```powershell
flutter run -t lib/main_facebook.dart --dart-define=FACEBOOK_API_URL=http://192.168.1.10:8080
```

## 3. Chạy ứng dụng

```powershell
flutter run -t lib/main_facebook.dart
```

Nhập email/mật khẩu và CAPTCHA. Nếu chưa có tài khoản, bấm **Sign Up for Facebook**; nếu đã có tài khoản, bấm **LOG IN**. Sau đăng nhập, ứng dụng tự chuyển sang màn hình profile.

## Dữ liệu Firebase

```text
Realtime Database
users/{uid}/profile
  email, fullName, phone, address, avatarUrl, updatedAt
users/{uid}/messaging
  fcmToken, platform, updatedAt

Storage
users/{uid}/avatar.jpg (hoặc avatar.png)
```

FCM registration ID được tạo sau khi người dùng cấp quyền thông báo và lưu tại `users/{uid}/messaging/fcmToken`. Dùng giá trị này làm thiết bị đích khi gửi test message từ Firebase Console hoặc từ backend dùng Firebase Admin SDK. Khi app đang mở, thông báo được hiển thị qua notification channel `high_importance_channel`; background/terminated do hệ điều hành và FCM xử lý.

## Kiểm thử

```powershell
flutter analyze
flutter test
```

Màn hình Instagram và backend demo Instagram vẫn giữ nguyên:

```powershell
flutter run -t lib/main_instagram.dart
```

## Bonus 5: API + Firebase

Nhánh `bonus5` bổ sung luồng hoàn chỉnh:

- Đăng nhập và đăng ký bằng API tại `https://backend.ongbantat.io.vn`.
- CAPTCHA SVG được tải từ máy chủ và gửi theo định dạng `captchaId|answer`.
- Lấy/cập nhật hồ sơ người dùng bằng API trang 16.
- Đồng bộ bản sao hồ sơ vào `users/{firebaseUid}/bonus5` trong Firebase Realtime Database.
- Không lưu mật khẩu hoặc access token của API lên Firebase.

Chạy Bonus 5 (đây cũng là entrypoint mặc định):

```powershell
flutter run
# hoặc
flutter run -t lib/main_bonus5.dart
```

Trước khi chạy, đặt `google-services.json` vào `android/app/` và bật Email/Password trong Firebase Authentication. File cấu hình này được `.gitignore` loại khỏi GitHub.
