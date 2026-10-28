import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(const SqileApp());

const Color kBg = Color(0xFF0C0913);
const Color kPanel = Color(0xFF171220);
const Color kPanel2 = Color(0xFF21182F);
const Color kPurple = Color(0xFF8B35FF);
const Color kPurpleLight = Color(0xFFC39BFF);
const Color kText = Color(0xFFF5F0FF);
const Color kMuted = Color(0xFF9D91AF);
const double kRadius = 15;

class SqileApp extends StatelessWidget {
  const SqileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sqile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPurple,
          brightness: Brightness.dark,
          surface: kPanel,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        ),
      ),
      home: const SqileHome(),
    );
  }
}

class Finding {
  Finding(this.title, this.detail, this.time, {this.level = 'INFO'});
  final String title;
  final String detail;
  final String time;
  final String level;
}

class SqileHome extends StatefulWidget {
  const SqileHome({super.key});
  @override
  State<SqileHome> createState() => _SqileHomeState();
}

class _SqileHomeState extends State<SqileHome> with TickerProviderStateMixin {
  final TextEditingController _url = TextEditingController(text: 'https://owasp.org');
  final List<Finding> _reports = [];
  late final WebViewController _web;
  int _tab = 0;
  int _progress = 0;
  bool _webReady = false;
  bool _loadingHeaders = false;
  String _pageTitle = 'No page loaded';
  String _headerResult = 'Enter a URL and run a security-header check.';
  Map<String, String> _headers = {};
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageStarted: (_) => setState(() { _webReady = false; _pageTitle = 'Loading website…'; }),
        onPageFinished: (url) async {
          String title = url;
          try { title = (await _web.getTitle()) ?? url; } catch (_) {}
          if (mounted) setState(() { _webReady = true; _pageTitle = title; _progress = 100; });
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? false) {
            setState(() { _pageTitle = 'Could not load page'; _webReady = false; });
          }
        },
      ))
      ..loadRequest(Uri.parse('https://owasp.org'));
  }

  @override
  void dispose() {
    _url.dispose();
    _pulse.dispose();
    super.dispose();
  }

  String _normalizedUrl() {
    var value = _url.text.trim();
    if (value.isEmpty) throw const FormatException('Enter a website URL first.');
    if (!value.startsWith('https://') && !value.startsWith('http://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      throw const FormatException('The URL format is invalid.');
    }
    return uri.toString();
  }

  void _loadUrl() {
    try {
      final value = _normalizedUrl();
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() { _progress = 1; _pageTitle = 'Loading website…'; });
      _web.loadRequest(Uri.parse(value));
      _addReport('Website opened', value, 'INFO');
    } on FormatException catch (e) {
      _toast(e.message);
    }
  }

  void _reload() {
    try {
      _normalizedUrl();
      _web.reload();
      setState(() => _progress = 1);
    } on FormatException catch (e) { _toast(e.message); }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _time() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _addReport(String title, String detail, String level) {
    setState(() {
      _reports.insert(0, Finding(title, detail, _time(), level: level));
      if (_reports.length > 30) _reports.removeLast();
    });
  }

  Future<void> _checkHeaders() async {
    String target;
    try { target = _normalizedUrl(); } on FormatException catch (e) { _toast(e.message); return; }
    setState(() { _loadingHeaders = true; _headerResult = 'Requesting response headers…'; });
    try {
      final response = await http.get(Uri.parse(target), headers: {'User-Agent': 'Sqile-Security-Lab/1.0'})
          .timeout(const Duration(seconds: 12));
      final map = <String, String>{};
      response.headers.forEach((key, value) => map[key.toLowerCase()] = value);
      const expected = <String, String>{
        'content-security-policy': 'Helps restrict script and resource sources.',
        'strict-transport-security': 'Requests HTTPS-only behavior in supporting browsers.',
        'x-content-type-options': 'Helps prevent MIME type sniffing.',
        'x-frame-options': 'Controls embedding in frames.',
        'referrer-policy': 'Controls referrer information sent by the browser.',
        'permissions-policy': 'Restricts access to selected browser features.',
      };
      final lines = <String>[];
      int present = 0;
      expected.forEach((name, description) {
        final value = map[name];
        if (value != null) present++;
        lines.add('${value == null ? 'MISSING' : 'PRESENT'}  $name${value == null ? '' : ': $value'}\n$description');
      });
      final summary = 'HTTP ${response.statusCode} • $present/${expected.length} common headers found';
      setState(() { _headers = map; _headerResult = '$summary\n\n${lines.join('\n\n')}'; });
      _addReport('Security headers checked', '$target — $summary', present == expected.length ? 'INFO' : 'REVIEW');
    } catch (e) {
      setState(() => _headerResult = 'Request failed: $e');
      _addReport('Header check failed', '$target — $e', 'ERROR');
    } finally {
      if (mounted) setState(() => _loadingHeaders = false);
    }
  }

  void _recordToolResult(String title, String detail) {
    _addReport(title, detail, 'REVIEW');
    _toast('Result added to Reports.');
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _homePage(),
      SqlInjectionPage(onRecord: _recordToolResult),
      XssPage(onRecord: _recordToolResult),
      _headersPage(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _topBar(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
    child: Row(children: [
      Container(
        width: 45, height: 45,
        decoration: BoxDecoration(
          color: kPurple.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: kPurple.withValues(alpha: .45)),
        ),
        padding: const EdgeInsets.all(6),
        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
      ),
      const SizedBox(width: 11),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SQILE', style: TextStyle(fontSize: 18, letterSpacing: 2.8, fontWeight: FontWeight.w900)),
        SizedBox(height: 2),
        Text('WEB SECURITY LAB', style: TextStyle(color: kMuted, fontSize: 9, letterSpacing: 1.7)),
      ])),
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: kPurple.withValues(alpha: .10 + _pulse.value * .08),
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: kPurple.withValues(alpha: .3 + _pulse.value * .3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFB58AFF), shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(_time(), style: const TextStyle(fontFeatures: [], fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]),
  );

  Widget _homePage() => ListView(
    key: const PageStorageKey('home'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
    children: [
      _welcomeCard(),
      const SizedBox(height: 16),
      _sectionTitle('TARGET WORKSPACE', 'WebView & live preview'),
      const SizedBox(height: 10),
      _urlCard(),
      const SizedBox(height: 10),
      _webViewCard(),
      const SizedBox(height: 14),
      _reportsCard(),
    ],
  );

  Widget _welcomeCard() => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(kRadius),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF51208B), Color(0xFF25123F), Color(0xFF171220)]),
      border: Border.all(color: kPurple.withValues(alpha: .35)),
    ),
    child: Stack(children: [
      Positioned(right: -12, top: -18, child: Icon(Icons.visibility_outlined, size: 112, color: Colors.white.withValues(alpha: .06))),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('11:12', style: TextStyle(fontSize: 35, fontWeight: FontWeight.w800, letterSpacing: -1)),
        const SizedBox(height: 5),
        const Text('Welcome to Sqile', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        const Text('A focused workspace for web security analysis.',
          style: TextStyle(color: Color(0xFFD3C3E8), height: 1.45, fontSize: 12)),
        const SizedBox(height: 14),
        Row(children: [
          _tag(Icons.shield_outlined, 'SECURITY LAB'),
          const SizedBox(width: 7),
          _tag(Icons.lock_outline, 'PRIVATE SESSION'),
        ]),
      ]),
    ]),
  );

  Widget _tag(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .16), borderRadius: BorderRadius.circular(kRadius)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: kPurpleLight), const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 8, letterSpacing: .6, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _sectionTitle(String title, String subtitle) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 10, letterSpacing: 1.5, color: kPurpleLight, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: kMuted, fontSize: 12)),
    ])),
  ]);

  Widget _urlCard() => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Website URL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _loadUrl(),
          style: const TextStyle(fontSize: 12),
          decoration: _inputDecoration('https://example.com', Icons.link),
        )),
        const SizedBox(width: 8),
        _iconButton(Icons.refresh_rounded, 'Reload', _reload),
      ]),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _loadUrl,
        icon: const Icon(Icons.language_rounded, size: 17),
        label: const Text('Open website'),
        style: ElevatedButton.styleFrom(
          backgroundColor: kPurple, foregroundColor: Colors.white,
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        ),
      )),
    ]),
  );

  Widget _webViewCard() => _card(
    padding: EdgeInsets.zero,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
        child: Row(children: [
          const Icon(Icons.web_rounded, color: kPurpleLight, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('Website preview', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          if (_webReady) const Icon(Icons.check_circle_outline, color: Color(0xFF8CDEB3), size: 15),
        ]),
      ),
      if (_progress > 0 && _progress < 100)
        LinearProgressIndicator(value: _progress / 100, minHeight: 2, color: kPurple, backgroundColor: kPanel2),
      SizedBox(
        height: 290,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(kRadius)),
          child: WebViewWidget(controller: _web),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 12),
        child: Row(children: [
          const Icon(Icons.article_outlined, size: 14, color: kMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(_pageTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: kMuted))),
          Text('$_progress%', style: const TextStyle(fontSize: 10, color: kPurpleLight)),
        ]),
      ),
    ]),
  );

  Widget _reportsCard() => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.receipt_long_outlined, color: kPurpleLight, size: 18),
        const SizedBox(width: 8),
        const Expanded(child: Text('Reports', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: kPurple.withValues(alpha: .17), borderRadius: BorderRadius.circular(20)),
          child: Text('${_reports.length}', style: const TextStyle(color: kPurpleLight, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
        IconButton(
          tooltip: 'Clear reports',
          onPressed: _reports.isEmpty ? null : () => setState(_reports.clear),
          icon: const Icon(Icons.delete_outline, size: 18),
          visualDensity: VisualDensity.compact,
        ),
      ]),
      if (_reports.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 15),
          child: Center(child: Column(children: [
            Icon(Icons.description_outlined, size: 27, color: kMuted),
            SizedBox(height: 7),
            Text('No reports yet', style: TextStyle(color: kMuted, fontSize: 12)),
            SizedBox(height: 3),
            Text('Your analysis results will appear here.', style: TextStyle(color: kMuted, fontSize: 10)),
          ])),
        )
      else
        ..._reports.take(8).map((r) => Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 5, right: 9),
              decoration: BoxDecoration(color: r.level == 'ERROR' ? Colors.redAccent : kPurpleLight, shape: BoxShape.circle)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(r.detail, style: const TextStyle(color: kMuted, fontSize: 10, height: 1.4)),
            ])),
            Text(r.time, style: const TextStyle(color: kMuted, fontSize: 9)),
          ]),
        )),
    ]),
  );

  Widget _headersPage() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      _pageHeading(Icons.shield_outlined, 'Security Headers', 'Inspect common HTTP response security headers.'),
      const SizedBox(height: 15),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Target URL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(controller: _url, keyboardType: TextInputType.url,
          decoration: _inputDecoration('https://example.com', Icons.link)),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _loadingHeaders ? null : _checkHeaders,
          icon: _loadingHeaders
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.manage_search, size: 18),
          label: Text(_loadingHeaders ? 'Checking headers…' : 'Analyze headers'),
          style: ElevatedButton.styleFrom(backgroundColor: kPurple, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)), minimumSize: const Size(0, 46)),
        )),
      ])),
      const SizedBox(height: 12),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Analysis result', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 10),
        SelectableText(_headerResult, style: const TextStyle(fontSize: 11, color: Color(0xFFD4C9E2), height: 1.55)),
        if (_headers.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _headerResult));
              _toast('Header report copied.');
            },
            icon: const Icon(Icons.copy, size: 16), label: const Text('Copy result'),
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius))),
          ),
        ],
      ])),
      const SizedBox(height: 12),
      _infoCard('Interpretation', 'A missing header is a review item, not proof of a vulnerability. Verify behavior against the site architecture and its intended browser policies.'),
    ],
  );

  Widget _pageHeading(IconData icon, String title, String subtitle) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(kRadius),
      gradient: const LinearGradient(colors: [Color(0xFF3B1A60), kPanel]),
      border: Border.all(color: kPurple.withValues(alpha: .25)),
    ),
    child: Row(children: [
      Container(width: 46, height: 46, decoration: BoxDecoration(color: kPurple.withValues(alpha: .18), borderRadius: BorderRadius.circular(kRadius)),
        child: Icon(icon, color: kPurpleLight, size: 23)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: kMuted, fontSize: 11, height: 1.4)),
      ])),
    ]),
  );

  Widget _infoCard(String title, String detail) => _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Icon(Icons.info_outline, color: kPurpleLight, size: 17), const SizedBox(width: 7),
      Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]),
    const SizedBox(height: 8),
    Text(detail, style: const TextStyle(fontSize: 11, height: 1.5, color: kMuted)),
  ]));

  Widget _bottomNav() => Container(
    decoration: BoxDecoration(color: kPanel, border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .06)))),
    child: SafeArea(top: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 5),
      child: Row(children: [
        _navItem(0, Icons.dashboard_outlined, 'Home'),
        _navItem(1, Icons.storage_rounded, 'SQLi'),
        _navItem(2, Icons.code_rounded, 'XSS'),
        _navItem(3, Icons.shield_outlined, 'Headers'),
      ]),
    )),
  );

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _tab == index;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _tab = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kPurple.withValues(alpha: .18) : Colors.transparent,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: selected ? kPurple.withValues(alpha: .35) : Colors.transparent),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 19, color: selected ? kPurpleLight : kMuted),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? kText : kMuted)),
        ]),
      ),
    ));
  }

  Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(14)}) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: kPanel,
      borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: Colors.white.withValues(alpha: .065)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 18, offset: const Offset(0, 7))],
    ),
    child: child,
  );

  Widget _iconButton(IconData icon, String tooltip, VoidCallback action) => Material(
    color: kPanel2,
    borderRadius: BorderRadius.circular(kRadius),
    child: InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(kRadius),
      child: SizedBox(width: 46, height: 46, child: Icon(icon, color: kPurpleLight, size: 21)),
    ),
  );

  InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: kMuted, fontSize: 11),
    prefixIcon: Icon(icon, color: kPurpleLight, size: 18),
    filled: true, fillColor: kBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius), borderSide: BorderSide(color: Colors.white.withValues(alpha: .08))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius), borderSide: BorderSide(color: Colors.white.withValues(alpha: .08))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius), borderSide: const BorderSide(color: kPurple)),
  );
}

