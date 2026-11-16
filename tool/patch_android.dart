// Run once before building the APK:   dart run tool/patch_android.dart
// Adds the INTERNET permission (needed only for map tiles) and sets the app name.
import 'dart:io';

void main() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) {
    stderr.writeln('android/ folder not found. Run this inside your Flutter project folder.');
    exit(1);
  }
  var s = f.readAsStringSync();
  if (!s.contains('android.permission.INTERNET')) {
    s = s.replaceFirst('<application',
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application');
  }
  s = s.replaceFirstMapped(
      RegExp(r'android:label="[^"]*"'), (m) => 'android:label="Smart Traffic"');
  f.writeAsStringSync(s);
  stdout.writeln('AndroidManifest.xml patched.');
}
