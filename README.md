# Sqile Protax

Sqile Protax is an Android web-testing utility with an embedded Android WebView, URL loading controls, query parameter editing, URL encode/decode, loading progress, and an in-app privacy policy.

## Features
- Functional WebView using Android WebView through `webview_flutter`.
- URL input with Run, Stop, and Reload controls.
- Query parameter editor for authorized testing.
- URL component encode/decode locally on device.
- Circular app logo loaded from `assets/logo.png` and configured as launcher icon.
- Privacy policy welcome screen.

Use only on websites you own or are authorized to test. Parameter editing is a convenience for ordinary URL testing; it does not imply vulnerability scanning.

## Build APK
Push the project to the `main` branch of a GitHub repository with Actions enabled, or run the `Build Sqile Protax APK` workflow manually. Download `Sqile-Protax-APK` from the successful workflow's Artifacts section.
