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

  TTRegistration _registration;
  KeyPair _keyPair;

  Future<String> dbPath() async {
    final dir = Platform.isIOS
        ? await getLibraryDirectory()
        : await getApplicationSupportDirectory();
    return p.join(dir.path, 'tracktok.db');
  }

  Future<Database> db() async {
    return databaseFactoryIo.openDatabase(await dbPath());
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

  Future<TTRegistration> get register async {
    // try calling the server to get the latest
    // registration data from the server
    // if this fails fall back to the cache if we have one
    final keyPair = await this.keyPair;
    final pubKey = keyPair.publicKey;
    final client = http.Client();
    final nonce = Nonce.randomBytes(8);
    final payload = pubKey.bytes + nonce.bytes;
    final signature = await ed25519.sign(
      payload,
      keyPair,
    );
    var registry = StoreRef<String, String>.main();
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
        var regString = uriResponse.body;
        var reg = TTRegistration.fromJson(json.decode(regString));
        print("registered with backend: $regString");
        var rec = registry.record('registration');
        final dbh = await db();
        rec.put(dbh, regString);
        dbh.close();
        print("store tag in db");
        _registration = reg;
      } else {
        print(uriResponse.body.toString());
      }
    } catch (err) {
      print("ERROR:" + err.toString());
    }
    client.close();
    if (_registration == null) {
      var rec = registry.record('registration');
      var dbh = await db();
      var regString = await rec.get(dbh);
      if (regString != null) {
        print("falling back to loading from cache: $regString");
        _registration = TTRegistration.fromJson(json.decode(regString));
      }
    }
    return _registration;
  }
}

class TTRegistration {
  final String tag;
  final List<TTEvent> events;

  TTRegistration({this.tag, this.events});

  factory TTRegistration.fromJson(Map<String, dynamic> json) {
    List events = json['events'];

    var registration = TTRegistration(
      tag: json['tag'],
      events: events.map((i) => TTEvent.fromJson(i)).toList(growable: true),
    );
    registration.events.add(TTEvent(id: 0, name: 'Test Run', parts: []));
    return registration;
  }
}

class TTEvent {
  final int id;
  final DateTime startOfficial;
  final DateTime startFirst;
  final DateTime startLast;
  final Duration duration;
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
          DateTime.fromMillisecondsSinceEpoch(json['start_official_ts'] * 1000),
      startFirst:
          DateTime.fromMillisecondsSinceEpoch(json['start_first_ts'] * 1000),
      startLast:
          DateTime.fromMillisecondsSinceEpoch(json['start_last_ts'] * 1000),
      duration: Duration(seconds: json['duration_s']),
      name: json['name'],
      parts: (json['parts'] as List).map((part) => part.toString()).toList(),
    );
  }
}
