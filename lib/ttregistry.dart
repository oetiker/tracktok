import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

class TTRegistry {
  TTRegistry();

  Future<String> _dbPath([String fileName = 'tracktock']) async {
    final dir = Platform.isIOS
        ? await getLibraryDirectory()
        : await getApplicationSupportDirectory();
    return p.join(dir.path, fileName + '.db');
  }

  Future<Database> _db() async {
    return databaseFactoryIo.openDatabase(await _dbPath());
  }

  Future<String> get(String key) async {
    var registry = StoreRef<String, String>.main();
    var rec = registry.record(key);
    var dbh = await _db();
    var ret = await rec.get(dbh);
    dbh.close();
    return ret;
  }

  Future<String> put(String key, String value) async {
    var registry = StoreRef<String, String>.main();
    var rec = registry.record(key);
    var dbh = await _db();
    var ret = await rec.put(dbh, value);
    dbh.close();
    return ret;
  }
}
