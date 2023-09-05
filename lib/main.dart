import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tracktok/ttuploader.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'ttregistration.dart';
import 'ttevent.dart';
import 'tttag.dart';
import 'tteventcard.dart';
import 'ttregistry.dart';
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
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.indigo,
      ).copyWith(
        secondary: Colors.redAccent.shade400,
      ),
    ),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool isReady = false;
  int locationCnt = 0;
  final registration = TTRegistration();
  final String version = '1.4.0';
  late String tag;
  late List<TTEvent> events;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Timer.periodic(Duration(/* seconds: */ minutes: 1), (t) {
      if (mounted) {
        setState(() {});
      }
    });
    initBackgroundLocation();
  }

  Future initBackgroundLocation() async {
     TTRegistry registry = TTRegistry();
    String? hasDisclosedBackgroundPermission =
        await registry.get("has_disclosed_background_permission");
    // [Android] Play Store compatibility requires disclosure of background permission before location runtime permission is requested.
    if (hasDisclosedBackgroundPermission != 'ok' &&
        (Theme.of(context).platform == TargetPlatform.android)) {
      AlertDialog dialog = AlertDialog(
        title: Row(
                children: [
                  Expanded(flex: 1, child: Text('Location Access')),
                  Icon(
                    Icons.gps_fixed,
                  ),
                ],
              ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(
                  'TrackTok uses location data to calculate the distance you have covered in your run. It continues todo this even when the app is closed or not in use.'),
              Text(''),
              Text(
                  'The distance data will be uploaded to the TrackTok server. Enter the Tag number you see on the app screen into your 2-Stunden-Lauf entry form to link-up with your TrackTok instance.')
            ],
          ),
        ),
        actions: <Widget>[
          MaterialButton(
            child: Text('Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
      await showDialog(
          context: context, builder: (BuildContext context) => dialog);
      registry.put("has_disclosed_background_permission", 'ok');
    }
    bg.BackgroundGeolocation.onProviderChange(onProviderChange);
    return bg.BackgroundGeolocation.reset(
      bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        showsBackgroundLocationIndicator: true,
        distanceFilter: 1,
        isMoving: true,
        pausesLocationUpdatesAutomatically: false,
        desiredOdometerAccuracy: 30,
        logLevel: bg.Config.LOG_LEVEL_ERROR,
        stopOnTerminate: false,
        startOnBoot: false,
        enableHeadless: true,
        backgroundPermissionRationale: bg.PermissionRationale(
            title:
                "Allow {applicationName} to access this device's location even when the app is closed.",
            message:
                "Once you start a Run, TrackTok accesses the device location for two hours to calculate the distance you ran. The app will continue to access your location in the backgrond when you close it. It will be able to report your run data to the TrackTok server even when you switch to a different app. Note your actual location will NOT be sent anywhere or even stored locally! You can stop the tracking at any time using the [Stop Tracking] button!",
            positiveAction: 'Change to "{backgroundPermissionOptionLabel}"',
            negativeAction: 'Cancel'),
      ),
    );
  }

  Future onProviderChange(bg.ProviderChangeEvent event) async {
    print("[providerchange] - $event");
    // Did the user disable precise locadtion in iOS 14+?
    if (event.accuracyAuthorization ==
        bg.ProviderChangeEvent.ACCURACY_AUTHORIZATION_REDUCED) {
      // Supply "Purpose" key from Info.plist as 1st argument.
      try {
        int accuracyAuthorization =
            await bg.BackgroundGeolocation.requestTemporaryFullAccuracy(
                "TrackTok needs for GPS precision while tracking your run.");
        if (accuracyAuthorization ==
            bg.ProviderChangeEvent.ACCURACY_AUTHORIZATION_FULL) {
          print(
              "[requestTemporaryFullAccuracy] GRANTED:  $accuracyAuthorization");
        } else {
          print(
              "[requestTemporaryFullAccuracy] DENIED:  $accuracyAuthorization");
        }
      } catch (error) {
        print("[requestTemporaryFullAccuracy] FAILED TO SHOW DIALOG: $error");
      }
    }
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
  }

  @override
  Widget build(BuildContext context) {
    // TTUploader().context = context;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    return WillPopScope(
      onWillPop: () async {
        MoveToBackground.moveTaskToBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
            centerTitle: false,
            title: Row(children: [
              Text('TrackTok'),
              Spacer(flex: 1),
              FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<PackageInfo> snapshot,
                  ) {
                    if (snapshot.hasData) {
                      return Text(snapshot.data?.version ?? '?');
                    } else {
                      return Text('???');
                    }
                  }),
            ])),
        body: Container(
          width: double.maxFinite,
          child: SafeArea(
            child: FutureBuilder<List<TTEvent>>(
                future: registration.events,
                builder: (BuildContext context,
                    AsyncSnapshot<List<TTEvent>> snapshot) {
                  Widget? child;
                  if (snapshot.hasData) {
                    events = snapshot.data!;
                    child = ListView(children: [
                      for (var index = 0; index < events.length; index++)
                        TTEventCard(
                          key: UniqueKey(),
                          event: events[index],
                        ),
                      TTTag(
                        key: ValueKey(registration.tag),
                        registration: registration,
                      ),
                    ]);
                  } else if (snapshot.hasError) {
                    child = Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.only(
                            left: 20, right: 20, top: 10, bottom: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 60,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text('Error: ${snapshot.error}'),
                            )
                          ],
                        ));
                  } else {
                    child = Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.only(
                            left: 20, right: 20, top: 10, bottom: 10),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const <Widget>[
                              CircularProgressIndicator(),
                              Padding(
                                padding: EdgeInsets.only(top: 16),
                                child: Text('Loading Events ...'),
                              ),
                            ]));
                  }

                  return RefreshIndicator(
                      onRefresh: () async {
                        registration.flushEvents();
                        events = await registration.events;
                        if (mounted) {
                          setState(() {});
                        }
                        return;
                      },
                      child: child);
                }),
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
