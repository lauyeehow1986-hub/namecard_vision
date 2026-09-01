import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the on-device SQLite file lazily on first use (app runtime).
/// Tests construct `AppDatabase(NativeDatabase.memory())` directly instead.
LazyDatabase openAppDatabase() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'namecard_vision.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
