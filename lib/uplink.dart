import 'dart:async';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

class UpLink {
  UpLink();

  KeyPair _keyPair;
  String _tag;

  Future<Database> db() async {
    final dbdir = Platform.isIOS
        ? await getLibraryDirectory()
        : await getApplicationSupportDirectory();
    return databaseFactoryIo.openDatabase(p.join(dbdir.path, 'tracktok.json'));
  }

  Future<KeyPair> get keyPair async {
    if (_keyPair != null) {
      print("return keypair from memory");
      return _keyPair;
    }

    var registry = StoreRef<String, String>.main();

    var rec = registry.record('privateKey');
    var dbh = await db();
    var pk64 = await rec.get(dbh);
    dbh.close();
    if (pk64 != null) {
      var privateKey = PrivateKey(base64Decode(pk64).toList());
      _keyPair = await ed25519.newKeyPairFromSeed(privateKey);
      print("restored keypair");
      return _keyPair;
    }

    _keyPair = await ed25519.newKeyPair();
    var privateKey = await _keyPair.privateKey.extract();
    dbh = await db();
    rec.put(dbh, base64Encode(privateKey));
    dbh.close();
    print("saved keypair");

    return _keyPair;
  }

  Future<String> get tag async {
    // find matching keys
    if (_tag != null) {
      print("return tag from memory");
      return _tag;
    }
    var registry = StoreRef<String, String>.main();
    var rec = registry.record('tag');
    var dbh = await db();
    _tag = await rec.get(dbh);
    dbh.close();
    if (_tag != null) {
      print("loaded tag from db");
      return _tag;
    }
    final keyPair = await this.keyPair;

    final pubKey = keyPair.publicKey;
    final client = http.Client();
    final nonce = Nonce.randomBytes(8);
    final payload = pubKey.bytes + nonce.bytes;
    final signature = await ed25519.sign(
      payload,
      keyPair,
    );
    try {
      final uriResponse =
          await client.post('https://o2h.ch/srv/REST/v1/register',
              headers: <String, String>{
                'Content-Type': 'application/json; charset=UTF-8',
              },
              body: jsonEncode(<String, String>{
                'pubKey': base64Encode(pubKey.bytes),
                'nonce': base64Encode(nonce.bytes),
                'signature': base64Encode(signature.bytes),
              }));
      if (uriResponse.statusCode == 200) {
        print("registered with backend");
        var reg = TTRegistration.fromJson(json.decode(uriResponse.body));
        var dbh = await db();
        rec.put(dbh, reg.tag);
        dbh.close();
        print("store tag in db");
        _tag = reg.tag;
      } else {
        print(uriResponse.body.toString());
      }
    } catch (err) {
      print("ERROR:" + err.toString());
    }
    client.close();
    return _tag;
  }
}

class TTRegistration {
  final String tag;
  final List<TTEvent> events;

  TTRegistration({this.tag, this.events});

  factory TTRegistration.fromJson(Map<String, dynamic> json) {
    List events = json['events'];

    return TTRegistration(
      tag: json['tag'],
      events: events.map((i) => TTEvent.fromJson(i)).toList(),
    );
  }
}

class TTEvent {
  final int id;
  final DateTime startOfficial;
  final DateTime startFirst;
  final DateTime startLast;
  final DateTime duration;
  final String name;
  final List<String> parts;
  TTEvent({
    this.id,
    this.duration,
    this.startOfficial,
    this.startFirst,
    this.startLast,
    this.name,
    this.parts,
  });
  factory TTEvent.fromJson(Map<String, dynamic> json) {
    return TTEvent(
      id: json['id'],
      startOfficial:
          DateTime.fromMillisecondsSinceEpoch(json['start_official_ts']),
      startFirst: DateTime.fromMillisecondsSinceEpoch(json['start_first_ts']),
      startLast: DateTime.fromMillisecondsSinceEpoch(json['start_last_ts']),
      duration: DateTime.fromMillisecondsSinceEpoch(json['duration_s']),
      name: json['name'],
      parts: json['parts'],
    );
  }
}
