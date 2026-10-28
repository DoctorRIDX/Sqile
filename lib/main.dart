import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

const bg = Color(0xFF0B0A0F);
const panel = Color(0xFF17151D);
const panel2 = Color(0xFF211D2A);
const purple = Color(0xFF7652B5);
const purpleLight = Color(0xFFB9A0E8);
const muted = Color(0xFFAAA5B5);
const line = Color(0xFF332D3D);

void main() => runApp(const SqileApp());

class SqileApp extends StatelessWidget {
  const SqileApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sqile Protax', debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: purpleLight, surface: panel),
      useMaterial3: true, appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: Colors.white),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: panel,
        hintStyle: const TextStyle(color: muted), contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: purpleLight)))),
    home: const PrivacyGate());
}

class PrivacyGate extends StatefulWidget { const PrivacyGate({super.key}); @override State<PrivacyGate> createState() => _PrivacyGateState(); }
class _PrivacyGateState extends State<PrivacyGate> {
  bool? accepted;
  @override void initState() { super.initState(); SharedPreferences.getInstance().then((p) { if (mounted) setState(() => accepted = p.getBool('protax_privacy') ?? false); }); }
  @override Widget build(BuildContext context) {
    if (accepted == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (accepted!) return const ProtaxHome();
    return Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Spacer(), Center(child: ClipOval(child: Image.asset('assets/logo.png', width: 88, height: 88, fit: BoxFit.cover))),
      const SizedBox(height: 26), const Text('Privacy Policy', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)), const SizedBox(height: 12),
      const Text('Sqile Protax memuat situs yang Anda masukkan melalui WebView. URL dan data yang Anda kirim ke situs diproses oleh situs tujuan. Aplikasi tidak memiliki server akun dan tidak mengirim riwayat browsing ke server Sqile.', style: TextStyle(color: muted, height: 1.55)),
      const SizedBox(height: 12), const Text('Gunakan hanya pada situs yang Anda miliki atau diizinkan untuk diuji. Situs dapat mengumpulkan data sesuai kebijakan privasinya. Fitur encode/decode bekerja secara lokal di perangkat.', style: TextStyle(color: muted, height: 1.55)),
      const Spacer(), SizedBox(width: double.infinity, child: FilledButton(onPressed: () async { final p = await SharedPreferences.getInstance(); await p.setBool('protax_privacy', true); if (mounted) setState(() => accepted = true); }, child: const Text('Setuju & Lanjutkan'))),
    ]))));
  }
}

class ProtaxHome extends StatefulWidget { const ProtaxHome({super.key}); @override State<ProtaxHome> createState() => _ProtaxHomeState(); }
class _ProtaxHomeState extends State<ProtaxHome> {
  final urlInput = TextEditingController();
  final dataInput = TextEditingController();
  late final WebViewController web;
  bool loading = false, loaded = false;
  int progress = 0;
  String currentUrl = '';
  String status = 'READY';

