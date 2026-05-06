import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/participant.dart';
import '../providers/event_provider.dart';

class ParticipantRegistrationScreen extends StatefulWidget {
  const ParticipantRegistrationScreen({super.key});

  @override
  State<ParticipantRegistrationScreen> createState() =>
      _ParticipantRegistrationScreenState();
}

class _ParticipantRegistrationScreenState
    extends State<ParticipantRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _qrBoundaryKey = GlobalKey();

  String? _selectedEventId;
  Participant? _latestParticipant;
  bool _isSaving = false;
  bool _isImporting = false;

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
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<Uint8List> _captureQrBytes() async {
    final boundary =
        _qrBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('QR code is not ready yet.');
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Unable to generate QR image.');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _shareQr(Participant participant) async {
    try {
      final bytes = await _captureQrBytes();
      await Share.shareXFiles([
        XFile.fromData(
          bytes,
          name: 'participant_${participant.id}.png',
          mimeType: 'image/png',
        ),
      ], text: 'Participant QR for ${participant.name} (${participant.id})');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to share QR code: $error')),
      );
    }
  }

  Future<void> _showQrDialog(Participant participant) async {
    setState(() {
      _latestParticipant = participant;
    });

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                participant.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text('ID: ${participant.id}'),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _qrBoundaryKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: QrImageView(
                    data: participant.id,
                    version: QrVersions.auto,
                    size: 220,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareQr(participant),
                      icon: const Icon(Icons.share),
                      label: const Text('Share / Save QR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitParticipant() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEventId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an event.')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final result = await Provider.of<EventProvider>(context, listen: false)
        .registerParticipant(
          id: _idController.text,
          name: _nameController.text,
          eventId: _selectedEventId!,
        );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (result.isSuccess && result.participant != null) {
      _formKey.currentState?.reset();
      _nameController.clear();
      _idController.clear();
      setState(() {
        _latestParticipant = result.participant;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      await _showQrDialog(result.participant!);
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _importCsv() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (pickerResult == null || pickerResult.files.isEmpty) {
        return;
      }

      final file = pickerResult.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw StateError('Unable to read the selected CSV file.');
      }

      final csvText = utf8.decode(bytes);
      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(csvText);
      if (rows.isEmpty) {
        throw StateError('CSV file is empty.');
      }

      final header = rows.first
          .map((value) => value.toString().trim().toLowerCase())
          .toList();
      final nameIndex = header.indexOf('name');
      final idIndex = header.indexOf('id');
      final eventIndex = header.indexWhere(
        (column) =>
            column == 'eventid' || column == 'event' || column == 'eventname',
      );

      if (nameIndex == -1 || idIndex == -1 || eventIndex == -1) {
        throw StateError(
          'CSV must include name, id, and event/eventId columns.',
        );
      }

      final provider = Provider.of<EventProvider>(context, listen: false);
      final participantsToImport = <Participant>[];

      for (final row in rows.skip(1)) {
        if (row.length <= eventIndex ||
            row.length <= idIndex ||
            row.length <= nameIndex) {
          continue;
        }

        final name = row[nameIndex].toString().trim();
        final id = row[idIndex].toString().trim();
        final eventValue = row[eventIndex].toString().trim();
        final event =
            provider.getEventById(eventValue) ??
            provider.getEventByName(eventValue);
        if (name.isEmpty || id.isEmpty || event == null) {
          continue;
        }

        participantsToImport.add(
          Participant(id: id, name: name, eventId: event.id),
        );
      }

      final summary = await provider.importParticipants(participantsToImport);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${summary.imported} participants. Skipped ${summary.skipped}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV import failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Widget _buildLatestQrCard() {
    final participant = _latestParticipant;
    if (participant == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Latest participant QR',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Center(
              child: QrImageView(
                data: participant.id,
                version: QrVersions.auto,
                size: 180,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${participant.name} • ${participant.id}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showQrDialog(participant),
              icon: const Icon(Icons.qr_code),
              label: const Text('Open QR actions'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Participant Registration')),
      body: Consumer<EventProvider>(
        builder: (context, provider, _) {
          final events = provider.events;
          final participants = provider.participants;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
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
                        Text(
                          'Participant Registry',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Register attendees one by one or import a CSV sheet. Each participant automatically gets a unique QR code.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _TopPill(
                              label: 'Participants',
                              value: participants.length.toString(),
                            ),
                            _TopPill(
                              label: 'Events',
                              value: events.length.toString(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Participant Name',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter participant name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _idController,
                              decoration: const InputDecoration(
                                labelText: 'Participant ID',
                                prefixIcon: Icon(Icons.fingerprint),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter participant ID';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedEventId,
                              decoration: const InputDecoration(
                                labelText: 'Event',
                                prefixIcon: Icon(
                                  Icons.event_available_outlined,
                                ),
                              ),
                              items: events
                                  .map(
                                    (event) => DropdownMenuItem(
                                      value: event.id,
                                      child: Text(event.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: events.isEmpty
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedEventId = value;
                                      });
                                    },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Select an event';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _isSaving ? null : _submitParticipant,
                              icon: const Icon(Icons.person_add_alt_1),
                              label: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  _isSaving
                                      ? 'Saving...'
                                      : 'Register Participant',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Bulk Import',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Upload a CSV with columns: name, id, and event/eventId.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _isImporting ? null : _importCsv,
                            icon: const Icon(Icons.upload_file),
                            label: Text(
                              _isImporting ? 'Importing CSV...' : 'Import CSV',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLatestQrCard(),
                  const SizedBox(height: 24),
                  Text(
                    'Registered Participants (${participants.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: participants.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final participant = participants[index];
                      final event = provider.getEventById(participant.eventId);
                      return Card(
                        child: ListTile(
                          title: Text(participant.name),
                          subtitle: Text(
                            'ID: ${participant.id}\nEvent: ${event?.name ?? participant.eventId}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: 'Show QR',
                            onPressed: () => _showQrDialog(participant),
                            icon: const Icon(Icons.qr_code_2),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  final String label;
  final String value;

  const _TopPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white),
          children: [
            TextSpan(
              text: '$value\n',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            TextSpan(
              text: label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
            ),
          ],
        ),
      ),
    );
  }
}
