import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/event.dart';
import '../services/storage_service.dart';

class EventProvider extends ChangeNotifier {
  final List<Event> _events = [];
  final _uuid = const Uuid();

  List<Event> get events => List.unmodifiable(_events);

  Future<void> loadEvents() async {
    _events.clear();
    final stored = StorageService.getAllEvents();
    for (final m in stored) {
      _events.add(Event.fromMap(m));
    }
    notifyListeners();
  }

  Future<void> addEvent(String name) async {
    final id = _uuid.v4();
    final event = Event(id: id, name: name);
    _events.add(event);
    await StorageService.saveEvent(id, event.toMap());
    notifyListeners();
  }

  Future<void> toggleCheckIn(String id) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final e = _events[idx];
    e.checkedIn = !e.checkedIn;
    e.checkedInAt = e.checkedIn ? DateTime.now() : null;
    await StorageService.saveEvent(id, e.toMap());
    notifyListeners();
  }

  /// Called when scanning a QR code. If event exists toggle check-in, otherwise create.
  Future<void> processScanned(String payload) async {
    // For simplicity assume payload is event id; adjust parsing as needed.
    final id = payload;
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx != -1) {
      await toggleCheckIn(id);
      return;
    }
    // If not found, create a new event with the scanned id as name as fallback
    final event = Event(
      id: id,
      name: 'Scanned: $id',
      checkedIn: true,
      checkedInAt: DateTime.now(),
    );
    _events.add(event);
    await StorageService.saveEvent(id, event.toMap());
    notifyListeners();
  }
}
