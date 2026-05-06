import 'package:hive/hive.dart';

part 'event.g.dart';

// Generate the adapter with: flutter pub run build_runner build --delete-conflicting-outputs
@HiveType(typeId: 0)
class Event {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime dateTime;

  @HiveField(3)
  final int maxCapacity;

  @HiveField(4)
  bool checkedIn;

  @HiveField(5)
  DateTime? checkedInAt;

  Event({
    required this.id,
    required this.name,
    required this.dateTime,
    required this.maxCapacity,
    this.checkedIn = false,
    this.checkedInAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dateTime': dateTime.toIso8601String(),
    'maxCapacity': maxCapacity,
    'checkedIn': checkedIn,
    'checkedInAt': checkedInAt?.toIso8601String(),
  };

  factory Event.fromJson(Map<dynamic, dynamic> json) => Event(
    id: json['id'] as String,
    name: json['name'] as String,
    dateTime: json['dateTime'] == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : json['dateTime'] is DateTime
        ? json['dateTime'] as DateTime
        : DateTime.parse(json['dateTime'] as String),
    maxCapacity: json['maxCapacity'] as int? ?? 0,
    checkedIn: json['checkedIn'] as bool? ?? false,
    checkedInAt: json['checkedInAt'] == null
        ? null
        : (json['checkedInAt'] is DateTime
              ? json['checkedInAt'] as DateTime
              : DateTime.parse(json['checkedInAt'] as String)),
  );

  Map<String, dynamic> toMap() => toJson();

  factory Event.fromMap(Map<dynamic, dynamic> map) => Event.fromJson(map);
}
