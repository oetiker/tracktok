import 'package:flutter/material.dart';
import 'uplink.dart';

class TTEventInfo extends StatelessWidget {
  TTEventInfo({
    Key key,
    @required this.event,
  }) : super(key: key);
  final TTEvent event;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          TTLabelValueField(
            label: 'Start',
            value: event.duration.toString(),
          ),
        ],
      ),
    );
  }
}

class TTLabelValueField extends StatelessWidget {
  TTLabelValueField({Key key, @required this.label, @required this.value})
      : super(key: key);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label), flex: 1),
        Text(value),
      ],
    );
  }
}
