# YGNTV Customer Android release

The public unofficial v1 is `1.0.0` (Android `versionCode` 2018), package `org.ygntv.ygntv_customer`, arm64-v8a only. The download page is <https://ygntv.org/app/> and the stable update manifest is <https://ygntv.org/app-updates/customer-stable/latest.json>.

## Build the next release

Increase both the app version and build number in `pubspec.yaml`, run the Flutter tests, then build the arm64 split APK with the ABI version-code offset disabled:

```bash
flutter test
flutter build apk --release --split-per-abi --target-platform android-arm64 --android-project-arg=force-version-code-ignoring-abi=true
```

The APK output is `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. Update the stable manifest only after validating the APK's package, version, arm64-only contents, signature, file size, and SHA-256.

## Signing-key safety

Release signing credentials are local-only: `android/key.properties` and `android/app/ygntv-customer-release.p12` are ignored by Git. Every future APK must use the same release key as v1 or Android will reject it as an update. Keep the owner backup archive private and backed up separately; never upload the keystore or password to the website or repository.

The older private TEST build used a different debug signing certificate. Users with that build may need to uninstall it before installing this public release; uninstalling can erase locally stored app data.
