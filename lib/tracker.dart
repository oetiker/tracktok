import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'dart:math';
import 'ttuploader.dart';
import 'package:geolocator/geolocator.dart';
import 'ttevent.dart';
import 'ttglobal.dart';

class Tracker {
  Tracker(
    this.messenger,
  );
  TTEvent event = TTEvent(
    id: 0,
    duration: Duration(seconds: 10),
  );
  final messenger;
  final uploader = TTUploader();

  void start() async {
    Map<String, dynamic> data = {
      'status': 'locating',
    };
    double totalUp = 0.0;
    double totalDown = 0.0;
    uploader.stopSyncBack();

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
    DateTime startTime;
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
        data['state'] = 'running';
        data['distance'] = (totalDistance + distance) / 1000;
        data['alt'] = position.altitude;
        data['accuracy'] = position.accuracy;
        data['speed'] = position.speed;
        data['ts'] = position.timestamp;

        data['heading'] = position.heading;
        data['cnt'] = locationCnt++;
        if (max(positionPrev.accuracy, position.accuracy) > distance) {
          // do not record the position as it does
          // not make sense from a precision perspective
          if (startTime == null && positionPrev.accuracy > position.accuracy) {
            positionPrev = position;
          }
          return;
        }
        if (startTime == null) {
          startTime = DateTime.now();
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
      if (msg is Map) {
        switch (msg['type']) {
          case 'stop':
            go = false;
            break;
          case 'event':
            event = TTEvent(
              duration: Duration(
                milliseconds: msg['eventDurationMs'],
              ),
              id: msg['eventId'],
            );
            break;
        }
      }
    });
    /* initial send */
    data['stepCount'] = 0;
    data['distance'] = 0.0;
    data['cnt'] = 0;
    data['alt'] = 0.0;
    data['elapsed'] = 0;
    int lastUpload = 0;
    int elapsed = 0;
    int remaining = 1;
    while (true) {
      var remaining = 1;
      if (startTime != null) {
        elapsed = DateTime.now().millisecondsSinceEpoch -
            startTime.millisecondsSinceEpoch;
        data['elapsed'] = DateTime.fromMillisecondsSinceEpoch(
          elapsed,
          isUtc: true,
        );
        data['remaining'] = DateTime.fromMillisecondsSinceEpoch(
          event.duration.inMilliseconds - elapsed,
          isUtc: true,
        );
        remaining = data['remaining'].millisecondsSinceEpoch;
        if (!go ||
            elapsed - lastUpload > TTGlobal.uploadInterval.inMilliseconds) {
          lastUpload = elapsed;
          var track = <String, int>{
            'distance_m': (data['distance'] * 1000).floor(),
            'duration_s': (elapsed / 1000).floor(),
            'up_m': totalUp.floor(),
            'down_m': totalDown.floor(),
            'steps': data['stepCount']
          };
          if (go) {
            uploader.push(event, startTime, track);
          } else {
            await uploader.push(event, startTime, track);
          }
        }
        if (remaining <= 0) {
          await uploader.push(event, startTime, {
            'distance_m': (data['distance'] *
                    1000.0 /
                    elapsed *
                    event.duration.inMilliseconds)
                .floor(),
            'duration_s': event.duration.inSeconds,
            'up_m': totalUp.floor(),
            'down_m': totalDown.floor(),
            'steps': data['stepCount']
          });
        }
      }
      messenger.send(data);
      if (!go || remaining <= 0) {
        break;
      }
      await Future.delayed(Duration(seconds: 1));
    }
    // final upload
    pedometerStream.cancel();
    positionStream.cancel();
    messenger.send({'state': 'done'});
  }
}
