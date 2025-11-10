import 'dart:io';

void main() {
  final now = DateTime.now();
  final formatted = now
      .toIso8601String()
      .replaceFirst('T', ' ')
      .split('.')
      .first;

  final file = File('lib/build_info.dart');
  file.writeAsStringSync('''
// ⚙️ Auto-generated at build time — do not edit manually.
const String buildTime = '$formatted';
''');
  print('✅ Build time updated: $formatted');
}
