import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

import 'dart:async';
import 'dart:ui';

import 'package:sprintf/sprintf.dart';

import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:tracktok/ttglobal.dart';
import 'ttuploader.dart';
import 'ttevent.dart';
// import 'package:pedometer/pedometer.dart';

class TTTrackingScreen extends StatefulWidget {
  const TTTrackingScreen({
    Key key,
    this.event,
  }) : super(key: key);

  final TTEvent event;

  @override
  _TrackingState createState() => _TrackingState();
}

class _TrackingState extends State<TTTrackingScreen>
    with WidgetsBindingObserver {
  // final isolates = IsolateHandler();
  final uploader = TTUploader();
  DateTime lastUpload;
  Map<String, dynamic> data = {};
  bool isReady = false;
  bool trackerOn;
  DateTime start;

  Duration get remaining {
    return widget.event.duration - duration;
  }

  Duration get duration {
    return now.difference(start);
  }

  DateTime get now {
    return DateTime.now();
  }

  int locationCnt = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    startTracker();
  }

  Timer tickerTimer;
  Future startTracker() async {
    bg.BackgroundGeolocation.onLocation(onLocation, (bg.LocationError error) {
      print('[onLocation] ERROR: $error');
    });
    start = DateTime.now();
    await bg.BackgroundGeolocation.start();
    await bg.BackgroundGeolocation.setOdometer(0);

    tickerTimer = Timer.periodic(Duration(seconds: 1), (t) {
      if (remaining.inSeconds >= 0) {
        data['remaining'] = DateTime.fromMillisecondsSinceEpoch(
          remaining.inMilliseconds,
          isUtc: true,
        );
        if (mounted) {
          setState(() {});
        }
      } else {
        t.cancel();
        tickerTimer = null;
      }
    });
    trackerOn = true;
    if (mounted) {
      setState(() {});
    }
    return;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopTracker();
    if (tickerTimer != null) {
      tickerTimer.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if ((await bg.BackgroundGeolocation.state).enabled == true) {
        bg.BackgroundGeolocation.changePace(true);
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  Future stopTracker() async {
    if (trackerOn == true) {
      if (tickerTimer != null) {
        tickerTimer.cancel();
        tickerTimer = null;
      }
      await bg.BackgroundGeolocation.removeListeners();
      await bg.BackgroundGeolocation.stop();
      trackerOn = false;
      if (mounted) {
        setState(() {});
      }
    }
    return;
  }

  var trackProcessing = false;
  void onLocation(bg.Location location) async {
    if (trackProcessing || start == null) {
      return;
    }
    trackProcessing = true;
    try {
      // print("Got Location $location");
      if (trackerOn == false) {
        print("Skipping location - trackerOff");
        trackProcessing = false;
        return;
      }
      if (trackerOn == null) {
        trackProcessing = false;
        return;
      }

      var tpk = '-';
      if (location.coords.speed > 0) {
        var sm = 1.0 / location.coords.speed / 60.0 * 1000.0;
        var smm = sm.floor();
        var sms = ((sm - smm) * 60.0).floor();
        tpk = smm <= 99 ? "$smm'$sms" + '" km' : null;
      }
      data = <String, dynamic>{
        'distance': location.odometer / 1000,
        'remaining': DateTime.fromMillisecondsSinceEpoch(
          remaining.inMilliseconds,
          isUtc: true,
        ),
        'steps': 0,
        'alt': location.coords.altitude,
        'tpk': tpk,
        'accuracy': location.coords.accuracy,
        'heading': location.coords.heading
      };
      var track = <String, int>{
        'distance_m': (data['distance'] * 1000).floor(),
        'duration_s': duration.inSeconds,
        'up_m': 0,
        'down_m': 0,
        'steps': 0
      };

      if (remaining.inMilliseconds <= 0) {
        track['distance_m'] = (track['distance_m'] /
                duration.inMilliseconds *
                widget.event.duration.inMilliseconds)
            .floor();
        track['duration_s'] = duration.inSeconds;
        uploader.push(widget.event, start, track);
        await stopTracker();
        data['remaining'] = DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        );
        if (mounted) {
          setState(() {});
        }
        return;
      }
      if (lastUpload == null ||
          now.difference(lastUpload) > TTGlobal.uploadInterval) {
        lastUpload = now;
        uploader.push(widget.event, start, track);
      }
      if (mounted) {
        setState(() {});
      }
    } catch (err) {
      print("Location Processing Error: $err");
    }
    trackProcessing = false;
    return;
  }

  Future<bool> onStop(BuildContext context) async {
    bool result = await showDialog(
      context: context,
      builder: (context) {
        bool active = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Expanded(flex: 1, child: Text('Stop Tracking?')),
                  Icon(
                    Icons.timer_off,
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      text: 'Do you want to stop tracking? Type ',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyText1.color,
                      ),
                      children: [
                        TextSpan(
                          text: 'STOP',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              ' and then tap on the Stop button to end your run early.',
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    onChanged: (String input) {
                      setState(() {
                        active = input.toUpperCase() == 'STOP';
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                MaterialButton(
                  color: Theme.of(context).accentColor,
                  onPressed: active
                      ? () {
                          Navigator.of(context, rootNavigator: true).pop(
                              true); // dismisses only the dialog and returns true
                        }
                      : null,
                  child: Text('Stop'),
                ),
                MaterialButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop(
                        false); // dismisses only the dialog and returns false
                  },
                  child: Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == true) {
      await stopTracker();
    }
    return result;
  }

  String _bePrint(String format, String key) {
    if (data == null || !data.containsKey(key) || data[key] == null) {
      return "";
    }
    return sprintf(format, [data[key]]);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    return WillPopScope(
      onWillPop: () async {
        if (trackerOn == true) {
          await onStop(context);
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.event.name),
        ),
        floatingActionButton: FloatingActionButton.extended(
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onPressed: () async {
            if (trackerOn == true) {
              await onStop(context);
              return;
            }
            Navigator.pop(context);
            return;
          },
          backgroundColor: trackerOn == true
              ? Theme.of(context).accentColor
              : Theme.of(context).primaryColor,
          label: Text(trackerOn == true ? 'Stop Tracking' : 'Close Tracker'),
        ),
        body: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(30),
          child: SafeArea(
            child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
              var width = constraints.constrainWidth() / 2;
              return Column(children: <Widget>[
                Row(children: <Widget>[
                  PropCard(
                      width: width,
                      title: "Remaining",
                      value: data == null
                          ? ""
                          : data['remaining'] is DateTime
                              ? '  ' +
                                  DateFormat.Hms().format(data['remaining'])
                              : data['remaining']),
                  PropCard(
                      width: width,
                      title: "Distance",
                      value: _bePrint("%.2f km", 'distance')),
                ]),
                Row(children: <Widget>[
                  PropCard(
                    width: width,
                    title: "Altitude",
                    value: _bePrint("%.0f m", 'alt'),
                  ),
                  PropCard(
                    width: width,
                    title: "Speed",
                    value: data == null ? "" : data['tpk'],
                  ),
                ]),
                Row(children: <Widget>[
                  PropCard(
                    width: width,
                    title: "Accuracy",
                    value: _bePrint("%.0f m", 'accuracy'),
                  ),
                  PropCard(
                    width: width,
                    title: "Heading",
                    value: _bePrint("%.0f°", 'heading'),
                  ),
                ]),
                if (trackerOn != true)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AutoSizeText(
                          trackerOn == false
                              ? 'FINISH'
                              : 'Waiting for GPS data',
                          stepGranularity: 2,
                          maxFontSize: 84,
                          maxLines: 1,
                          style: TextStyle(
                            color: trackerOn == false
                                ? Theme.of(context).accentColor
                                : Theme.of(context).hintColor,
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

class PropCard extends StatelessWidget {
  static var titleGroup = AutoSizeGroup();
  static var valueGroup = AutoSizeGroup();

  PropCard({
    Key key,
    @required this.title,
    @required this.value,
    @required this.width,
  }) : super(key: key);

  final String title;
  final String value;
  final double width;

  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          FractionallySizedBox(
            alignment: Alignment.bottomRight,
            widthFactor: 0.6,
            child: AutoSizeText(
              '$title',
              textAlign: TextAlign.right,
              group: titleGroup,
              style: TextStyle(
                fontSize: 30,
                fontFeatures: [
                  FontFeature.tabularFigures(),
                ],
              ),
              maxLines: 1,
            ),
          ),
          SizedBox(height: 4),
          FractionallySizedBox(
            alignment: Alignment.bottomRight,
            widthFactor: 0.9,
            child: AutoSizeText(
              value == null || value == "" ? "—       " : value,
              group: valueGroup,
              textAlign: TextAlign.right,
              stepGranularity: 2,
              maxFontSize: 54,
              maxLines: 1,
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                fontFeatures: [
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 16,
          )
        ],
      ),
    );
  }
}
