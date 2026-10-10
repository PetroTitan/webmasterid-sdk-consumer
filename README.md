# webmasterid_consumer

A minimal customer app for the WebmasterID Flutter SDK. It follows the
installation guide at https://webmasterid.com/docs/mobile-sdk step by step and
nothing else: the package from pub.dev, the launch order (property id check →
stored consent → initialize → lifecycle observer → session → identify or
resetIdentity), a test event, and the diagnostics before and after an explicit
flush that say whether the server took it.

Its `lib/main.dart` and `codemagic.yaml` are the guide's, byte for byte. Besides
`webmasterid_flutter` it uses `shared_preferences`, only to store the consent
decision and the demo session.

It contains no secret and needs no access to any WebmasterID repository. The
SDK installs from pub.dev; the native SDKs it pins come from the public Swift
package (iOS) and from `https://webmasterid.com/sdk/maven` (Android).

## Status

**Published 2026-10-07.** `webmasterid_flutter` 0.3.0 is on pub.dev; the iOS binary
package it pins is `https://github.com/PetroTitan/webmasterid-mobile-sdk` 1.2.0 and the
Android artifacts are at `https://webmasterid.com/sdk/maven` (0.2.0). `flutter pub get`
in this app installs all three without any credential.

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

In the app: **Allow analytics** → **Send test event**. Diagnostics should show
`acknowledged: 2`, `last status: success`. Then reload your app's page in the
dashboard: the card reads **Receiving events** with the time of the last event.

**Delivery differs by platform.** `track`, `screenView` and `ctaTap` only queue.
On iOS events leave the device only when the app calls `flush()` or reports the
background transition — this app registers `WebmasterIDLifecycleObserver` for
that, and its test event calls `flush()` once. On Android the native SDK also
sends about 5 seconds after an event, so an app without the observer works on
Android and keeps its events on iOS.

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
