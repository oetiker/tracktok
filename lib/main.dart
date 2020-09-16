import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:move_to_background/move_to_background.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tracktok/ttuploader.dart';

import 'ttregistration.dart';
import 'ttevent.dart';
import 'tttag.dart';
import 'tteventcard.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

void main() {
  // LicenseRegistry.addLicense(() async* {
  //   final license = await rootBundle.loadString('google_fonts/LICENSE.txt');
  //    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  // });
  WidgetsFlutterBinding.ensureInitialized();
  TTUploader().startSyncBack();
  return runApp(MaterialApp(
    home: MyApp(),
    title: 'TrackTok',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      textTheme: GoogleFonts.robotoTextTheme(),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      primarySwatch: Colors.indigo,
      accentColor: Colors.redAccent.shade400,
    ),
  ));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool isReady = false;
  int locationCnt = 0;
  final registration = TTRegistration();
  String tag;
  List<TTEvent> events;

  @override
  void initState() {
    super.initState();
    registration.tag.then((newTag) async {
      tag = newTag;
      events = await registration.events;
      if (mounted) {
        setState(() {});
      }
    });
    initBackgroundLocation();
    WidgetsBinding.instance.addObserver(this);
    Timer.periodic(Duration(/* seconds: */ minutes: 1), (t) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future initBackgroundLocation() async {
    return bg.BackgroundGeolocation.reset(
      bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_NAVIGATION,
        showsBackgroundLocationIndicator: true,
        distanceFilter: 1,
        isMoving: true,
        pausesLocationUpdatesAutomatically: false,
        desiredOdometerAccuracy: 30,
        logLevel: bg.Config.LOG_LEVEL_ERROR,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      registration.flushEvents();
      registration.events.then((newEvents) async {
        events = newEvents;
        if (mounted) {
          setState(() {});
        }
      });
    }
    //  else if (state == AppLifecycleState.inactive) {
    //   // app is inactive
    // } else if (state == AppLifecycleState.paused) {
    //   // user quit our app temporally
    // } else if (state == AppLifecycleState.detached) {
    //   // app detached
    // }
  }

  @override
  Widget build(BuildContext context) {
    // TTUploader().context = context;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    var eventCount = events == null ? 0 : events.length;
    Map<int, bool> hide = {};
    var hideTest = false;
    int testId;
    if (events != null) {
      events.asMap().forEach((i, e) {
        if (e.id == 0) {
          testId = i;
          return;
        }
        var now = DateTime.now().millisecondsSinceEpoch;
        if (e.startFirst.subtract(e.duration).millisecondsSinceEpoch < now &&
            e.startLast.millisecondsSinceEpoch > now) {
          hideTest = true;
        }
      });
      if (testId != null && hideTest) {
        hide[testId] = true;
      }
    }
    return WillPopScope(
      onWillPop: () async {
        MoveToBackground.moveTaskToBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TrackTok'),
        ),
        body: Container(
          width: double.maxFinite,
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                registration.flushEvents();
                events = await registration.events;
                if (mounted) {
                  setState(() {});
                }
                return;
              },
              child: ListView(
                children: [
                  for (var index = 0; index < eventCount; index++)
                    if (hide[index] != true) TTEventCard(event: events[index]),
                  TTTag(tag: tag),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// OpenContainer(
//       transitionDuration: 500.milliseconds,
//       closedBuilder: (BuildContext c, VoidCallback action) => Text("Click Me"),
//       openBuilder: (BuildContext c, VoidCallback action) => SomeNewPage(),
//       tappable: true,
//     )
