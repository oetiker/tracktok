import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:move_to_background/move_to_background.dart';
import 'package:google_fonts/google_fonts.dart';

import 'uplink.dart';
import 'tttag.dart';
import 'tteventcard.dart';

void main() {
  // LicenseRegistry.addLicense(() async* {
  //   final license = await rootBundle.loadString('google_fonts/LICENSE.txt');
  //    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  // });
  WidgetsFlutterBinding.ensureInitialized();
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

class _MyAppState extends State<MyApp> {
  bool isReady = false;
  int locationCnt = 0;
  final upLink = UpLink();
  String tag;
  List<TTEvent> events;

  @override
  void initState() {
    super.initState();
    upLink.register.then((registration) {
      if (registration != null) {
        tag = registration.tag;
        events = registration.events;
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    var eventCount = events == null ? 0 : events.length;
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
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var index = 0; index < eventCount; index++)
                  TTEventCard(event: events[index]),
                TTTag(tag: tag),
              ],
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
