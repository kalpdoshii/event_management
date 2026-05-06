import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/event.dart';
import '../models/participant.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class CheckInResult {
  final bool isSuccess;
  final String message;
  final Participant? participant;

  const CheckInResult._({
    required this.isSuccess,
    required this.message,
    this.participant,
  });

  factory CheckInResult.success({
    required String message,
    Participant? participant,
  }) {
    return CheckInResult._(
      isSuccess: true,
      message: message,
      participant: participant,
    );
  }

  factory CheckInResult.failure(String message) {
    return CheckInResult._(isSuccess: false, message: message);
  }
}

class EventProvider extends ChangeNotifier {
  final List<Event> _events = [];
  final List<Participant> _participants = [];
  final _uuid = const Uuid();

  List<Event> get events => List.unmodifiable(_events);
  List<Participant> get participants => List.unmodifiable(_participants);
  Event? getEventById(String id) {
    try {
      return _events.firstWhere((event) => event.id == id);
    } catch (_) {
      return null;
    }
  }

  Event? getEventByName(String name) {
    final normalized = name.trim().toLowerCase();
    try {
      return _events.firstWhere(
        (event) => event.name.trim().toLowerCase() == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  bool participantExists(String id) {
    return _participants.any((participant) => participant.id == id);
  }

  Participant? getParticipantById(String id) {
    try {
      return _participants.firstWhere((participant) => participant.id == id);
    } catch (_) {
      return null;
    }
  }

  int get totalParticipants => _participants.length;

  int get checkedInCount =>
      _participants.where((participant) => participant.isCheckedIn).length;

  int get totalCapacity =>
      _events.fold<int>(0, (total, event) => total + event.maxCapacity);

  int get remainingCapacity =>
      (totalCapacity - checkedInCount).clamp(0, totalCapacity);

  double get crowdLevel =>
      totalCapacity == 0 ? 0 : checkedInCount / totalCapacity;

  Future<void> loadEvents() async {
    _events.clear();
    final stored = StorageService.getAllEvents();
    for (final m in stored) {
      _events.add(Event.fromMap(m));
    }
    notifyListeners();
  }

  Future<void> loadParticipants() async {
    _participants.clear();
    final stored = StorageService.getAllParticipants();
    for (final m in stored) {
      _participants.add(Participant.fromMap(m));
    }
    notifyListeners();
  }

  Future<CheckInResult> registerParticipant({
    required String id,
    required String name,
    required String eventId,
  }) async {
    final normalizedId = id.trim();
    final normalizedName = name.trim();
    final normalizedEventId = eventId.trim();

    if (normalizedId.isEmpty ||
        normalizedName.isEmpty ||
        normalizedEventId.isEmpty) {
      return CheckInResult.failure(
        'Participant name, ID, and event are required.',
      );
    }

    if (participantExists(normalizedId)) {
      return CheckInResult.failure('Participant ID already exists.');
    }

    final event =
        getEventById(normalizedEventId) ?? getEventByName(normalizedEventId);
    if (event == null) {
      return CheckInResult.failure('Event not found.');
    }

    final participant = Participant(
      id: normalizedId,
      name: normalizedName,
      eventId: event.id,
    );

    _participants.add(participant);
    await StorageService.saveParticipant(participant.id, participant.toMap());
    notifyListeners();
    return CheckInResult.success(
      message: 'Participant registered.',
      participant: participant,
    );
  }

  Future<CheckInResult> registerParticipantFromCsvRow({
    required String id,
    required String name,
    required String eventValue,
  }) async {
    final event = getEventById(eventValue) ?? getEventByName(eventValue);
    if (event == null) {
      return CheckInResult.failure('Event not found for CSV row: $id');
    }
    return registerParticipant(id: id, name: name, eventId: event.id);
  }

  Future<({int imported, int skipped, List<String> errors})> importParticipants(
    List<Participant> participants,
  ) async {
    var imported = 0;
    var skipped = 0;
    final errors = <String>[];

    for (final participant in participants) {
      if (participantExists(participant.id)) {
        skipped++;
        errors.add('Duplicate participant ID: ${participant.id}');
        continue;
      }

      final event = getEventById(participant.eventId);
      if (event == null) {
        skipped++;
        errors.add('Event not found for participant ${participant.id}');
        continue;
      }

      final importedParticipant = Participant(
        id: participant.id.trim(),
        name: participant.name.trim(),
        eventId: event.id,
        isCheckedIn: participant.isCheckedIn,
        checkInTime: participant.checkInTime,
      );

      _participants.add(importedParticipant);
      await StorageService.saveParticipant(
        importedParticipant.id,
        importedParticipant.toMap(),
      );
      imported++;
    }

    notifyListeners();
    return (imported: imported, skipped: skipped, errors: errors);
  }

  Future<void> createEvent({
    required String name,
    required DateTime dateTime,
    required int maxCapacity,
  }) async {
    final id = _uuid.v4();
    final event = Event(
      id: id,
      name: name,
      dateTime: dateTime,
      maxCapacity: maxCapacity,
    );
    _events.add(event);
    await StorageService.saveEvent(id, event.toMap());
    notifyListeners();
  }

  Future<void> addEvent(String name) async {
    await createEvent(name: name, dateTime: DateTime.now(), maxCapacity: 0);
  }

  Future<CheckInResult> checkInParticipant(String participantId) async {
    final normalizedId = participantId.trim();
    if (normalizedId.isEmpty) {
      return CheckInResult.failure('Enter a participant ID.');
    }

    final participantIndex = _participants.indexWhere(
      (participant) => participant.id == normalizedId,
    );
    if (participantIndex == -1) {
      return CheckInResult.failure('Participant ID not found.');
    }

    final participant = _participants[participantIndex];
    if (participant.isCheckedIn) {
      return CheckInResult.failure('Participant is already checked in.');
    }

    final eventIndex = _events.indexWhere(
      (event) => event.id == participant.eventId,
    );
    if (eventIndex == -1) {
      return CheckInResult.failure('Event not found for this participant.');
    }

    final event = _events[eventIndex];
    final checkedInCount = _participants
        .where(
          (entry) => entry.eventId == participant.eventId && entry.isCheckedIn,
        )
        .length;
    if (checkedInCount >= event.maxCapacity) {
      return CheckInResult.failure('Capacity is full.');
    }

    participant.isCheckedIn = true;
    participant.checkInTime = DateTime.now();
    await StorageService.saveParticipant(participant.id, participant.toMap());
    notifyListeners();
    unawaited(SyncService.instance.queueCheckIn(participant));

    return CheckInResult.success(
      message: 'Checked in successfully.',
      participant: participant,
    );
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
    await checkInParticipant(payload);
  }
}
