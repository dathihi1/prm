import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prm/main_bonus5.dart';
import 'package:prm/ongbantat_api.dart';

void main() {
  testWidgets('SIGN UP opens the Bonus 5 registration screen', (tester) async {
    final api = _FakeOngBanTatApi();
    await tester.pumpWidget(
      MaterialApp(home: Bonus5LoginScreen(api: api, firebaseRepository: null)),
    );
    await tester.pumpAndSettle();

    final signUpButton = find.widgetWithText(OutlinedButton, 'SIGN UP');
    await tester.ensureVisible(signUpButton);
    await tester.tap(signUpButton);
    await tester.pumpAndSettle();

    expect(find.text('Đăng ký'), findsOneWidget);
    expect(find.byKey(const Key('bonus5RegisterAccount')), findsOneWidget);
    expect(find.byKey(const Key('bonus5RegisterPassword')), findsOneWidget);
    expect(find.byKey(const Key('bonus5RegisterEmail')), findsOneWidget);

    api.close();
  });
}

class _FakeOngBanTatApi extends OngBanTatApi {
  _FakeOngBanTatApi() : super(baseUrl: 'http://unused');

  @override
  Future<OngBanTatCaptcha> createCaptcha() async {
    return const OngBanTatCaptcha(
      id: 1,
      svg: '<svg xmlns="http://www.w3.org/2000/svg"></svg>',
    );
  }
}
