import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:tracktok/tttrackingscreen.dart';
import 'ttevent.dart';
import 'package:slider_button/slider_button.dart';
import 'tteventinfo.dart';
import 'package:permission_handler/permission_handler.dart';

class TTEventCard extends StatelessWidget {
  TTEventCard({
    Key key,
    @required this.event,
  }) : super(key: key);
  static final eventName = AutoSizeGroup();
  static final dateRange = AutoSizeGroup();
  static final timeToGo = AutoSizeGroup();
  final TTEvent event;

  String countDown(DateTime target) {
    Duration diff = target
        .add(Duration(
          minutes: 1,
        ))
        .difference(DateTime.now());
    var days = diff.inDays;
    var hours = diff.inHours % 24;
    var minutes = diff.inMinutes % 60;
    return days.toString() +
        (days == 1 ? ' day ' : ' days ') +
        hours.toString() +
        (hours == 1 ? ' hour ' : ' hours ') +
        minutes.toString() +
        (minutes == 1 ? ' minute ' : ' minutes ');
  }

  Future startTracking(context) async {
    if (await checkPermissions(context)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TTTrackingScreen(event: event),
        ),
      );
    }
    return;
  }

  Future<bool> checkPermissions(context) async {
    Map<Permission, PermissionStatus> ps = await [
      Permission.locationAlways,
      Permission.ignoreBatteryOptimizations,
      Permission.sensors,
      Permission.activityRecognition
    ].request();
    List<Widget> problems = List.empty(growable: true);
    if (ps[Permission.locationAlways].isDenied) {
      problems.add(Text('permanent access to the location service'));
    }
    // if (Platform.isAndroid &&
    //     !ps[Permission.ignoreBatteryOptimizations].isGranted) {
    //   problems.add(Text('be excempt from battery optimizations'));
    // }
    if (ps[Permission.sensors].isDenied ||
        ps[Permission.activityRecognition].isDenied) {
      problems.add(Text('access the motion sensors to count steps'));
    }

    if (problems.length > 0) {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('TrackTok needs the following'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...problems.map(
                  (widget) => Container(
                    padding: EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('-  '),
                        Flexible(
                          child: widget,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                      'Please open the settings dialog and grant the permissions.'),
                ),
              ],
            ),
            actions: <Widget>[
              MaterialButton(
                onPressed: () async {
                  await openAppSettings();
                  Navigator.of(context, rootNavigator: true).pop(
                      false); // dismisses only the dialog and returns false
                },
                child: Text('Open Settings'),
              ),
              MaterialButton(
                onPressed: () {
                  Navigator.of(context, rootNavigator: true)
                      .pop(true); // dismisses only the dialog and returns true
                },
                child: Text('Abort'),
              ),
            ],
          );
        },
      );
      return false;
    }
    return true;
  }

  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    int now = DateTime.now().millisecondsSinceEpoch;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 10,
      margin: EdgeInsets.only(top: 20, left: 20, right: 20),
      child: Column(
        children: <Widget>[
          Container(
            padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
            color: theme.primaryColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Align(
                    //   alignment: Alignment.centerLeft,
                    //   child:
                    Expanded(
                      flex: 1,
                      child: AutoSizeText(
                        event.name,
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        group: eventName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // ),
                    if (event.startFirst != null)
                      IconButton(
                        padding: EdgeInsets.only(left: 16, right: 8),
                        iconSize: 32,
                        alignment: Alignment.centerRight,
                        icon: Icon(Icons.info),
                        color: Colors.white60,
                        tooltip: 'Show Event Information',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return TTEventInfo(
                                event: event,
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
            child: Column(
              children: [
                if (event.startFirst != null &&
                    event.startLast.millisecondsSinceEpoch >= now) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        event.startFirst.millisecondsSinceEpoch > now
                            ? 'Start in'
                            : 'Start within the next',
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(
                        height: 4,
                      ),
                      AutoSizeText(
                        countDown(event.startFirst.millisecondsSinceEpoch > now
                            ? event.startFirst
                            : event.startLast),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 90,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                ],
                if (event.startFirst == null ||
                    (event.startFirst.millisecondsSinceEpoch <= now &&
                        event.startLast.millisecondsSinceEpoch >= now))
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      return SliderButton(
                        dismissible: false,
                        width: constraints.constrainWidth(),
                        boxShadow: BoxShadow(),
                        shimmer: false,
                        action: () {
                          startTracking(context);
                        },
                        vibrationFlag: false,
                        backgroundColor: theme.accentColor,
                        buttonSize: 50,
                        height: 60,

                        ///Put label over here
                        label: Text(
                          "Slide to start!",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        icon: Center(
                          child: Icon(
                            Icons.directions_run,
                            color: theme.accentColor,
                            size: 40.0,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
