import 'package:hive/hive.dart';

part 'participant.g.dart';

// Generate the adapter with: flutter pub run build_runner build --delete-conflicting-outputs
@HiveType(typeId: 1)
class Participant {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String eventId;

  @HiveField(3)
  bool isCheckedIn;

  @HiveField(4)
  DateTime? checkInTime;

  Participant({
    required this.id,
    required this.name,
    required this.eventId,
    this.isCheckedIn = false,
    this.checkInTime,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'eventId': eventId,
    'isCheckedIn': isCheckedIn,
    'checkInTime': checkInTime?.toIso8601String(),
  };

  factory Participant.fromJson(Map<dynamic, dynamic> json) => Participant(
    id: json['id'] as String,
    name: json['name'] as String,
    eventId: json['eventId'] as String,
    isCheckedIn: json['isCheckedIn'] as bool? ?? false,
    checkInTime: json['checkInTime'] == null
        ? null
        : (json['checkInTime'] is DateTime
              ? json['checkInTime'] as DateTime
              : DateTime.parse(json['checkInTime'] as String)),
  );

  Map<String, dynamic> toMap() => toJson();

  factory Participant.fromMap(Map<dynamic, dynamic> map) =>
      Participant.fromJson(map);
}