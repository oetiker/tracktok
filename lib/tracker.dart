import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'dart:math';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:kms/kms.dart';
import 'package:kms_flutter/kms_flutter.dart';

// import 'dart:convert';
// import 'package:cryptography/cryptography.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Tracker {
  Tracker(this.messenger);
  final messenger;
  final kms = flutterKms();

  // find matching keys
  Future<KeyDocument> _getKeyDoc() async {
    KeyDocument document;

    await kms.documentsAsStream().forEach((doc) {
      if (document == null &&
          doc.collection.collectionId == 'TrackTok' &&
          doc.documentId == 'Ed25519') {
        document = doc;
      }
    });
    if (document == null) {
      document = await kms.collection('TrackTok').createKeyPair(
            documentId: 'Ed25519',
            keyExchangeType: null, // We will not do key exchange.
            signatureType: SignatureType.ed25519,
          );
    }
    return document;
  }

  void start() async {
    KeyDocument document = await _getKeyDoc();
    var pubKey = base64Encode((await document.getPublicKey()).bytes);

    // if (value == null) {}
    int locationCnt = 0;
    // final pedometer = Pedometer();
    StreamSubscription<int> pedometerStream;
    // StreamSubscription<LocationResult> geolocationSub;
    StreamSubscription<Position> positionStream;
    Map<String, dynamic> data = {
      "pubKey": pubKey.substring(0, 4) + '-' + pubKey.substring(4, 8)
    };
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
    data['remaining'] = "locating";

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