class SqlInjectionPage extends StatefulWidget {
  const SqlInjectionPage({super.key, required this.onRecord});
  final void Function(String, String) onRecord;
  @override
  State<SqlInjectionPage> createState() => _SqlInjectionPageState();
}

class _SqlInjectionPageState extends State<SqlInjectionPage> {
  final _input = TextEditingController();
  final _output = TextEditingController();
  String _selected = 'Quote handling';
  String _result = 'Choose a lab check, enter a sample value, then analyze locally.';
  final Map<String, String> _checks = {
    'Quote handling': "O'Reilly",
    'Boolean condition': "' OR '1'='1",
    'Error behavior': "'",
    'Numeric parameter': '1 AND 1=1',
  };

  @override
  void dispose() { _input.dispose(); _output.dispose(); super.dispose(); }

  void _analyze() {
    final input = _input.text;
    if (input.trim().isEmpty) {
      setState(() => _result = 'Enter a sample input first.');
      return;
    }
    final findings = <String>[];
    if (input.contains("'") || input.contains('"')) findings.add('Contains quote characters; review parameterized query handling.');
    if (RegExp(r'\b(OR|AND)\b', caseSensitive: false).hasMatch(input)) findings.add('Contains a boolean operator; treat as untrusted input.');
    if (RegExp(r'\b(SELECT|UNION|DROP|INSERT|UPDATE|DELETE)\b', caseSensitive: false).hasMatch(input)) findings.add('Contains SQL-like keywords.');
    if (findings.isEmpty) findings.add('No simple SQL-like patterns found. Pattern checks cannot prove a parameter is safe.');
    setState(() => _result = findings.join('\n\n'));
    widget.onRecord('SQLi input reviewed', 'Local pattern review: ${findings.length} note(s). No request sent.',);
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      _toolHeading(Icons.storage_rounded, 'SQL Injection', 'Local input review and lab test-case builder.'),
      const SizedBox(height: 14),
      _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Test case library', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 9),
        DropdownButtonFormField<String>(
          initialValue: _selected,
          dropdownColor: kPanel2,
          decoration: _decoration('Choose a test case'),
          items: _checks.keys.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _selected = v ?? _selected),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => setState(() => _input.text = _checks[_selected] ?? ''),
          icon: const Icon(Icons.playlist_add, size: 17), label: const Text('Load sample'),
          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius))),
        ),
      ])),
      const SizedBox(height: 12),
      _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Input to inspect', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 9),
        TextField(controller: _input, minLines: 2, maxLines: 4,
          decoration: _decoration('Paste a sample value or lab input')),
        const SizedBox(height: 11),
        _primaryButton('Analyze locally', Icons.manage_search, _analyze),
        const SizedBox(height: 12),
        _resultBox(_result),
      ])),
      const SizedBox(height: 12),
      _info('What this does', 'This screen checks text patterns locally and helps prepare lab cases. It does not submit SQL injection strings to the URL or run database commands. Confirm SQLi safely in a deliberately vulnerable lab and review server-side parameterized queries.'),
    ],
  );
}

