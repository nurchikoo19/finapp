import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupService {
  static Future<File> _dbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'finapp.sqlite'));
  }

  /// Creates a backup. Returns the saved path, or null if cancelled.
  static Future<String?> backup() async {
    final db = await _dbFile();
    if (!await db.exists()) return '';

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final fileName = 'finapp_backup_$dateStr.db';

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить резервную копию',
        fileName: fileName,
      );
      if (savePath == null) return null; // user cancelled
      await db.copy(savePath);
      return savePath;
    } else {
      // Android: save alongside the DB file and show path
      final dir = await getApplicationDocumentsDirectory();
      final dest = File(p.join(dir.path, fileName));
      await db.copy(dest.path);
      return dest.path;
    }
  }

  /// Lets user pick a backup file and restores it.
  /// Returns true on success, false if cancelled.
  static Future<bool> restore() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Выбрать файл резервной копии',
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return false;

    final source = File(result.files.single.path!);
    final dest = await _dbFile();
    await source.copy(dest.path);
    return true;
  }
}
