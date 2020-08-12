import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:ui';

import 'package:sprintf/sprintf.dart';

import 'package:intl/intl.dart';
import 'package:isolate_handler/isolate_handler.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:location_permissions/location_permissions.dart';
import 'tracker.dart';

void main() {
  // LicenseRegistry.addLicense(() async* {
  //   final license = await rootBundle.loadString('google_fonts/OFL.txt');
  //   yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  // });
  return runApp(MaterialApp(
    home: MyApp(),
    title: 'TrackTok',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
        visualDensity: VisualDensity.adaptivePlatformDensity,
        primarySwatch: Colors.indigo,
        accentColor: Colors.redAccent),
  ));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final isolates = IsolateHandler();

  Map<String, dynamic> data;
  bool isRunning = false;
  int locationCnt = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    isolates.send('stop', to: 'tracker');
    super.dispose();
  }

  void trackerReceiver(dynamic status) {
    setState(() {
      data = status;
    });
  }

  // geolocation

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        MoveToBackground.moveTaskToBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TrackTok'),
        ),
        floatingActionButton: FloatingActionButton(
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onPressed: isRunning
                ? () async {
                    await onStop(context);
                  }
                : onStart,
            backgroundColor:
                isRunning ? Colors.redAccent : Colors.lightGreenAccent[700],
            child: Icon(isRunning ? Icons.stop : Icons.play_arrow)),
        body: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(30),
          child: OrientationBuilder(builder: (context, orientation) {
            return SafeArea(
                child: GridView.count(
                    primary: false,
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(0.0),
                    crossAxisCount: orientation == Orientation.portrait ? 2 : 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 8,
                    childAspectRatio:
                        orientation == Orientation.portrait ? 2.3 : 3,
                    children: <Widget>[
                  PropCard(
                      title: "Remaining",
                      value: data == null
                          ? ""
                          : data['remaining'] is DateTime
                              ? DateFormat.Hms().format(data['remaining'])
                              : data['remaining']),
                  PropCard(
                      title: "Distance", value: _bePrint("%.2fkm", 'distance')),
                  PropCard(title: "Steps", value: _bePrint("%d", 'stepCount')),
                  PropCard(title: "Altitude", value: _bePrint("%.0fm", 'alt')),
                  PropCard(title: "Measurements", value: _bePrint("%d", 'cnt')),
                  PropCard(title: "Speed", value: _bePrint("%.1fm/s", 'speed')),
                  PropCard(
                      title: "Accuracy", value: _bePrint("%.0fm", 'accuracy')),
                  PropCard(
                      title: "Heading", value: _bePrint("%.0f°", 'heading')),
                  PropCard(title: "Tag", value: _bePrint("%s", 'tag')),
                ]));
          }),
        ),
      ),
    );
  }

  void onStart() async {
    if (PermissionStatus.granted !=
        await LocationPermissions().requestPermissions(
          permissionLevel: LocationPermissionLevel.locationAlways,
        )) {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Missing Location Permission'),
            content: Text(
                'TrackTok needs to access your location to work! Please open the settings and grant access.'),
            actions: <Widget>[
              FlatButton(
                onPressed: () async {
                  await LocationPermissions().openAppSettings();
                  Navigator.of(context, rootNavigator: true).pop(
                      false); // dismisses only the dialog and returns false
                },
                child: Text('Open Settings'),
              ),
              FlatButton(
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
      return;
    }

    isolates.spawn<dynamic>(
      trackerStarter,
      name: 'tracker',
      onReceive: trackerReceiver,
    );
    setState(() {
      isRunning = true;
    });
  }

  Future onStop(BuildContext context) async {
    bool result = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Do you want to stop tracking?'),
          actions: <Widget>[
            FlatButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true)
                    .pop(false); // dismisses only the dialog and returns false
              },
              child: Text('No'),
            ),
            FlatButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true)
                    .pop(true); // dismisses only the dialog and returns true
              },
              child: Text('Yes'),
            ),
          ],
        );
      },
    );
    if (result == true) {
      isolates.send('stop', to: 'tracker');
      isolates.kill('tracker');
      setState(() {
        isRunning = false;
      });
    }
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
    return OrientationBuilder(builder: (context, orientation) {
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
          SizedBox(height: orientation == Orientation.portrait ? 4 : 0),
          FractionallySizedBox(
            alignment: Alignment.bottomLeft,
            widthFactor: 0.9,
            child: AutoSizeText(
              value == null || value == "" ? "—" : value,
              group: valueGroup,
              stepGranularity: 2,
              maxFontSize: value == null || value == ""
                  ? 28
                  : orientation == Orientation.portrait ? 54 : 32,
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
    });
  }
}

void trackerStarter(Map<String, dynamic> context) async {
  final messenger = HandledIsolate.initialize(context);
  final tracker = Tracker(messenger);
  tracker.start();
}