class XssPage extends StatefulWidget {
  const XssPage({super.key, required this.onRecord});
  final void Function(String, String) onRecord;
  @override
  State<XssPage> createState() => _XssPageState();
}

class _XssPageState extends State<XssPage> {
  final _input = TextEditingController();
  String _result = 'Enter text or a response snippet to inspect locally.';
  String _encoded = '';
  @override
  void dispose() { _input.dispose(); super.dispose(); }

  String _escapeHtml(String value) => value
    .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;').replaceAll("'", '&#x27;');

  void _analyze() {
    final value = _input.text;
    if (value.isEmpty) { setState(() => _result = 'Enter a value first.'); return; }
    final hints = <String>[];
    if (value.contains('<') || value.contains('>')) hints.add('HTML angle brackets found; verify context-appropriate output encoding.');
    if (RegExp(r'javascript\s*:', caseSensitive: false).hasMatch(value)) hints.add('JavaScript URL scheme-like text found.');
    if (RegExp(r'\bon\w+\s*=', caseSensitive: false).hasMatch(value)) hints.add('HTML event-handler-like attribute found.');
    if (hints.isEmpty) hints.add('No simple XSS-like markers found. This does not establish that the output is safe.');
    setState(() { _result = hints.join('\n\n'); _encoded = _escapeHtml(value); });
    widget.onRecord('XSS input reviewed', 'Local marker review: ${hints.length} note(s). No script executed.');
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      _toolHeading(Icons.code_rounded, 'XSS Analysis', 'Inspect text and review HTML output encoding.'),
      const SizedBox(height: 14),
      _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Input / response snippet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 9),
        TextField(controller: _input, minLines: 3, maxLines: 6,
          decoration: _decoration('Paste a value or HTML response snippet')),
        const SizedBox(height: 11),
        _primaryButton('Analyze locally', Icons.manage_search, _analyze),
        const SizedBox(height: 12),
        _resultBox(_result),
        if (_encoded.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('HTML-escaped output', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 7),
          _resultBox(_encoded),
          const SizedBox(height: 7),
          OutlinedButton.icon(
            onPressed: () { Clipboard.setData(ClipboardData(text: _encoded)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escaped output copied.'))); },
            icon: const Icon(Icons.copy, size: 16), label: const Text('Copy escaped output'),
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius))),
          ),
        ],
      ])),
      const SizedBox(height: 12),
      _info('What this does', 'This tool performs local pattern checks and demonstrates HTML escaping. It does not inject or execute JavaScript in a target website. Use a controlled lab to validate context-specific output encoding.'),
    ],
  );
}

