import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:tracktok/ttregistration.dart';

class TTTag extends StatelessWidget {
  TTTag({
    Key? key,
    required this.registration,
  }) : super(key: key);

  final TTRegistration registration;

  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var tag;
    return FutureBuilder<String>(
        future: registration.tag,
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          Widget? child;
          if (snapshot.hasData) {
            tag = snapshot.data!;
            child = GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: tag ?? 'NOTAG'));
                final snackbar = SnackBar(
                  content: Text("TrackTok tag copied"),
                );
                ScaffoldMessenger.of(context).showSnackBar(snackbar);
              },
              child: Card(
                margin: EdgeInsets.only(left: 20, right: 20, top: 20),
                clipBehavior: Clip.antiAlias,
                elevation: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    Container(
                      color: theme.primaryColorLight,
                      padding: EdgeInsets.only(
                          left: 20, right: 20, top: 10, bottom: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AutoSizeText(
                          'Your TrackTock Tag. Tap to copy!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 100,
                            fontFeatures: [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                          left: 20, right: 20, top: 10, bottom: 10),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: AutoSizeText(
                          tag ?? 'NOTAG',
                          style: TextStyle(
                            fontSize: 100,
                            color: Colors.black26,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else if (snapshot.hasError) {
            child = Column(
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
            );
          } else {
            child = Container(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          return child;
        });
  }
}
