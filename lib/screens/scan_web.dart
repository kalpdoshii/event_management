import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/participant.dart';
import '../providers/event_provider.dart';

enum _CheckInMode { qr, manual }

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _manualFormKey = GlobalKey<FormState>();
  final _participantIdController = TextEditingController();
  _CheckInMode _mode = _CheckInMode.qr;
  bool _isSubmitting = false;
  CheckInResult? _lastResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<EventProvider>(context, listen: false);
      provider.loadEvents();
      provider.loadParticipants();
    });
  }

  @override
  void dispose() {
    _participantIdController.dispose();
    super.dispose();
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Check-in failed'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCheckIn(String participantId) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final result = await Provider.of<EventProvider>(
      context,
      listen: false,
    ).checkInParticipant(participantId);

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _lastResult = result;
        _participantIdController.clear();
      });
    } else {
      await _showErrorDialog(result.message);
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submitManual() async {
    if (!_manualFormKey.currentState!.validate()) return;
    await _handleCheckIn(_participantIdController.text);
  }

  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16324F), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.cloud_done, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Web Check-In',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Use manual validation in the browser and keep your queue in sync when connectivity returns.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard(BuildContext context) {
    final result = _lastResult;
    if (result == null || !result.isSuccess || result.participant == null) {
      return const SizedBox.shrink();
    }

    final Participant participant = result.participant!;
    final checkedInTime = participant.checkInTime;
    final checkedInLabel = checkedInTime == null
        ? 'Just now'
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(checkedInTime.toLocal()));

    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Success',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${participant.id} checked in at $checkedInLabel',
                    style: TextStyle(color: Colors.green.shade900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return ToggleButtons(
      isSelected: [_mode == _CheckInMode.qr, _mode == _CheckInMode.manual],
      onPressed: (index) {
        setState(() {
          _mode = _CheckInMode.values[index];
        });
      },
      borderRadius: BorderRadius.circular(12),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('QR Scan'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Manual Entry'),
        ),
      ],
    );
  }

  Widget _buildScannerArea() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const AspectRatio(
            aspectRatio: 1,
            child: Center(
              child: Text(
                'QR scanning is not available on web.\nUse Manual Entry.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManualEntry() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _manualFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Manual Validation',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _participantIdController,
                decoration: const InputDecoration(
                  labelText: 'Participant ID',
                  prefixIcon: Icon(Icons.fingerprint),
                ),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a participant ID';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submitManual(),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isSubmitting ? null : _submitManual,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(_isSubmitting ? 'Checking in...' : 'Check In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-In')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(context),
              const SizedBox(height: 16),
              _buildSuccessCard(context),
              if (_lastResult != null) const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _buildModeToggle(),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _mode == _CheckInMode.qr
                    ? _buildScannerArea()
                    : _buildManualEntry(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScanScreen extends CheckInScreen {
  const ScanScreen({super.key});
}
