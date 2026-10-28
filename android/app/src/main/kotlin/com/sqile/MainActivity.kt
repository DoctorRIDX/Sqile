package com.sqile

import android.content.pm.PackageManager
import android.os.Build
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.sqile/security").setMethodCallHandler { call, result ->
      if (call.method != "scanApk") { result.notImplemented(); return@setMethodCallHandler }
      val path = call.argument<String>("path")
      if (path.isNullOrBlank() || !File(path).isFile) { result.error("INVALID_FILE", "File APK tidak ditemukan.", null); return@setMethodCallHandler }
      try {
        @Suppress("DEPRECATION")
        val info = if (Build.VERSION.SDK_INT >= 33) packageManager.getPackageArchiveInfo(path, PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong())) else packageManager.getPackageArchiveInfo(path, PackageManager.GET_PERMISSIONS)
        if (info == null) { result.error("INVALID_APK", "File tidak dapat dibaca sebagai APK.", null); return@setMethodCallHandler }
        val perms = info.requestedPermissions?.toList() ?: emptyList()
        val sensitive = listOf("CAMERA", "RECORD_AUDIO", "ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION", "READ_SMS", "SEND_SMS", "READ_CONTACTS", "READ_CALL_LOG", "SYSTEM_ALERT_WINDOW", "REQUEST_INSTALL_PACKAGES", "READ_PHONE_STATE", "ACCESS_BACKGROUND_LOCATION")
        val flagged = perms.filter { p -> sensitive.any { p.endsWith(it) } }
        val high = listOf("SEND_SMS", "READ_SMS", "SYSTEM_ALERT_WINDOW", "REQUEST_INSTALL_PACKAGES")
        val risk = when { flagged.any { p -> high.any { p.endsWith(it) } } -> "High"; flagged.isNotEmpty() -> "Review"; else -> "Low" }
        result.success(mapOf("appName" to (info.applicationInfo?.loadLabel(packageManager)?.toString() ?: File(path).name), "packageName" to info.packageName, "versionName" to (info.versionName ?: "Unknown"), "permissions" to perms, "sensitivePermissions" to flagged, "risk" to risk))
      } catch (e: Exception) { result.error("SCAN_FAILED", e.message ?: "Gagal membaca APK.", null) }
    }
  }
}
