# Sqile
Flutter security dashboard starter: welcome/privacy notice, solid dark-purple UI, circular logo, Wi-Fi IP summary, APK permission inspection, reports and GitHub Actions.

## Build
`flutter pub get && dart run flutter_launcher_icons && flutter analyze && flutter build apk --release`
APK: `build/app/outputs/flutter-apk/app-release.apk`

## Limitations
Permission scanning is a heuristic, not a full antivirus engine. Sensitive permissions are risk indicators, not proof of malware. Android generally does not let Sqile overlay Chrome's own download dialog; select a downloaded APK to inspect it. Device-wide ad blocking is not activated in this starter; it requires a properly implemented Android VpnService/DNS tunnel. The Ad Blocker screen explains Android Private DNS instead of claiming traffic is blocked. APK and results are processed locally and not uploaded by this app.
