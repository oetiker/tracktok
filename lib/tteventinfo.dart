import 'package:flutter/material.dart';
import 'ttevent.dart';
import 'package:intl/intl.dart';

class TTEventInfo extends StatelessWidget {
  TTEventInfo({
    Key key,
    @required this.event,
  }) : super(key: key);
  final TTEvent event;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(event.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TTLabelValueField(
            label: 'First Start',
            value: DateFormat("d.M.yyyy H:mm").format(event.startFirst),
          ),
          Divider(),
          TTLabelValueField(
            label: 'Official Start',
            value: DateFormat("d.M.yyyy H:mm").format(event.startOfficial),
          ),
          Divider(),
          TTLabelValueField(
            label: 'Duration',
            value: DateFormat("H:mm").format(
                    DateTime.fromMicrosecondsSinceEpoch(
                        event.duration.inMicroseconds,
                        isUtc: true)) +
                ' h',
          ),
          Divider(),
          TTLabelValueField(
            label: 'Last Start',
            value: DateFormat("d.M.yyyy H:mm").format(event.startLast),
          ),
          if (event.parts.length > 0) ...[
            Divider(),
            TTLabelValueField(label: 'In use by', value: event.parts)
          ],
        ],
      ),
    );
  }
}

class TTLabelValueField extends StatelessWidget {
  TTLabelValueField({Key key, @required this.label, @required this.value})
      : super(key: key);
  final String label;
  final dynamic value;
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Text(label), flex: 1),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (value is List)
            ...value.map((v) => Text(v.toString()))
          else
            Text(value.toString())
        ],
      ),
    ]);
  }
}
