class TTEvent {
  final int id;
  final DateTime startOfficial;
  final DateTime startFirst;
  final DateTime startLast;
  final Duration duration;
  final String name;
  final List<String> parts;
  TTEvent({
    this.id,
    this.duration,
    this.startOfficial,
    this.startFirst,
    this.startLast,
    this.name,
    this.parts,
  });
  factory TTEvent.fromJson(Map<String, dynamic> json) {
    return TTEvent(
      id: json['id'],
      startOfficial:
          DateTime.fromMillisecondsSinceEpoch(json['start_official_ts'] * 1000),
      startFirst:
          DateTime.fromMillisecondsSinceEpoch(json['start_first_ts'] * 1000),
      startLast:
          DateTime.fromMillisecondsSinceEpoch(json['start_last_ts'] * 1000),
      duration: Duration(seconds: json['duration_s']),
      name: json['name'],
      parts: (json['parts'] as List).map((part) => part.toString()).toList(),
    );
  }
}
