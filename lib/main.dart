// A minimal customer app for the WebmasterID Flutter SDK.
//
// It does, in this order, what the installation guide says every app must do
// at launch: restore the consent decision, start the SDK with it, restore the
// app's own session, confirm who it is (or end the session an earlier launch
// left behind), and only then send events.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webmasterid_flutter/webmasterid_flutter.dart';

/// The app property's PUBLIC id, from the dashboard (iOS apps / Android apps),
/// given at build time: --dart-define=WMID_APP_PROPERTY_ID=ap_…
/// It ships inside the app and addresses your property; it is not a secret and
/// it authenticates nothing. Never put a WebmasterID server key in an app.
///
/// There is deliberately NO default. A default that looks like an id builds,
/// starts and sends — to no property — and the server answers every unknown id
/// with the same 403, so nothing would say why nothing arrives.
const String appPropertyId = String.fromEnvironment('WMID_APP_PROPERTY_ID');

/// The placeholder earlier versions of the installation guide printed.
const String guidePlaceholderPropertyId = 'ap_xxxxxxxxxxxxxxxx';

/// The id this build will use — or a StateError when it is missing, still a
/// placeholder, or not a public property id. It runs before the SDK is touched,
/// so a misconfigured build fails here, on the device, and sends nothing.
/// The message never repeats the value: whatever was configured by mistake
/// stays out of logs.
String requireAppPropertyId(String value) {
  if (value.isEmpty) {
    throw StateError(
      'WMID_APP_PROPERTY_ID is not set. Build with '
      '--dart-define=WMID_APP_PROPERTY_ID=<the Public property ID from the dashboard>.',
    );
  }
  if (value == guidePlaceholderPropertyId) {
    throw StateError(
      "WMID_APP_PROPERTY_ID is still the guide's placeholder. Use the Public "
      "property ID shown on your app's card in the dashboard.",
    );
  }
  if (!RegExp(r'^ap_[0-9a-z]{16}$').hasMatch(value)) {
    throw StateError(
      'WMID_APP_PROPERTY_ID is not a public property id: "ap_" followed by '
      '16 lowercase letters or digits, as shown in the dashboard.',
    );
  }
  return value;
}

/// Leave empty for production. Set only for an acceptance run against an
/// endpoint WebmasterID gave you for testing (https://host[:port]).
const String endpoint = String.fromEnvironment('WMID_ENDPOINT');

/// Where this app keeps the person's consent decision between launches. The
/// SDK never stores it: an app restores the decision at every launch.
class ConsentStore {
  static const _key = 'webmasterid.consent';

  Future<WebmasterIDConsent?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_key);
    if (name == null) return null;
    for (final consent in WebmasterIDConsent.values) {
      if (consent.name == name) return consent;
    }
    return null;
  }

  Future<void> save(WebmasterIDConsent consent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, consent.name);
  }
}

/// The app's own notion of who is signed in: an opaque account key, or null.
/// A real app restores this from its auth layer; this one keeps it locally.
class Session {
  static const _key = 'app.accountKey';

  Future<String?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> signIn(String accountKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, accountKey);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final consentStore = ConsentStore();
final session = Session();

/// The launch order. Everything the SDK needs happens here, once per process.
Future<WebmasterID> startWebmasterID() async {
  // 0. The build's property id — refused here, before the SDK, when it is wrong.
  final propertyId = requireAppPropertyId(appPropertyId);

  // 1. The decision this app stored — null if the person has not decided yet.
  final WebmasterIDConsent? consent = await consentStore.load();

  // 2. One client, started with that decision. Analytics only: no purchase
  //    collector is created, so no store framework is involved at runtime.
  final webmasterID = await WebmasterID.initialize(
    appPropertyId: propertyId,
    consent: consent,
    purchases: false,
    endpoint: endpoint.isEmpty ? null : Uri.parse(endpoint),
  );

  // 3. YOUR session, restored the way your app restores it.
  final accountKey = await session.restore();

  // 4. Confirm who it is — or end the session an earlier launch left behind.
  if (accountKey != null) {
    try {
      await webmasterID.identify(accountKey);
    } on PlatformException catch (e) {
      // iOS before the device's first unlock: the Keychain is not reachable,
      // nothing was registered — identify again later. Anything else is real.
      if (e.code != 'keychain_unavailable') rethrow;
    }
  } else if ((await webmasterID.diagnostics())?.deliveryHold ==
      'identityNotRestored') {
    await webmasterID.resetIdentity();
  }
  return webmasterID;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ConsumerApp());
}

