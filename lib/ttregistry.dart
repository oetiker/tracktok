import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

class TTRegistry {
  TTRegistry();
  final registry = StoreRef<String, String>.main();
  Future<String> _dbPath([String fileName = 'tracktok']) async {
    final dir = Platform.isIOS
        ? await getLibraryDirectory()
        : await getApplicationSupportDirectory();

    var basePath = p.join(dir.path, fileName);
    var newPath = basePath + '.db';
    var oldPath = basePath + '.json';
    var oldFile = File(oldPath);
    var newFile = File(newPath);
    if (await oldFile.exists()) {
      if (await newFile.exists()) {
        print("Moving $newPath away.");
        await newFile.rename(newPath + '-saved');
      }
      print("Moving $oldPath to $newPath.");
      await oldFile.rename(newPath);
    }
    return newPath;
  }

  Future<Database> _db() async {
    return databaseFactoryIo.openDatabase(await _dbPath());
  }

  Future<String> get(String key) async {
    var rec = registry.record(key);
    var dbh = await _db();
    var ret = await rec.get(dbh);
    dbh.close();
    return ret;
  }

  Future<String> put(String key, String value) async {
    var rec = registry.record(key);
    var dbh = await _db();
    var ret = await rec.put(dbh, value);
    dbh.close();
    return ret;
  }
}