  @override void initState() {
    super.initState();
    web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(bg)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) { if (mounted) setState(() { progress = p; loading = p < 100; }); },
        onPageStarted: (url) { if (mounted) setState(() { loading = true; loaded = false; status = 'LOADING'; currentUrl = url; urlInput.text = url; }); },
        onPageFinished: (url) { if (mounted) setState(() { loading = false; loaded = true; progress = 100; status = 'LOADED'; currentUrl = url; urlInput.text = url; }); },
        onWebResourceError: (error) { if (error.isForMainFrame == true && mounted) setState(() { loading = false; status = 'ERROR'; }); },
        onUrlChange: (change) { if (change.url != null && mounted) setState(() { currentUrl = change.url!; }); },
      ));
  }
  @override void dispose() { urlInput.dispose(); dataInput.dispose(); super.dispose(); }
  String normalizeUrl(String raw) { var value = raw.trim(); if (value.isEmpty) throw const FormatException('URL belum diisi'); if (!value.contains('://')) value = 'https://$value'; final uri = Uri.parse(value); if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) throw const FormatException('Masukkan URL HTTP atau HTTPS yang valid'); return uri.toString(); }
  Future<void> runUrl() async { try { final url = normalizeUrl(urlInput.text); FocusScope.of(context).unfocus(); setState(() { loading = true; loaded = false; status = 'LOADING'; progress = 0; }); await web.loadRequest(Uri.parse(url)); } catch (e) { setState(() => status = 'INVALID URL'); _message(e.toString().replaceFirst('FormatException: ', '')); } }
  void _message(String text) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating)); }
  Future<void> openParams() async {
    String initial = urlInput.text.trim();
    if (initial.isEmpty) { _message('Masukkan URL terlebih dahulu'); return; }
    try { final uri = Uri.parse(normalizeUrl(initial)); final key = TextEditingController(text: (uri.queryParameters.keys.isEmpty ? '' : uri.queryParameters.keys.first)); final value = TextEditingController(text: (uri.queryParameters.values.isEmpty ? '' : uri.queryParameters.values.first));
      await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: panel, builder: (ctx) => Padding(padding: EdgeInsets.fromLTRB(18, 20, 18, MediaQuery.of(ctx).viewInsets.bottom + 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('URL Parameters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 14), TextField(controller: key, decoration: const InputDecoration(labelText: 'Parameter name', hintText: 'id')), const SizedBox(height: 10), TextField(controller: value, decoration: const InputDecoration(labelText: 'Value', hintText: '123')), const SizedBox(height: 14), SizedBox(width: double.infinity, child: FilledButton(onPressed: () { final q = Map<String, String>.from(uri.queryParameters); if (key.text.trim().isNotEmpty) q[key.text.trim()] = value.text; final updated = uri.replace(queryParameters: q.isEmpty ? null : q).toString(); urlInput.text = updated; Navigator.pop(ctx); }, child: const Text('Apply to URL')))])));
    } catch (_) { _message('URL tidak valid'); }
  }
  Future<void> openCodec(bool encode) async {
    dataInput.clear();
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: panel, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => Padding(padding: EdgeInsets.fromLTRB(18, 20, 18, MediaQuery.of(ctx).viewInsets.bottom + 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(encode ? 'URL Encode' : 'URL Decode', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 14), TextField(controller: dataInput, minLines: 3, maxLines: 5, decoration: const InputDecoration(hintText: 'Enter text or encoded data')), const SizedBox(height: 12), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () { try { dataInput.text = encode ? Uri.encodeComponent(dataInput.text) : Uri.decodeComponent(dataInput.text); refresh(() {}); } catch (_) { _message('Data tidak dapat diproses'); } }, icon: Icon(encode ? Icons.lock_outline : Icons.lock_open_outlined), label: Text(encode ? 'Encode' : 'Decode'))), const SizedBox(width: 10), IconButton(onPressed: () => Clipboard.setData(ClipboardData(text: dataInput.text)).then((_) => _message('Disalin')), icon: const Icon(Icons.copy))])]))));
  }
  Widget action(String label, IconData icon, VoidCallback onTap, {bool primary = false}) => SizedBox(height: 42, child: primary ? FilledButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label), style: FilledButton.styleFrom(backgroundColor: purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))) : OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 17), label: Text(label), style: OutlinedButton.styleFrom(foregroundColor: purpleLight, side: const BorderSide(color: line), padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))));
  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 13, 16, 10), child: Row(children: [ClipOval(child: Image.asset('assets/logo.png', width: 43, height: 43, fit: BoxFit.cover)), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sqile Protax', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -.6)), SizedBox(height: 1), Text('By Farid - DoctorRIDX', style: TextStyle(color: muted, fontSize: 12))])), IconButton(tooltip: 'Privacy Policy', onPressed: () => showDialog(context: context, builder: (_) => const AlertDialog(title: Text('Privacy Policy'), content: Text('Situs dibuka di WebView. Data yang dikirim melalui situs diterima oleh situs tujuan. Encode/decode berjalan lokal. Sqile tidak mengunggah riwayat browsing ke server Sqile.'), actions: [CloseButton()])), icon: const Icon(Icons.privacy_tip_outlined, color: purpleLight))])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [Expanded(child: TextField(controller: urlInput, keyboardType: TextInputType.url, textInputAction: TextInputAction.go, onSubmitted: (_) => runUrl(), decoration: const InputDecoration(hintText: 'https://example.com', prefixIcon: Icon(Icons.link, color: purpleLight), isDense: true))), const SizedBox(width: 8), SizedBox(height: 49, child: FilledButton(onPressed: runUrl, style: FilledButton.styleFrom(backgroundColor: purple, padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Icon(Icons.play_arrow_rounded))) ])),
      SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(14, 9, 14, 10), child: Row(children: [action('Stop', Icons.stop_rounded, () async { await web.runJavaScript('window.stop()').catchError((_) {});  if (mounted) setState(() { loading = false; status = 'STOPPED'; }); }), const SizedBox(width: 7), action('Reload', Icons.refresh_rounded, () async { if (currentUrl.isNotEmpty) { setState(() { loading = true; status = 'LOADING'; }); await web.reload(); } }), const SizedBox(width: 7), action('Params', Icons.tune_rounded, openParams), const SizedBox(width: 7), action('Encode', Icons.lock_outline, () => openCodec(true)), const SizedBox(width: 7), action('Decode', Icons.lock_open_outlined, () => openCodec(false))])),
      Container(height: 1, color: line),
      Expanded(child: Stack(children: [WebViewWidget(controller: web), if (!loaded) Positioned.fill(child: IgnorePointer(child: Container(color: bg, child: Center(child: ClipOval(child: Image.asset('assets/logo.png', width: 76, height: 76, fit: BoxFit.cover)))))), if (loading) Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(value: progress == 0 || progress >= 100 ? null : progress / 100, minHeight: 2, backgroundColor: panel2, color: purpleLight))])),
      Container(color: panel, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: status == 'ERROR' ? Colors.redAccent : status == 'LOADED' ? const Color(0xFF7BC8A4) : purpleLight, shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(status, style: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w700, letterSpacing: .6), maxLines: 1, overflow: TextOverflow.ellipsis)), if (currentUrl.isNotEmpty) Flexible(child: Text(Uri.tryParse(currentUrl)?.host ?? '', style: const TextStyle(color: muted, fontSize: 11), overflow: TextOverflow.ellipsis))]))
    ])),
  );
}
