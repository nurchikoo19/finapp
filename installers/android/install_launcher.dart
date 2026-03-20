import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

Future<void> downloadAPK(String url) async {
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/app.apk';

    // Create file and write data
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    print('APK downloaded to: $filePath');
  } else {
    print('Failed to download APK: ${response.statusCode}');
  }
}

Future<void> main() async {
  // Replace with your GitHub release APK URL
  const String apkUrl = 'https://github.com/nurchikoo19/finapp/releases/download/v1.0/app.apk';
  await downloadAPK(apkUrl);
}
