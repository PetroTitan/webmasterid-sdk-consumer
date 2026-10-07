# webmasterid_consumer

A minimal customer app for the WebmasterID Flutter SDK. It follows the
installation guide at https://webmasterid.com/docs/mobile-sdk step by step and
nothing else: one `pubspec.yaml` line, the launch order (consent → initialize →
session → identify or resetIdentity), a test event, and the diagnostics that
say whether the server took it.

It contains no secret and needs no access to any WebmasterID repository. The
SDK installs from pub.dev; the native SDKs it pins come from the public Swift
package (iOS) and from `https://webmasterid.com/sdk/maven` (Android).

## Run it

```sh
flutter pub get
flutter run --dart-define=WMID_APP_PROPERTY_ID=ap_xxxxxxxxxxxxxxxx
```

`WMID_APP_PROPERTY_ID` is your app property's **public** id from the dashboard
(iOS apps / Android apps). `WMID_ENDPOINT` is only for an acceptance run against
an endpoint WebmasterID gave you; leave it unset for production.

In the app: **Allow analytics** → **Send test event**. Diagnostics should show
`acknowledged: 2`, `last status: success`. Then reload your app's page in the
dashboard: the card reads **Receiving events** with the time of the last event.

## Build it on CI

- `codemagic.yaml` — Codemagic: analyze, test, Android release APK (R8), iOS
  Simulator build. Manual start, no signing, no secret, read access to this
  repository only.
- `.github/workflows/build.yml` — the same on GitHub Actions (`workflow_dispatch`).

## Tests

`flutter test` runs the host-side tests (`test/consumer_test.dart`): the consent
store, the session store and the shape of the property id. The SDK itself runs on
devices and simulators, in the builds above.
