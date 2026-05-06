import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/participant.dart';

class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  static const String _queueBoxName = 'pending_checkins';

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;
  late Box _queueBox;

  bool _isInitialized = false;
  bool _isOnline = true;
  String _apiBaseUrl = 'http://localhost:3000/api';

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  bool get hasPendingActions => _isInitialized && _queueBox.isNotEmpty;

  Future<void> initialize({
    String apiBaseUrl = 'http://localhost:3000/api',
  }) async {
    if (_isInitialized) {
      return;
    }

    _apiBaseUrl = apiBaseUrl;
    _queueBox = await Hive.openBox(_queueBoxName);
    _isInitialized = true;

    final initial = await _connectivity.checkConnectivity();
    _updateConnectivity(initial);

    _subscription = _connectivity.onConnectivityChanged.listen((result) async {
      final changed = _updateConnectivity(result);
      if (changed && _isOnline) {
        await syncPendingCheckIns();
      }
    });

    if (_isOnline) {
      await syncPendingCheckIns();
    }
  }

  bool _updateConnectivity(ConnectivityResult result) {
    final online = result != ConnectivityResult.none;
    if (online == _isOnline) {
      return false;
    }
    _isOnline = online;
    notifyListeners();
    return true;
  }

  Future<void> queueCheckIn(Participant participant) async {
    if (!_isInitialized) {
      return;
    }

    final payload = <String, dynamic>{
      'participantId': participant.id,
      'eventId': participant.eventId,
      'checkInTime': participant.checkInTime?.toIso8601String(),
      'queuedAt': DateTime.now().toIso8601String(),
    };
    final queueKey =
        '${DateTime.now().microsecondsSinceEpoch}_${participant.id}';
    await _queueBox.put(queueKey, payload);
    notifyListeners();

    if (_isOnline) {
      await syncPendingCheckIns();
    }
  }

  Future<void> syncPendingCheckIns() async {
    if (!_isInitialized || !_isOnline || _queueBox.isEmpty) {
      return;
    }

    final pendingEntries = _queueBox.toMap().entries.toList()
      ..sort((left, right) {
        final leftQueuedAt = DateTime.parse(
          (left.value as Map)['queuedAt'] as String,
        );
        final rightQueuedAt = DateTime.parse(
          (right.value as Map)['queuedAt'] as String,
        );
        return leftQueuedAt.compareTo(rightQueuedAt);
      });

    for (final entry in pendingEntries) {
      final payload = Map<String, dynamic>.from(entry.value as Map);
      final synced = await _postCheckIn(payload);
      if (synced) {
        await _queueBox.delete(entry.key);
      } else {
        break;
      }
    }

    notifyListeners();
  }

  Future<bool> _postCheckIn(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/checkins'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
