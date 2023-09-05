import 'dart:async';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ttregistry.dart';
import 'ttevent.dart';
import 'ttglobal.dart';

class TTRegistration {
  TTRegistration();

  String? _tag;
  List<TTEvent>? _events;
  KeyPair? _keyPair;

  Future<KeyPair> get keyPair async {
    if (_keyPair != null) {
      print("return keypair from memory");
      return _keyPair!;
    }
    TTRegistry registry = TTRegistry();
    String? pk64 = await registry.get('privateKey');
    var algo = Ed25519();
    if (pk64 != null) {
      var privateKey = base64Decode(pk64).toList();
      _keyPair = await algo.newKeyPairFromSeed(privateKey);
      print("restored keypair");
      return _keyPair!;
    }

    var _newPair = await algo.newKeyPair();
    List<int> privateKey = await _newPair.extractPrivateKeyBytes();
    await registry.put('privateKey', base64Encode(privateKey));
    print("saved keypair");
    return _newPair;
  }

  Future<String> get tag async {
    if (_tag != null) {
      return _tag!;
    }
    await _registration();
    return _tag!;
  }

  void flushEvents() {
    _events = null;
  }

  Future<List<TTEvent>> get events async {
    if (_events != null) {
      return _events!;
    }
    await _registration();
    return _events!;
  }

  void _loadFromJson(String regString) {
    Map<String, dynamic> data = json.decode(regString);
    List events = data['events'];
    _tag = data['tag'];
    _events = events.map((i) => TTEvent.fromJson(i)).toList(growable: true);
    _events!.add(TTEvent(
        id: 0,
        name: 'Test Run',
        duration: TTGlobal.testRunDuration,
        parts: []),);
  }

  Future _registration() async {
    // try calling the server to get the latest
    // registration data from the server
    // if this fails fall back to the cache if we have one
    final keyPair = await this.keyPair;
    final SimplePublicKey pubKey =
        await keyPair.extractPublicKey() as SimplePublicKey;
    final nonce = randomBytes(8);
    final payload = pubKey.bytes + nonce;
    final signature = await Ed25519().sign(
      payload,
      keyPair: keyPair,
    );
    TTRegistry registry = TTRegistry();
    try {
      final client = http.Client();
      print("call " + TTGlobal.server + '/REST/v1/register');
      final uriResponse =
          await client.post(Uri.parse(TTGlobal.server + '/REST/v1/register'),
              headers: <String, String>{
                'Content-Type': 'application/json; charset=UTF-8',
              },
              body: jsonEncode(<String, String>{
                'pubKey': base64Encode(pubKey.bytes),
                'nonce': base64Encode(nonce),
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
      client.close();
    } catch (err) {
      print("ERROR:" + err.toString());
    }
    if (this._tag == null) {
      var regString = await registry.get('registration');
      this._loadFromJson(regString!);
      print("falling back to loading from cache: $regString");
    }
  }
}
