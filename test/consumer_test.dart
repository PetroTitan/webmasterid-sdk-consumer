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

  // The property id. This test used to assert that the DEFAULT id had the
  // public shape — and the default was a placeholder that did, which is how a
  // build could start and send to no property. There is no default now.
  group('the property id', () {
    test('a build without WMID_APP_PROPERTY_ID has no id at all', () {
      // `flutter test` passes no --dart-define, exactly like a build that forgot it.
      expect(appPropertyId, isEmpty);
    });

    test('missing: refused', () {
      expect(() => requireAppPropertyId(''), throwsStateError);
    });

    test("the guide's old placeholder: refused by name", () {
      expect(
        () => requireAppPropertyId('ap_xxxxxxxxxxxxxxxx'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('placeholder'))),
      );
    });

    test('anything that is not a public property id: refused, without repeating it', () {
      for (final value in ['ap_YOUR_PROPERTY_ID', 'AP_0123456789ABCDEF', 'ap_0123', ' ap_0123456789abcdef']) {
        expect(
          () => requireAppPropertyId(value),
          throwsA(isA<StateError>().having((e) => e.message, 'message', isNot(contains(value)))),
          reason: value,
        );
      }
    });

    test('a public property id passes unchanged', () {
      expect(requireAppPropertyId('ap_0123456789abcdef'), 'ap_0123456789abcdef');
    });

    test('*** startWebmasterID refuses BEFORE the SDK: a StateError, not a platform error ***', () async {
      // Were the SDK reached first, its platform channel (absent in a host
      // test) would answer with a PlatformException instead.
      SharedPreferences.setMockInitialValues({});
      await expectLater(startWebmasterID(), throwsA(isA<StateError>()));
    });
  });
}
