import 'dart:async';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ttregistry.dart';
import 'ttevent.dart';
import 'ttglobal.dart';

class TTRegistration {
  TTRegistration();

  String _tag;
  List<TTEvent> _events;
  KeyPair _keyPair;

  Future<KeyPair> get keyPair async {
    if (_keyPair != null) {
      print("return keypair from memory");
      return _keyPair;
    }
    TTRegistry registry = TTRegistry();
    String pk64 = await registry.get('privateKey');

    if (pk64 != null) {
      var privateKey = PrivateKey(base64Decode(pk64).toList());
      _keyPair = await ed25519.newKeyPairFromSeed(privateKey);
      print("restored keypair");
      return _keyPair;
    }

    _keyPair = await ed25519.newKeyPair();
    List<int> privateKey = await _keyPair.privateKey.extract();
    await registry.put('privateKey', base64Encode(privateKey));
    print("saved keypair");
    return _keyPair;
  }

  Future<String> get tag async {
    if (_tag != null) {
      return _tag;
    }
    await _registration();
    return _tag;
  }

  Future<List<TTEvent>> get events async {
    if (_events != null) {
      return _events;
    }
    await _registration();
    return _events;
  }

  void _loadFromJson(String regString) {
    Map<String, dynamic> data = json.decode(regString);
    List events = data['events'];
    _tag = data['tag'];
    _events = events.map((i) => TTEvent.fromJson(i)).toList(growable: true);
    _events.add(TTEvent(
        id: 0,
        name: 'Test Run',
        duration: TTGlobal.testRunDuration,
        parts: []));
  }

  Future _registration() async {
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
    TTRegistry registry = TTRegistry();
    try {
      final uriResponse =
          await client.post(TTGlobal.server + '/REST/v1/register',
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
        this._loadFromJson(regString);
        print("registered with backend: $regString");
        await registry.put('registration', regString);
      } else {
        print(uriResponse.body.toString());
      }
    } catch (err) {
      print("ERROR:" + err.toString());
    }
    client.close();
    if (this._tag == null) {
      var regString = await registry.get('registration');
      if (regString != null) {
        this._loadFromJson(regString);
        print("falling back to loading from cache: $regString");
      }
    }
  }
}
