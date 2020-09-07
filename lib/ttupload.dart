import 'dart:async';
import 'package:meta/meta.dart';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ttregistry.dart';
import 'ttregistration.dart';

class TTUpload {
  TTUpload({@required this.event, @required this.startTs});
  final int event;
  final int startTs;

  final _registration = TTRegistration();
  final _registry = TTRegistry();

  Future<List<Map<String, int>>> _uploadCache() async {
    var cacheStr = await _registry.get('uploadCache');
    if (cacheStr != null) {
      try {
        var cache = jsonDecode(cacheStr);
        if (cache['event'] == event && cache['startTs'] == startTs) {
          List<Map<String, int>> tracks = [];

          cache['tracks'].forEach((track) {
            tracks.add(Map<String, int>.from(track));
          });
          return tracks;
        } else {
          print("found abandoned cache: ${cache.toString()}");
          _registry.put('uploadCache', null);
        }
      } catch (ex) {
        print("failed to read cache ${cacheStr} ${ex}");
      }
    }
    return [];
  }

  // returns the pending uplodas
  Future<int> upload(Map<String, int> newTrack) async {
    // try calling the server to get the latest
    // registration data from the server
    // if this fails fall back to the cache if we have one
    final keyPair = await _registration.keyPair;
    final pubKey = keyPair.publicKey;
    final client = http.Client();
    final nonce = Nonce.randomBytes(8);
    var payload = pubKey.bytes +
        nonce.bytes +
        utf8.encode(event.toString()) +
        utf8.encode(startTs.toString());
    var tracks = await _uploadCache();
    tracks.add(newTrack);
    print("Store ${newTrack.toString()}");
    await _registry.put(
        'uploadCache',
        jsonEncode({
          'event': event,
          'startTs': startTs,
          'tracks': tracks,
        }));
    tracks.forEach((track) {
      ['distance_m', 'duration_s', 'up_m', 'down_m', 'steps'].forEach((key) {
        payload += utf8.encode(track[key].toString());
      });
    });
    final signature = await ed25519.sign(
      payload,
      keyPair,
    );
    var pending = tracks.length;
    try {
      final uriResponse = await client.post('https://o2h.ch/srv/REST/v1/track',
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode({
            'pubKey': base64Encode(pubKey.bytes),
            'nonce': base64Encode(nonce.bytes),
            'signature': base64Encode(signature.bytes),
            'event': event,
            'start_ts': startTs,
            'tracks': tracks
          }));
      if (uriResponse.statusCode == 200) {
        var list = uriResponse.body;
        print(list);
        _registry.put('uploadCache', null);
        pending = 0;
      } else {
        print(uriResponse.body);
      }
    } catch (err) {
      print("ERROR:" + err.toString());
    }
    client.close();
    return pending;
  }
}
