# Sqile — Web Security Analysis Lab

Flutter + Dart source project with a purple interface, embedded WebView, report panel, and separate SQL Injection, XSS Analysis, and Security Headers screens.

## Features
- URL entry and in-app WebView with reload/progress indicator.
- Reports panel directly below the WebView.
- SQLi module: builds common **non-destructive lab test strings** locally, lets you copy them, and records notes/results. It does not automatically submit payloads to arbitrary websites.
- XSS module: creates harmless marker strings and provides local output-encoding guidance/checks; it does not inject scripts into a target.
- Security Headers: sends a normal HTTP GET request and reports common security headers returned by the target.
- Local report history for the current app session.
- App logo at `assets/logo.png`.
- GitHub Actions workflow for analysis and Android APK build.

## Requirements
- Flutter stable (Dart 3.4+)
- Android Studio / Android SDK for local Android builds

## Run locally
```bash
flutter pub get
flutter create --platforms=android --org com.sqile .
flutter run
```

## Build APK
```bash
flutter build apk --release
```

## GitHub
Push this folder to a GitHub repository. The workflow at `.github/workflows/build.yml` generates missing Android platform files, runs `flutter analyze`, and builds a release APK.

## Usage boundaries
Only assess systems you own or are explicitly authorized to test. The SQLi and XSS screens are designed as lab helpers and do not launch automated exploit requests. Security-header checks are ordinary HTTP requests.
