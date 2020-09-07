import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';

class TTTag extends StatelessWidget {
  TTTag({
    Key key,
    @required this.tag,
  }) : super(key: key);

  final String tag;

  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: tag));
        final snackbar = SnackBar(
          content: Text("TrackTok tag copied"),
        );
        Scaffold.of(context).showSnackBar(snackbar);
      },
      child: tag == null
          ? Container(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : Card(
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
                        tag,
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
  }
}