class ConsumerApp extends StatelessWidget {
  const ConsumerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'WebmasterID consumer',
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  WebmasterID? _webmasterID;
  WebmasterIDDiagnostics? _diagnostics;
  String? _accountKey;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final webmasterID = await startWebmasterID();
      final accountKey = await session.restore();
      setState(() {
        _webmasterID = webmasterID;
        _accountKey = accountKey;
      });
      _say('SDK started for $appPropertyId'
          '${endpoint.isEmpty ? '' : ' → $endpoint'}');
      await _refresh();
    } catch (e) {
      _say('start failed: $e');
    }
  }

  // The SDK observes nothing on its own: the app forwards the lifecycle, and
  // going to the background delivers what is queued. On iOS nothing else
  // sends: without this (or WebmasterIDLifecycleObserver, or flush()), events
  // wait on the device. On Android the native SDK also sends about 5 seconds
  // after an event.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final webmasterID = _webmasterID;
    if (webmasterID == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        webmasterID.applicationDidBecomeActive();
      case AppLifecycleState.paused:
        webmasterID.applicationDidEnterBackground();
      default:
        break;
    }
  }

  Future<void> _setConsent(WebmasterIDConsent consent) async {
    final webmasterID = _webmasterID;
    if (webmasterID == null) return;
    await consentStore.save(consent);
    await webmasterID.setConsent(consent);
    _say('consent → ${consent.name}');
    await _refresh();
  }

  Future<void> _signIn() async {
    final webmasterID = _webmasterID;
    if (webmasterID == null) return;
    // Your own opaque account key — never an e-mail address, which is refused.
    const accountKey = 'demo-account-1';
    await session.signIn(accountKey);
    try {
      await webmasterID.identify(accountKey);
      _say('identified as $accountKey');
    } on PlatformException catch (e) {
      _say('identify refused: ${e.code}');
    }
    setState(() => _accountKey = accountKey);
    await _refresh();
  }

  Future<void> _signOut() async {
    final webmasterID = _webmasterID;
    if (webmasterID == null) return;
    await session.signOut();
    await webmasterID.resetIdentity();
    setState(() => _accountKey = null);
    _say('signed out — a new identity period');
    await _refresh();
  }

  /// One screen view and one tap, delivered now. Whether the server took them
  /// is in diagnostics (acknowledged), not in the return values.
  Future<void> _sendTestEvent() async {
    final webmasterID = _webmasterID;
    if (webmasterID == null) return;
    final queuedView = await webmasterID.screenView('Home');
    final queuedTap =
        await webmasterID.ctaTap(cta: 'send_test_event', screen: 'Home');
    final delivered = await webmasterID.flush();
    _say('screen_view queued=$queuedView, cta_tap queued=$queuedTap, '
        'flush made progress=$delivered');
    await _refresh();
  }

  Future<void> _refresh() async {
    final webmasterID = _webmasterID;
    if (webmasterID == null) return;
    final diagnostics = await webmasterID.diagnostics();
    if (!mounted) return;
    setState(() => _diagnostics = diagnostics);
    if (diagnostics != null) {
      // One line a log reader can grep for.
      debugPrint('WMID_CONSUMER consent=${diagnostics.consent?.name} '
          'queued=${diagnostics.queuedEvents} '
          'acknowledged=${diagnostics.acknowledged} '
          'status=${diagnostics.lastStatusCategory} '
          'hold=${diagnostics.deliveryHold} '
          'identityStorage=${diagnostics.identityStorage}');
    }
  }

  void _say(String line) {
    debugPrint('WMID_CONSUMER $line');
    if (!mounted) return;
    setState(() => _log.insert(0, line));
  }

  @override
  Widget build(BuildContext context) {
    final d = _diagnostics;
    return Scaffold(
      appBar: AppBar(title: const Text('WebmasterID consumer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Property: $appPropertyId'),
          Text('Signed in as: ${_accountKey ?? 'nobody'}'),
          const SizedBox(height: 12),
          const Text('1. Consent (the person decides; the app stores it)'),
          Wrap(spacing: 8, children: [
            FilledButton(
              onPressed: () => _setConsent(WebmasterIDConsent.analyticsAllowed),
              child: const Text('Allow analytics'),
            ),
            OutlinedButton(
              onPressed: () => _setConsent(WebmasterIDConsent.restricted),
              child: const Text('Restricted'),
            ),
            OutlinedButton(
              onPressed: () => _setConsent(WebmasterIDConsent.disabled),
              child: const Text('Disable'),
            ),
          ]),
          const SizedBox(height: 12),
          const Text('2. Session'),
          Wrap(spacing: 8, children: [
            FilledButton(onPressed: _signIn, child: const Text('Sign in')),
            OutlinedButton(onPressed: _signOut, child: const Text('Sign out')),
          ]),
          const SizedBox(height: 12),
          const Text('3. Events'),
          FilledButton(
            onPressed: _sendTestEvent,
            child: const Text('Send test event'),
          ),
          const SizedBox(height: 16),
          const Text('Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
          if (d == null)
            const Text('not started')
          else ...[
            Text('consent: ${d.consent?.name ?? 'not decided'}'),
            Text('queued: ${d.queuedEvents}  acknowledged: ${d.acknowledged}  '
                'attempted: ${d.attempted}'),
            Text('last status: ${d.lastStatusCategory}  '
                'delivery hold: ${d.deliveryHold}'),
            Text('identity storage: ${d.identityStorage}'),
          ],
          const SizedBox(height: 16),
          const Text('Log', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final line in _log) Text(line),
        ],
      ),
    );
  }
}
