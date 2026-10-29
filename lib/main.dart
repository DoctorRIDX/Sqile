import 'dart:convert';
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
  bool loading = false, loaded = false, stopRequested = false;
  int progress = 0;
  String currentUrl = '';
  String status = 'READY';

  @override void initState() {
    super.initState();
    web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(bg)
      ..addJavaScriptChannel('SqilePick', onMessageReceived: (m) => _onPick(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) { if (stopRequested || !mounted) return; setState(() { progress = p; loading = p < 100; }); },
        onPageStarted: (url) { stopRequested = false; if (mounted) setState(() { loading = true; loaded = false; status = 'LOADING'; currentUrl = url == 'about:blank' ? '' : url; if (url != 'about:blank') urlInput.text = url; }); },
        onPageFinished: (url) { if (stopRequested || !mounted) return; _applyEdits(url); setState(() { loading = false; loaded = url != 'about:blank'; progress = loaded ? 100 : 0; status = loaded ? 'LOADED' : 'READY'; currentUrl = url == 'about:blank' ? '' : url; if (url != 'about:blank') urlInput.text = url; }); },
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

  Future<void> stopPage() async {
    stopRequested = true;
    try { await web.runJavaScript('window.stop()'); } catch (_) {}
    if (!mounted) return;
    setState(() { loading = false; status = 'STOPPED'; });
  }

  Future<void> clearPage() async {
    urlInput.clear();
    stopRequested = true;
    try { await web.runJavaScript('window.stop()'); } catch (_) {}
    if (!mounted) return;
    setState(() { loading = false; loaded = false; progress = 0; currentUrl = ''; status = 'READY'; });
  }

  Future<void> navigate(bool forward) async {
    try {
      if (forward ? await web.canGoForward() : await web.canGoBack()) {
        if (forward) { await web.goForward(); } else { await web.goBack(); }
      } else {
        _message(forward ? 'Tidak ada halaman berikutnya' : 'Tidak ada halaman sebelumnya');
      }
    } catch (_) { _message('Navigasi tidak tersedia'); }
  }

  Future<void> copyUrl() async {
    final value = currentUrl.isNotEmpty ? currentUrl : urlInput.text.trim();
    if (value.isEmpty) { _message('URL masih kosong'); return; }
    await Clipboard.setData(ClipboardData(text: value));
    _message('URL disalin');
  }

  Future<void> textTool(String title, String hint, Future<void> Function(String) apply,
      {String initial = '', int lines = 4}) async {
    final input = TextEditingController(text: initial);
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: panel,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(18, 20, 18, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: input, minLines: lines, maxLines: lines + 3,
            decoration: InputDecoration(hintText: hint)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () async { final value = input.text; Navigator.pop(ctx); await apply(value); },
            child: const Text('Apply')))
        ]),
      ),
    );
    input.dispose();
  }

  Future<void> editHeaders() async {
    await textTool('Request Headers', 'Contoh:\\nAccept: application/json\\nX-Test: value',
      (value) async {
        try {
          final headers = <String, String>{};
          for (final row in value.split('\\n')) {
            final i = row.indexOf(':');
            if (i > 0) {
              final key = row.substring(0, i).trim();
              final val = row.substring(i + 1).trim();
              if (key.isNotEmpty) headers[key] = val;
            }
          }
          final url = normalizeUrl(urlInput.text);
          setState(() { loading = true; loaded = false; progress = 0; status = 'LOADING'; });
          await web.loadRequest(Uri.parse(url), headers: headers);
        } catch (e) { _message('Header/URL tidak valid: $e'); }
      });
  }

  Future<void> sendBody() async {
    await textTool('POST Body', 'Contoh: username=test&password=123',
      (value) async {
        try {
          final url = normalizeUrl(urlInput.text);
          setState(() { loading = true; loaded = false; progress = 0; status = 'LOADING'; });
          await web.loadRequest(
            Uri.parse(url),
            method: LoadRequestMethod.post,
            headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
            body: Uint8List.fromList(utf8.encode(value)),
          );
        } catch (e) { _message('Gagal mengirim body: $e'); }
      });
  }

  Future<void> showCookies() async {
    try {
      final result = await web.runJavaScriptReturningResult('document.cookie');
      if (!mounted) return;
      showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Cookies halaman'),
        content: SingleChildScrollView(child: SelectableText('$result')),
        actions: [
          TextButton(onPressed: () async {
            await Clipboard.setData(ClipboardData(text: '$result'));
            if (ctx.mounted) Navigator.pop(ctx);
            _message('Hasil disalin');
          }, child: const Text('Copy')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ));
    } catch (_) { _message('Buka halaman terlebih dahulu'); }
  }

  Future<void> editUserAgent() async {
    await textTool('User-Agent', 'Masukkan User-Agent baru',
      (value) async {
        if (value.trim().isEmpty) { _message('User-Agent kosong'); return; }
        try {
          await web.setUserAgent(value.trim());
          _message('User-Agent diterapkan untuk navigasi berikutnya');
        } catch (e) { _message('Gagal mengatur User-Agent: $e'); }
      });
  }

  Future<void> findText() async {
    await textTool('Find in page', 'Teks yang dicari',
      (value) async {
        if (value.isEmpty) return;
        try {
          final safe = jsonEncode(value);
          await web.runJavaScript('window.find($safe)');
        } catch (_) { _message('Pencarian tidak didukung halaman ini'); }
      }, lines: 1);
  }

  static const String _applyJs = r'''(function(d){
  try{
    var st=document.getElementById('sqile-edit-css');
    if(!st){st=document.createElement('style');st.id='sqile-edit-css';(document.head||document.documentElement).appendChild(st);}
    st.textContent=d.css||'';
    (d.ops||[]).forEach(function(o){
      try{
        document.querySelectorAll(o.s).forEach(function(e){
          if(o.t==='text'){e.textContent=o.v;}
          else if(o.t==='hide'){e.style.setProperty('display','none','important');}
        });
      }catch(x){}
    });
  }catch(x){}
})''';

  static const String _pickJs = r'''(function(mode){
  if(window.__sqPick){window.__sqPick.off();}
  var hi=document.createElement('div');
  hi.style.cssText='position:fixed;z-index:2147483647;pointer-events:none;border:2px solid #B9A0E8;background:rgba(118,82,181,.25);display:none;';
  document.documentElement.appendChild(hi);
  function sel(e){
    var p=[];
    while(e&&e.nodeType===1&&e!==document.documentElement){
      if(e.id&&document.querySelectorAll('#'+CSS.escape(e.id)).length===1){p.unshift('#'+CSS.escape(e.id));break;}
      var s=e.tagName.toLowerCase(),par=e.parentElement;
      if(par){var sib=Array.prototype.filter.call(par.children,function(c){return c.tagName===e.tagName;});if(sib.length>1){s+=':nth-of-type('+(sib.indexOf(e)+1)+')';}}
      p.unshift(s);e=par;
    }
    return p.join('>');
  }
  function mark(ev){var t=ev.target;if(!t||t===hi)return;var r=t.getBoundingClientRect();hi.style.display='block';hi.style.left=r.left+'px';hi.style.top=r.top+'px';hi.style.width=r.width+'px';hi.style.height=r.height+'px';}
  function off(){document.removeEventListener('touchstart',mark,true);document.removeEventListener('click',pick,true);if(hi.parentNode)hi.parentNode.removeChild(hi);window.__sqPick=null;}
  function pick(ev){
    ev.preventDefault();ev.stopPropagation();ev.stopImmediatePropagation();
    var t=ev.target;off();
    var a={};for(var i=0;i<t.attributes.length;i++){a[t.attributes[i].name]=t.attributes[i].value;}
    SqilePick.postMessage(JSON.stringify({mode:mode,sel:sel(t),tag:t.tagName.toLowerCase(),text:(t.innerText||t.textContent||'').slice(0,2000),attrs:a,html:t.outerHTML.slice(0,3000)}));
  }
  document.addEventListener('touchstart',mark,true);
  document.addEventListener('click',pick,true);
  window.__sqPick={off:off};
})''';

  String? _editKey() {
    final host = Uri.tryParse(currentUrl)?.host ?? '';
    return host.isEmpty ? null : 'protax_edit_$host';
  }

  Future<Map<String, dynamic>> _loadEdits(String key) async {
    final p = await SharedPreferences.getInstance();
    try {
      final raw = p.getString(key);
      if (raw != null) {
        final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        m['css'] = (m['css'] ?? '').toString();
        m['ops'] = List<dynamic>.from((m['ops'] ?? <dynamic>[]) as List);
        return m;
      }
    } catch (_) {}
    return <String, dynamic>{'css': '', 'ops': <dynamic>[]};
  }

  Future<void> _saveEdits(String key, Map<String, dynamic> e) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(e));
  }

  Future<void> _runApply(Map<String, dynamic> e) =>
      web.runJavaScript('$_applyJs(${jsonEncode(e)});');

  Future<void> _applyEdits(String url) async {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) return;
    final e = await _loadEdits('protax_edit_$host');
    if ((e['css'] as String).isEmpty && (e['ops'] as List).isEmpty) return;
    try {
      await _runApply(e);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) await _runApply(e);
    } catch (_) {}
  }

  Future<void> startPick(String mode) async {
    if (!loaded) { _message('Buka halaman terlebih dahulu'); return; }
    try {
      await web.runJavaScript('$_pickJs("$mode");');
      _message('Tap elemen di halaman');
    } catch (_) { _message('Gagal mengaktifkan mode pilih'); }
  }

  Future<void> _onPick(String msg) async {
    Map<String, dynamic> d;
    try { d = Map<String, dynamic>.from(jsonDecode(msg) as Map); } catch (_) { return; }
    final sel = (d['sel'] ?? '').toString();
    final mode = d['mode'];
    final key = _editKey();
    if (sel.isEmpty || key == null) { _message('Elemen tidak bisa dipilih'); return; }
    if (mode == 'inspect') {
      _showInspect(d);
    } else if (mode == 'hide') {
      final e = await _loadEdits(key);
      (e['ops'] as List).add({'t': 'hide', 's': sel});
      await _saveEdits(key, e);
      await _runApply(e);
      _message('Element disembunyikan');
    } else if (mode == 'text') {
      await textTool('Edit Text', 'Teks baru', (value) async {
        final e = await _loadEdits(key);
        (e['ops'] as List).add({'t': 'text', 's': sel, 'v': value});
        await _saveEdits(key, e);
        await _runApply(e);
        _message('Teks diubah');
      }, initial: (d['text'] ?? '').toString());
    }
  }

  void _showInspect(Map<String, dynamic> d) {
    final attrs = (d['attrs'] as Map?)?.entries.map((e) => '${e.key}="${e.value}"').join('\n') ?? '';
    final info = 'Tag: ${d['tag']}\nSelector: ${d['sel']}\n\nAttributes:\n${attrs.isEmpty ? '-' : attrs}\n\nHTML:\n${d['html']}';
    if (!mounted) return;
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Inspect Element'),
      content: SingleChildScrollView(child: SelectableText(info, style: const TextStyle(fontSize: 12))),
      actions: [
        TextButton(onPressed: () async {
          await Clipboard.setData(ClipboardData(text: info));
          if (ctx.mounted) Navigator.pop(ctx);
          _message('Hasil disalin');
        }, child: const Text('Copy')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
      ],
    ));
  }

  Future<void> editCss() async {
    final key = _editKey();
    if (key == null || !loaded) { _message('Buka halaman terlebih dahulu'); return; }
    final e = await _loadEdits(key);
    await textTool('Edit CSS', 'Contoh: body{background:#000} h1{color:red}', (value) async {
      e['css'] = value;
      await _saveEdits(key, e);
      await _runApply(e);
      _message('CSS diterapkan');
    }, initial: (e['css'] ?? '').toString(), lines: 6);
  }

  Future<void> resetEdits() async {
    final key = _editKey();
    if (key == null) { _message('Buka halaman terlebih dahulu'); return; }
    final p = await SharedPreferences.getInstance();
    await p.remove(key);
    if (loaded) {
      stopRequested = false;
      setState(() { loading = true; status = 'LOADING'; });
      await web.reload();
    }
    _message('Perubahan situs ini direset');
  }

  Future<void> viewSource() async {
    try {
      final r = await web.runJavaScriptReturningResult('document.documentElement.outerHTML');
      var s = r.toString();
      try { final d = jsonDecode(s); if (d is String) s = d; } catch (_) {}
      if (!mounted) return;
      final shown = s.length > 30000 ? '${s.substring(0, 30000)}\n... (dipotong, tekan Copy untuk isi lengkap)' : s;
      showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Page Source'),
        content: SingleChildScrollView(child: SelectableText(shown, style: const TextStyle(fontSize: 11))),
        actions: [
          TextButton(onPressed: () async {
            await Clipboard.setData(ClipboardData(text: s));
            if (ctx.mounted) Navigator.pop(ctx);
            _message('Source disalin');
          }, child: const Text('Copy')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ));
    } catch (_) { _message('Buka halaman terlebih dahulu'); }
  }

  Widget _toolGrid() {
    final items = <(String, IconData, VoidCallback)>[
      ('Back', Icons.arrow_back, () => navigate(false)),
      ('Forward', Icons.arrow_forward, () => navigate(true)),
      ('Stop', Icons.stop_rounded, stopPage),
      ('Reload', Icons.refresh_rounded, () async { if (currentUrl.isNotEmpty) { stopRequested = false; setState(() { loading = true; status = 'LOADING'; }); await web.reload(); } }),
      ('Clear', Icons.clear, clearPage),
      ('Copy URL', Icons.copy, copyUrl),
      ('Params', Icons.tune_rounded, openParams),
      ('Headers', Icons.subject, editHeaders),
      ('Body', Icons.data_object, sendBody),
      ('Cookies', Icons.cookie_outlined, showCookies),
      ('User-Agent', Icons.manage_accounts_outlined, editUserAgent),
      ('Encode', Icons.lock_outline, () => openCodec(true)),
      ('Decode', Icons.lock_open_outlined, () => openCodec(false)),
      ('Find', Icons.search, findText),
      ('Source', Icons.code, viewSource),
      ('Edit Text', Icons.edit_outlined, () => startPick('text')),
      ('Edit CSS', Icons.css, editCss),
      ('Hide Element', Icons.visibility_off_outlined, () => startPick('hide')),
      ('Inspect', Icons.manage_search, () => startPick('inspect')),
      ('Reset Changes', Icons.restart_alt, resetEdits),
    ];
    return SizedBox(height: 172, child: GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 7, crossAxisSpacing: 7, mainAxisExtent: 42),
      itemCount: items.length,
      itemBuilder: (_, i) => _gridBtn(items[i].$1, items[i].$2, items[i].$3),
    ));
  }

  Widget _gridBtn(String label, IconData icon, VoidCallback onTap) => OutlinedButton.icon(
    onPressed: onTap, icon: Icon(icon, size: 16),
    label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
    style: OutlinedButton.styleFrom(foregroundColor: purpleLight, side: const BorderSide(color: line),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  Widget action(String label, IconData icon, VoidCallback onTap, {bool primary = false}) => SizedBox(height: 42, child: primary ? FilledButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label), style: FilledButton.styleFrom(backgroundColor: purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))) : OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 17), label: Text(label), style: OutlinedButton.styleFrom(foregroundColor: purpleLight, side: const BorderSide(color: line), padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))));
  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 13, 16, 10), child: Row(children: [ClipOval(child: Image.asset('assets/logo.png', width: 43, height: 43, fit: BoxFit.cover)), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sqile Protax', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -.6)), SizedBox(height: 1), Text('By Farid - DoctorRIDX', style: TextStyle(color: muted, fontSize: 12))])), IconButton(tooltip: 'Privacy Policy', onPressed: () => showDialog(context: context, builder: (_) => const AlertDialog(title: Text('Privacy Policy'), content: Text('Situs dibuka di WebView. Data yang dikirim melalui situs diterima oleh situs tujuan. Encode/decode berjalan lokal. Sqile tidak mengunggah riwayat browsing ke server Sqile.'), actions: [CloseButton()])), icon: const Icon(Icons.privacy_tip_outlined, color: purpleLight))])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [Expanded(child: TextField(controller: urlInput, keyboardType: TextInputType.url, textInputAction: TextInputAction.go, onSubmitted: (_) => runUrl(), decoration: const InputDecoration(hintText: 'https://example.com', prefixIcon: Icon(Icons.link, color: purpleLight), isDense: true))), const SizedBox(width: 8), SizedBox(height: 49, child: FilledButton(onPressed: runUrl, style: FilledButton.styleFrom(backgroundColor: purple, padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Icon(Icons.play_arrow_rounded))) ])),
      _toolGrid(),
      Container(height: 1, color: line),
      Expanded(child: Stack(children: [WebViewWidget(controller: web), if (!loaded) Positioned.fill(child: IgnorePointer(child: Container(color: bg, child: Center(child: ClipOval(child: Image.asset('assets/logo.png', width: 76, height: 76, fit: BoxFit.cover)))))), if (loading) Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(value: progress == 0 || progress >= 100 ? null : progress / 100, minHeight: 2, backgroundColor: panel2, color: purpleLight))])),
      Container(color: panel, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: status == 'ERROR' ? Colors.redAccent : status == 'LOADED' ? const Color(0xFF7BC8A4) : purpleLight, shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(status, style: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w700, letterSpacing: .6), maxLines: 1, overflow: TextOverflow.ellipsis)), if (currentUrl.isNotEmpty) Flexible(child: Text(Uri.tryParse(currentUrl)?.host ?? '', style: const TextStyle(color: muted, fontSize: 11), overflow: TextOverflow.ellipsis))]))
    ])),
  );
}
