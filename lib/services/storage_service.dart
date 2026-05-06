import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static const String _boxName = 'events';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
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

  static Future<void> deleteEvent(String id) async {
    await _box.delete(id);
  }
}
