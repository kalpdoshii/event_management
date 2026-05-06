import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:cross_file/cross_file.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/participant.dart';
import '../providers/event_provider.dart';

enum _LogFilter { all, checkedIn, pending }

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _LogFilter _filter = _LogFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EventProvider>(context, listen: false).loadParticipants();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Participant> _filterAndSort(List<Participant> participants) {
    final query = _query.trim().toLowerCase();
    final filtered = participants.where((participant) {
      final matchesStatus = switch (_filter) {
        _LogFilter.all => true,
        _LogFilter.checkedIn => participant.isCheckedIn,
        _LogFilter.pending => !participant.isCheckedIn,
      };
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;
      return participant.id.toLowerCase().contains(query) ||
          participant.name.toLowerCase().contains(query);
    }).toList();

    filtered.sort((left, right) {
      final leftTime = left.checkInTime;
      final rightTime = right.checkInTime;
      if (leftTime == null && rightTime == null) {
        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      }
      if (leftTime == null) return 1;
      if (rightTime == null) return -1;
      return rightTime.compareTo(leftTime);
    });

    return filtered;
  }

  String _formatEntryTime(DateTime? time) {
    if (time == null) return 'Pending';
    return DateFormat.yMMMd().add_jm().format(time.toLocal());
  }

  Future<void> _exportCsv(EventProvider provider) async {
    final rows = <List<String>>[
      <String>['name', 'id', 'event', 'status', 'checkInTime'],
      ...provider.participants
          .where((participant) => participant.isCheckedIn)
          .map((participant) {
            final event = provider.getEventById(participant.eventId);
            return <String>[
              participant.name,
              participant.id,
              event?.name ?? participant.eventId,
              participant.isCheckedIn ? 'Checked In' : 'Pending',
              participant.checkInTime == null
                  ? ''
                  : DateFormat(
                      'yyyy-MM-dd HH:mm:ss',
                    ).format(participant.checkInTime!.toLocal()),
            ];
          }),
    ];

    final csvText = const ListToCsvConverter().convert(rows);
    await Share.shareXFiles([
      XFile.fromData(
        utf8.encode(csvText),
        name: 'attendance_logs.csv',
        mimeType: 'text/csv',
      ),
    ], subject: 'Attendance Logs CSV');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logs & Search')),
      body: Consumer<EventProvider>(
        builder: (context, provider, _) {
          final participants = _filterAndSort(provider.participants);

          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF16324F), Color(0xFF245D82)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Logs',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Search participant records, review entry times, and export checked-in attendance.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search by ID or name',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.white,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _FilterChip(
                              label: 'All',
                              selected: _filter == _LogFilter.all,
                              onTap: () =>
                                  setState(() => _filter = _LogFilter.all),
                            ),
                            _FilterChip(
                              label: 'Checked In',
                              selected: _filter == _LogFilter.checkedIn,
                              onTap: () => setState(
                                () => _filter = _LogFilter.checkedIn,
                              ),
                            ),
                            _FilterChip(
                              label: 'Pending',
                              selected: _filter == _LogFilter.pending,
                              onTap: () =>
                                  setState(() => _filter = _LogFilter.pending),
                            ),
                            _FilterChip(
                              label: 'Export CSV',
                              selected: false,
                              icon: Icons.file_download_outlined,
                              onTap:
                                  provider.participants
                                      .where(
                                        (participant) =>
                                            participant.isCheckedIn,
                                      )
                                      .isEmpty
                                  ? null
                                  : () => _exportCsv(provider),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: participants.isEmpty
                      ? Center(
                          child: Text(
                            _query.isEmpty
                                ? 'No participants available.'
                                : 'No matching participants found.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: participants.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final participant = participants[index];
                            final checkedIn = participant.isCheckedIn;
                            final badgeColor = checkedIn
                                ? Colors.green
                                : Colors.orange;
                            final badgeLabel = checkedIn
                                ? 'Checked In'
                                : 'Pending';

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: Colors.black.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            participant.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        _StatusBadge(
                                          label: badgeLabel,
                                          color: badgeColor,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.fingerprint,
                                          size: 18,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text('ID: ${participant.id}'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          size: 18,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Entry time: ${_formatEntryTime(participant.checkInTime)}',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 18,
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
            ),
      label: Text(label),
      backgroundColor: selected
          ? Theme.of(context).colorScheme.primary
          : Colors.white,
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Colors.black.withValues(alpha: 0.08),
      ),
      onPressed: () {
        if (onTap != null) {
          onTap!();
        }
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
