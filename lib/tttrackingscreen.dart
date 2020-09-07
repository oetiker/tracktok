import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';
import 'dart:ui';

import 'package:sprintf/sprintf.dart';

import 'package:intl/intl.dart';
import 'package:isolate_handler/isolate_handler.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tracker.dart';
import 'ttevent.dart';

class TTTrackingScreen extends StatefulWidget {
  const TTTrackingScreen({
    Key key,
    @required this.event,
  }) : super(key: key);

  final TTEvent event;

  @override
  _TrackingState createState() => _TrackingState();
}

class _TrackingState extends State<TTTrackingScreen>
    with WidgetsBindingObserver {
  final isolates = IsolateHandler();

  Map<String, dynamic> data = {};
  bool isReady = false;
  bool trackerOn = false;
  Timer refreshTimer;
  int locationCnt = 0;
  static int eventId;
  //final upLink = UpLink();

  // @override
  // void initState() {
  //   super.initState();
  // }

  @override
  void initState() {
    super.initState();
    eventId = widget.event.id;
    isolates.spawn<dynamic>(
      trackerStarter,
      name: 'tracker',
      onReceive: trackerReceiver,
    );
    trackerOn = true;
    // update the display every minute
    refreshTimer = Timer.periodic(
      Duration(minutes: 1),
      (Timer timer) {
        if (mounted) {
          setState(() {});
        }
      },
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    stopTracker();
    if (refreshTimer != null) {
      refreshTimer.cancel();
      refreshTimer = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("APP_STATE: $state");

    if (state == AppLifecycleState.resumed) {
      // user returned to our app
    } else if (state == AppLifecycleState.inactive) {
      // app is inactive
    } else if (state == AppLifecycleState.paused) {
      // user quit our app temporally
    } else if (state == AppLifecycleState.detached) {
      // app detached
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    return WillPopScope(
      onWillPop: () async {
        return await onStop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TrackTok'),
        ),
        floatingActionButton: FloatingActionButton(
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onPressed: () async {
            if (await onStop(context)) {
              Navigator.pop(context);
            }
          },
          backgroundColor: Theme.of(context).accentColor,
          child: Icon(Icons.stop),
        ),
        body: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(30),
          child: SafeArea(
            child: Column(children: <Widget>[
              GridView.count(
                  primary: false,
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(0.0),
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.3,
                  children: <Widget>[
                    PropCard(
                        title: "Remaining",
                        value: data == null
                            ? ""
                            : data['remaining'] is DateTime
                                ? DateFormat.Hms().format(data['remaining'])
                                : data['remaining']),
                    PropCard(
                        title: "Distance",
                        value: _bePrint("%.2fkm", 'distance')),
                    PropCard(
                        title: "Steps", value: _bePrint("%d", 'stepCount')),
                    PropCard(
                        title: "Altitude", value: _bePrint("%.0fm", 'alt')),
                    PropCard(
                        title: "Measurements", value: _bePrint("%d", 'cnt')),
                    PropCard(
                        title: "Speed", value: _bePrint("%.1fm/s", 'speed')),
                    PropCard(
                        title: "Accuracy",
                        value: _bePrint("%.0fm", 'accuracy')),
                    PropCard(
                        title: "Heading", value: _bePrint("%.0f°", 'heading')),
                  ]),
            ]),
          ),
        ),
      ),
    );
  }

  void stopTracker() {
    if (trackerOn) {
      isolates.send('stop', to: 'tracker');
      isolates.kill('tracker');
    }
    trackerOn = false;
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
                        print(active.toString());
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
      stopTracker();
    }
    return result;
  }

  void trackerReceiver(dynamic status) {
    setState(() {
      data = status;
    });
  }

  static void trackerStarter(Map<String, dynamic> context) {
    final messenger = HandledIsolate.initialize(context);
    final tracker = Tracker(messenger, eventId);
    tracker.start();
  }

  String _bePrint(String format, String key) {
    if (data == null || !data.containsKey(key) || data[key] == null) {
      return "";
    }
    return sprintf(format, [data[key]]);
  }
}

class PropCard extends StatelessWidget {
  static var titleGroup = AutoSizeGroup();
  static var valueGroup = AutoSizeGroup();

  PropCard({
    Key key,
    @required this.title,
    @required this.value,
  }) : super(key: key);

  final String title;
  final String value;

  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        FractionallySizedBox(
          alignment: Alignment.bottomLeft,
          widthFactor: 0.6,
          child: AutoSizeText(
            '$title',
            group: titleGroup,
            style: GoogleFonts.roboto(
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
          alignment: Alignment.bottomLeft,
          widthFactor: 0.9,
          child: AutoSizeText(
            value == null || value == "" ? "—" : value,
            group: valueGroup,
            stepGranularity: 2,
            maxFontSize: value == null || value == "" ? 28 : 54,
            maxLines: 1,
            style: GoogleFonts.roboto(
              fontSize: 60,
              fontWeight: FontWeight.bold,
              fontFeatures: [
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
