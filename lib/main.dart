
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

const purple = Color(0xFF9B6DFF);
const background = Color(0xFF100D18);
const surface = Color(0xFF1B1626);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SqileApp());
}

class SqileApp extends StatelessWidget {
  const SqileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sqile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          brightness: Brightness.dark,
        ),
        cardTheme: const CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const WelcomePage(),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool accepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: surface,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/logo.png',
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.shield_outlined,
                      color: purple,
                      size: 60,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to Sqile',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Security tools for web analysis and APK permission review.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Privacy notice',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'APK checks are preliminary permission reviews, '
                          'not a guarantee that an app is safe. Web requests '
                          'may contact external websites. Only scan files '
                          'you are authorized to inspect.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                CheckboxListTile(
                  value: accepted,
                  onChanged: (value) {
                    setState(() => accepted = value ?? false);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I have read the privacy notice'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: accepted
                        ? () async {
                            final prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setBool('welcomeAccepted', true);
                            if (!context.mounted) return;
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const SqileHome(),
                              ),
                            );
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: purple,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SqileHome extends StatefulWidget {
  const SqileHome({super.key});

  @override
  State<SqileHome> createState() => _SqileHomeState();
}

class _SqileHomeState extends State<SqileHome> {
  int selectedIndex = 0;
  String ipAddress = 'Unavailable';

  late final WebViewController webController;
  final TextEditingController urlController = TextEditingController(
    text: 'https://example.com',
  );

  @override
  void initState() {
    super.initState();
    loadIp();

    webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null ||
                (uri.scheme != 'https' && uri.scheme != 'http')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://example.com'));
  }

  Future<void> loadIp() async {
    try {
      final info = NetworkInfo();
      final value = await info.getWifiIP();
      if (!mounted) return;
      setState(() => ipAddress = value ?? 'Unavailable');
    } catch (_) {
      if (!mounted) return;
      setState(() => ipAddress = 'Unavailable');
    }
  }

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      dashboard(),
      webPage(),
      const ApkScannerPage(),
      const InfoPage(
        title: 'Ad Blocker',
        icon: Icons.block,
        description:
            'Manage browser content-blocking options. This page does not '
            'currently block ads system-wide.',
      ),
      const InfoPage(
        title: 'Virus Manager',
        icon: Icons.shield_outlined,
        description:
            'Review APK permissions with the scanner. Sqile is not a '
            'full antivirus and does not continuously monitor your device.',
      ),
      const InfoPage(
        title: 'Reports',
        icon: Icons.assessment_outlined,
        description:
            'Reports will appear here when scan history is implemented.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: surface,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/logo.png',
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.shield, color: purple),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Sqile',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey(selectedIndex),
            child: pages[selectedIndex],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: surface,
        indicatorColor: purple.withValues(alpha: 0.2),
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) {
          setState(() => selectedIndex = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.language),
            label: 'Web',
          ),
          NavigationDestination(
            icon: Icon(Icons.android),
            label: 'APK Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'Tools',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            label: 'Virus',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            label: 'Reports',
          ),
        ],
      ),
    );
  }

  Widget dashboard() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Security Dashboard',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Monitor and review your security tasks.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.wifi, color: purple, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Wi-Fi IP address'),
                      const SizedBox(height: 4),
                      Text(
                        ipAddress,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: loadIp,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        toolCard(
          'WebView',
          'Browse and inspect websites',
          Icons.language,
          () => setState(() => selectedIndex = 1),
        ),
        toolCard(
          'APK Permission Scanner',
          'Review permissions in an APK file',
          Icons.android,
          () => setState(() => selectedIndex = 2),
        ),
        toolCard(
          'Ad Blocker',
          'View content-blocking guidance',
          Icons.block,
          () => setState(() => selectedIndex = 3),
        ),
        toolCard(
          'Virus Manager',
          'Review available security tools',
          Icons.shield_outlined,
          () => setState(() => selectedIndex = 4),
        ),
        toolCard(
          'Reports',
          'View scan report information',
          Icons.assessment_outlined,
          () => setState(() => selectedIndex = 5),
        ),
      ],
    );
  }

  Widget toolCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: purple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: purple),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget webPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'https://example.com',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  var value = urlController.text.trim();
                  if (!value.startsWith('https://') &&
                      !value.startsWith('http://')) {
                    value = 'https://$value';
                  }
                  final uri = Uri.tryParse(value);
                  if (uri != null &&
                      (uri.scheme == 'https' || uri.scheme == 'http') &&
                      uri.host.isNotEmpty) {
                    webController.loadRequest(uri);
                  }
                },
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ),
        Expanded(child: WebViewWidget(controller: webController)),
      ],
    );
  }
}

class ApkScannerPage extends StatefulWidget {
  const ApkScannerPage({super.key});

  @override
  State<ApkScannerPage> createState() => _ApkScannerPageState();
}

class _ApkScannerPageState extends State<ApkScannerPage> {
  String result = 'Choose an APK file to review its permissions.';
  bool scanning = false;

  Future<void> scanApk() async {
    final file = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
      withData: false,
    );

    if (file == null || file.files.single.path == null) return;

    setState(() {
      scanning = true;
      result = 'Reviewing APK metadata...';
    });

    try {
      final response = await http.get(
        Uri.parse('https://www.google.com/generate_204'),
      ).timeout(const Duration(seconds: 5));

      final networkAvailable = response.statusCode == 204;
      final name = file.files.single.name;
      setState(() {
        result = 'File: $name\n'
            'Network check: ${networkAvailable ? "Available" : "Unknown"}\n\n'
            'Sqile has not yet performed a malware signature scan. '
            'Review the app source and permissions before installing. '
            'A filename or network check cannot establish that an APK is safe.';
      });
    } catch (_) {
      setState(() {
        result = 'File: ${file.files.single.name}\n\n'
            'Network check unavailable. This is not a malware verdict. '
            'A full permission and malware analysis engine is not configured.';
      });
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'APK Scanner',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select an APK to review. This version does not claim to detect '
            'all malware or automatically block installation.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: scanning ? null : scanApk,
              icon: const Icon(Icons.file_open),
              label: Text(scanning ? 'Checking...' : 'Choose APK'),
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(result),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;

  const InfoPage({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: purple, size: 42),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                description,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