Widget _toolHeading(IconData icon, String title, String subtitle) => Container(
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(kRadius),
    gradient: const LinearGradient(colors: [Color(0xFF3B1A60), kPanel]),
    border: Border.all(color: kPurple.withValues(alpha: .25)),
  ),
  child: Row(children: [
    Container(width: 46, height: 46, decoration: BoxDecoration(color: kPurple.withValues(alpha: .18), borderRadius: BorderRadius.circular(kRadius)),
      child: Icon(icon, color: kPurpleLight, size: 23)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: kMuted, fontSize: 11, height: 1.4)),
    ])),
  ]),
);

Widget _panel({required Widget child}) => Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(kRadius),
    border: Border.all(color: Colors.white.withValues(alpha: .065))),
  child: child,
);

InputDecoration _decoration(String hint) => InputDecoration(
  hintText: hint, hintStyle: const TextStyle(color: kMuted, fontSize: 11),
  filled: true, fillColor: kBg,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius), borderSide: BorderSide(color: Colors.white.withValues(alpha: .08))),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius), borderSide: BorderSide(color: Colors.white.withValues(alpha: .08))),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius), borderSide: const BorderSide(color: kPurple)),
);

Widget _primaryButton(String label, IconData icon, VoidCallback onTap) => SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: onTap, icon: Icon(icon, size: 17), label: Text(label),
    style: ElevatedButton.styleFrom(backgroundColor: kPurple, foregroundColor: Colors.white,
      minimumSize: const Size(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius))),
  ),
);

Widget _resultBox(String text) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(kRadius),
    border: Border.all(color: kPurple.withValues(alpha: .18))),
  child: SelectableText(text, style: const TextStyle(fontSize: 11, color: Color(0xFFD4C9E2), height: 1.5)),
);

Widget _info(String title, String detail) => _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Row(children: [const Icon(Icons.info_outline, color: kPurpleLight, size: 17), const SizedBox(width: 7),
    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]),
  const SizedBox(height: 8),
  Text(detail, style: const TextStyle(fontSize: 11, height: 1.5, color: kMuted)),
]));
