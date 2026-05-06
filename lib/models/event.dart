class Event {
  final String id;
  final String name;
  bool checkedIn;
  DateTime? checkedInAt;

  Event({
    required this.id,
    required this.name,
    this.checkedIn = false,
    this.checkedInAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'checkedIn': checkedIn,
    'checkedInAt': checkedInAt?.toIso8601String(),
  };

  factory Event.fromMap(Map<dynamic, dynamic> m) => Event(
    id: m['id'] as String,
    name: m['name'] as String,
    checkedIn: m['checkedIn'] as bool? ?? false,
    checkedInAt: m['checkedInAt'] != null
        ? DateTime.parse(m['checkedInAt'])
        : null,
  );
}
