# webmasterid_consumer

A minimal customer app for the WebmasterID Flutter SDK. It follows the
installation guide at https://webmasterid.com/docs/mobile-sdk step by step and
nothing else: the package from pub.dev, the launch order (property id check →
stored consent → initialize → lifecycle observer → session → identify or
resetIdentity), a test event, and the diagnostics at once and ten seconds later
that say whether the server took it — no flush(): the SDK delivers on its own.

Its `lib/main.dart` and `codemagic.yaml` are the guide's, byte for byte. Besides
`webmasterid_flutter` it uses `shared_preferences`, only to store the consent
decision and the demo session.

It contains no secret and needs no access to any WebmasterID repository. The
SDK installs from pub.dev; the native SDKs it pins come from the public Swift
package (iOS) and from `https://webmasterid.com/sdk/maven` (Android).

## Status

**Candidate — `webmasterid_flutter` 0.4.0 is NOT published yet.** This branch
depends on `^0.4.0`, which pins the iOS binary package
`https://github.com/PetroTitan/webmasterid-mobile-sdk` 1.3.0 and the Android
artifacts 0.3.0 at `https://webmasterid.com/sdk/maven`. Until those are published
`flutter pub get` cannot resolve it from pub.dev, and `pubspec.lock` still records
0.3.0; regenerate it from pub.dev after the publication, before merging.
(Published today: 0.3.0, with iOS 1.2.0 and Android 0.2.0.)

## Run it

```sh
flutter pub get
flutter run --dart-define=WMID_APP_PROPERTY_ID=ap_YOUR_PROPERTY_ID
```

`WMID_APP_PROPERTY_ID` is your app property's **public** id from the dashboard
(iOS apps / Android apps). Replace `ap_YOUR_PROPERTY_ID` with it: the app has no
default id, and without a real one it stops at start with a StateError that
says what is wrong — before the SDK is touched and before any request. In
Codemagic, set `WMID_APP_PROPERTY_ID` in `codemagic.yaml`; the build stops at
its first step while it is empty. `WMID_ENDPOINT` is only for an acceptance run against
an endpoint WebmasterID gave you; leave it unset for production.

In the app: **Allow analytics** → **Send test event**. Ten seconds later the
Diagnostics show `queued: 0`, `acknowledged: 2`, `last status: success`. Then
reload your app's page in the dashboard: the card reads **Receiving events** with
the time of the last event.

**Delivery is the SDK's, on iOS and Android.** `track`, `screenView` and `ctaTap`
only queue; the SDK sends about 5 seconds after the first queued event (later
events join that request), when the app goes to the background, and after the
next launch for anything left, and it retries failures on its own. **Deliver
now** calls `flush()` — a boundary you choose, not something to call after every
event. `WebmasterIDLifecycleObserver` is registered once and records `app_open`;
delivery does not depend on it. Nothing runs after the app is suspended,
force-quit or terminated: undelivered events stay on the device until it next
runs.

## Build it on CI

- `codemagic.yaml` — Codemagic: analyze, test, Android release APK (R8), iOS
  Simulator build. Manual start, no signing, no secret, read access to this
  repository only. Its first step prints `this build sends to property ap_…`.
  Your own release workflow passes the same `--dart-define` to `flutter build
  ipa` and `flutter build appbundle` (the guide's section 7 shows it); define
  `WMID_APP_PROPERTY_ID` in one place only — `vars` or a variable group.
- `.github/workflows/build.yml` — the same on GitHub Actions (`workflow_dispatch`).

## Tests

`flutter test` runs the host-side tests (`test/consumer_test.dart`): the consent
store, the session store and the shape of the property id. The SDK itself runs on
devices and simulators, in the builds above.
