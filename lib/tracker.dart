import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'dart:math';
import 'ttupload.dart';
import 'package:geolocator/geolocator.dart';

class Tracker {
  Tracker(
    this.messenger,
    this.event,
  );
  final int event;
  final messenger;
  // final _uploadInterval = 1000 * 60 * 5;
  final _uploadInterval = 1000 * 5;
  void start() async {
    Map<String, dynamic> data = {
      'remaining': "locating",
    };
    double totalUp = 0.0;
    double totalDown = 0.0;
    TTUpload uploader;

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
          uploader = TTUpload(
            event: event,
            startTs: (startTime / 1000).floor(),
          );
        }
        totalDistance += distance;
        var assent = position.altitude - positionPrev.altitude;
        if (assent > 0) {
          totalUp += assent;
        } else {
          totalDown -= assent;
        }
        positionPrev = position;
      }
    });
    bool go = true;
    messenger.listen((msg) {
      if (msg is String && msg == "stop") {
        pedometerStream.cancel();
        positionStream.cancel();
        go = false;
      }
    });
    /* initial send */
    data['stepCount'] = 0;
    data['distance'] = 0.0;
    data['cnt'] = 0;
    data['alt'] = 0.0;
    int lastUpload;

    while (go) {
      if (startTime != null) {
        int elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
        data['remaining'] = DateTime.fromMillisecondsSinceEpoch(
          3600 * 2000 - elapsed,
          isUtc: true,
        );
        if (lastUpload == null || elapsed - lastUpload > _uploadInterval) {
          lastUpload = elapsed;
          uploader.upload({
            'distance_m': (data['distance'] * 1000).floor(),
            'duration_s': (elapsed / 1000).floor(),
            'up_m': totalUp.floor(),
            'down_m': totalDown.floor(),
            'steps': data['stepCount']
          });
        }
      }
      messenger.send(data);
      await Future.delayed(Duration(seconds: 1));
    }
  }
}
