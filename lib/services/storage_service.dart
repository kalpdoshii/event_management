import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static const String _boxName = 'events';
  static const String _participantsBoxName = 'participants';
  static late Box _box;
  static late Box _participantsBox;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _participantsBox = await Hive.openBox(_participantsBoxName);
  }

  static Future<void> saveEvent(String id, Map<String, dynamic> data) async {
    await _box.put(id, data);
  }

  static Map<dynamic, dynamic>? getEvent(String id) {
    return _box.get(id) as Map<dynamic, dynamic>?;
  }

  static List<Map<dynamic, dynamic>> getAllEvents() {
    return _box.values.cast<Map<dynamic, dynamic>>().toList();
  }

  static Future<void> saveParticipant(
    String id,
    Map<String, dynamic> data,
  ) async {
    await _participantsBox.put(id, data);
  }

  static Map<dynamic, dynamic>? getParticipant(String id) {
    return _participantsBox.get(id) as Map<dynamic, dynamic>?;
  }

  static List<Map<dynamic, dynamic>> getAllParticipants() {
    return _participantsBox.values.cast<Map<dynamic, dynamic>>().toList();
  }

  static Future<void> deleteEvent(String id) async {
    await _box.delete(id);
  }

  static Future<void> deleteParticipant(String id) async {
    await _participantsBox.delete(id);
  }
}
