import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'dart:math';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:kms/kms.dart';
import 'package:kms_flutter/kms_flutter.dart';
import 'package:http/http.dart' as http;

class Tracker {
  Tracker(this.messenger);
  final messenger;
  final kms = flutterKms();

  // find matching keys
  Future<KeyDocument> _getKeyDoc() async {
    KeyDocument keyPairDocument;

    await kms.documentsAsStream().forEach((doc) {
      if (keyPairDocument == null &&
          doc.collection.collectionId == 'TrackTok' &&
          doc.documentId == '25519Sig') {
        keyPairDocument = doc;
        print("Found ${keyPairDocument}");
      }
    });
    if (keyPairDocument == null) {
      keyPairDocument = await kms.collection('TrackTok').createKeyPair(
            documentId: '25519Sig',
            keyExchangeType: null, // We will not do key exchange.
            signatureType: SignatureType.ed25519,
            keyDocumentSecurity: KeyDocumentSecurity.highest,
          );
      print("Generated ${keyPairDocument}");
    }
    return keyPairDocument;
  }

  void start() async {
    TTRegistration reg;
    Map<String, dynamic> data = {
      'remaining': "locating",
    };
    _getKeyDoc().then((keyPairDocument) async {
      final pubKey = await keyPairDocument.getPublicKey();
      final client = http.Client();
      final nonce = Nonce.randomBytes(8);
      final String payload = pubKey.toString() + nonce.toString();
      final signature = await keyPairDocument.sign(payload.codeUnits);
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
          reg = TTRegistration.fromJson(json.decode(uriResponse.body));
          data['tag'] = reg.tag;
        } else {
          print(uriResponse.body.toString());
        }
      } catch (event) {
        print("ERROR:" + event);
      }
      client.close();
    });

    // if (value == null) {}
    int locationCnt = 0;
    // final pedometer = Pedometer();
    StreamSubscription<int> pedometerStream;
    // StreamSubscription<LocationResult> geolocationSub;
    StreamSubscription<Position> positionStream;

    // Location locationPrev;
    Position positionPrev;
    int stepStart;
    double totalDistance = 0;
    int startTime;
    pedometerStream = Pedometer().pedometerStream.listen((
      int stepCount,
    ) {
      if (stepStart == null) {
        stepStart = stepCount;
      }
      data['stepCount'] = stepCount - stepStart;
    }, cancelOnError: true);
    positionStream = Geolocator()
        .getPositionStream(
      LocationOptions(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    )
        .listen((Position position) async {
      if (position != null) {
        if (positionPrev == null) {
          positionPrev = position;
        }
        var distance = await Geolocator().distanceBetween(positionPrev.latitude,
            positionPrev.longitude, position.latitude, position.longitude);
        data['distance'] = (totalDistance + distance) / 1000;
        data['alt'] = position.altitude;
        data['accuracy'] = position.accuracy;
        data['speed'] = position.speed;
        data['ts'] = position.timestamp;

        data['heading'] = position.heading;
        data['cnt'] = locationCnt++;
        if (max(positionPrev.accuracy, position.accuracy) > distance) {
          // do not record the distance as it does
          // not make sense from a precision perspective
          if (startTime == null && positionPrev.accuracy > position.accuracy) {
            positionPrev = position;
          }
          return;
        }
        if (startTime == null) {
          startTime = position.timestamp.millisecondsSinceEpoch;
        }
        totalDistance += distance;
        positionPrev = position;
      }
    });
    messenger.listen((msg) {
      if (msg is String && msg == "stop") {
        pedometerStream.cancel();
        positionStream.cancel();
      }
    });

    /* initial send */
    data['stepCount'] = 0;
    data['distance'] = 0.0;
    data['cnt'] = 0;
    data['alt'] = 0.0;
    while (true) {
      if (startTime != null) {
        int elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
        data['remaining'] = DateTime.fromMillisecondsSinceEpoch(
          3600 * 2000 - elapsed,
          isUtc: true,
        );
      }
      messenger.send(data);
      await Future.delayed(Duration(seconds: 1));
    }
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
