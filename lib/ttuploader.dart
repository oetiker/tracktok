import 'dart:async';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ttregistry.dart';
import 'ttregistration.dart';
import 'ttglobal.dart';
import 'ttevent.dart';

class TTUploader {
  static final TTUploader _singleton = TTUploader._init();
  final _registration = TTRegistration();
  final _registry = TTRegistry();
  factory TTUploader() => _singleton;
  TTUploader._init(); // empty constructor

  Map<String, Map<String, List<Map<String, int>>>>? _trackCache;

  Future<Map<String, Map<String, List<Map<String, int>>>>?>
      get _trackStore async {
    if (_trackCache != null) {
      return _trackCache;
    }
    _trackCache = {};
    var cacheStr = await _registry.get('uploadCache');
    print("Upload Cache: $cacheStr");
    if (cacheStr != null) {
      try {
        var _tempCache = jsonDecode(cacheStr);
        _tempCache.forEach((eventId, startMap) {
          _trackCache![eventId] = {};
          startMap.forEach((startTs, tracks) {
            _trackCache![eventId]?[startTs] = [];
            tracks.forEach((track) {
              Map<String, int> nt = {};
              track.forEach((k, v) {
                nt[k] = v;
              });
              _trackCache![eventId]?[startTs]?.add(nt);
            });
          });
        });
      } catch (e) {
        print("ERROR: $e");
      }
    }
    return _trackCache;
  }

  Timer? syncBackTimer;
  stopSyncBack() {
    if (syncBackTimer != null) {
      print("Stopping Background Syncer");
      syncBackTimer?.cancel();
      syncBackTimer = null;
    }
  }

  Future startSyncBack() async {
    if (syncBackTimer == null) {
      print("Starting Background Syncer");
      syncBackTimer = Timer.periodic(Duration(seconds: 15), (timer) async {
        if ((await uploadTrackStore()) == 0) {
          print("Nothing more to sync");
          stopSyncBack();
          return;
        }
        // if (context != null) {
        //   final snackbar = SnackBar(
        //     content: Text("Waiting for server connection!"),
        //   );
        //   Scaffold.of(context).showSnackBar(snackbar);
        // }
      });
    }
    return;
  }

  Future<int> uploadTrackStore() async {
    List<Future<int>> tasks = [];
    var ts = await _trackStore;
    bool removedAny = false;
    ts!.forEach((eventId, startMap) {
      startMap.forEach((startTs, tracks) {
        tasks.add(_upload(int.parse(eventId), int.parse(startTs), tracks)
            .then((pending) {
          if (pending == 0) {
            ts[eventId]?.remove(startTs);
            removedAny = true;
          }
          return pending;
        }));
      });
    });
    if (removedAny) {
      print("Storing uploadCache as some content was removed");
      await _registry.put('uploadCache', jsonEncode(ts));
    }
    return Future.wait(tasks).then((counts) {
      int pending = 0;
      counts.forEach((ret) {
        print("- $ret unsaved entries");
        pending += ret;
      });
      return pending;
    });
  }

  Future push(TTEvent event, DateTime startTs, Map<String, int> track) async {
    var ts = await _trackStore;
    var e = event.id.toString();
    var t = (startTs.millisecondsSinceEpoch / 1000).floor().toString();

    if (ts![e] == null) {
      ts[e] = {};
    }
    if (ts[e]![t] == null) {
      ts[e]![t] = [];
    }
    ts[e]?[t]?.add(track);
    if ((await uploadTrackStore()) > 0) {
      print("storeing unsent tracks");
      // if (context != null) {
      //   final snackbar = SnackBar(
      //     content: Text("Storing Tracks for later sending"),
      //   );
      //   Scaffold.of(context).showSnackBar(snackbar);
      // }
      await _registry.put('uploadCache', jsonEncode(ts));
    }
  }

  // returns the pending uploads
  Map<String, bool> uploadInProgress = {};

  Future<int> _upload(
      int eventId, int startTs, List<Map<String, int>> tracks) async {
    var uipKey = eventId.toString() + ':' + startTs.toString();
    var pending = tracks.length;
    print("Tracks to send: ${tracks.toString()}");
    if (pending == 0) {
      return 0;
    }
    if (uploadInProgress[uipKey] == true) {
      print("Skipping upload $uipKey ... already in progress");
      return pending;
    }
    uploadInProgress[uipKey] = true;
    final keyPair = await _registration.keyPair;
    final pubKey = await keyPair.extractPublicKey() as SimplePublicKey;
    final client = http.Client();
    final nonce = randomBytes(8);
    var payload = pubKey.bytes +
        nonce +
        utf8.encode(eventId.toString()) +
        utf8.encode(startTs.toString());

    tracks.forEach((track) {
      ['distance_m', 'duration_s', 'up_m', 'down_m', 'steps'].forEach((key) {
        // print("${key}: ${track[key].toString()}");
        payload += utf8.encode(track[key].toString());
      });
    });
    // print(payload.toString());
    final signature = await Ed25519().sign(
      payload,
      keyPair: keyPair,
    );
    // lets make sure there is only one instance uploading at a time

    try {
      final uriResponse = await client.post(Uri.parse(TTGlobal.server + '/REST/v1/track'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode({
            'pubKey': base64Encode(pubKey.bytes),
            'nonce': base64Encode(nonce),
            'signature': base64Encode(signature.bytes),
            'event': eventId,
            'start_ts': startTs,
            'tracks': tracks
          }));
      if (uriResponse.statusCode == 200) {
        var list = uriResponse.body;
        print("upload success: " + list);
        pending = 0;
      } else {
        print(uriResponse.body);
      }
    } catch (err) {
      print("ERROR:" + err.toString());
    }
    client.close();
    uploadInProgress[uipKey] = false;
    return pending;
  }
}
