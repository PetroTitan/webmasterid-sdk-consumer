// Host-side tests: what this app does on its own, without the native SDK.
// (The SDK itself is exercised on devices and simulators by the builds.)
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webmasterid_consumer/main.dart';
import 'package:webmasterid_flutter/webmasterid_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('no decision stored means null — the SDK then collects nothing', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await ConsentStore().load(), isNull);
  });

  test('a stored decision is restored by name', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ConsentStore();
    await store.save(WebmasterIDConsent.restricted);
    expect(await store.load(), WebmasterIDConsent.restricted);
  });

  test('a session is an opaque account key, or nobody', () async {
    SharedPreferences.setMockInitialValues({});
    final s = Session();
    expect(await s.restore(), isNull);
    await s.signIn('demo-account-1');
    expect(await s.restore(), 'demo-account-1');
    await s.signOut();
    expect(await s.restore(), isNull);
  });

  test('the property id is the public ap_ shape', () {
    expect(RegExp(r'^ap_[0-9a-z]{16}$').hasMatch(appPropertyId), isTrue);
  });
}
