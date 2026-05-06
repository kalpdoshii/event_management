import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/event_provider.dart';
import 'scan_screen.dart';

class EventSetupScreen extends StatefulWidget {
  const EventSetupScreen({super.key});

  @override
  State<EventSetupScreen> createState() => _EventSetupScreenState();
}

class _EventSetupScreenState extends State<EventSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController();
  DateTime? _selectedDateTime;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _selectedDateTime ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? now),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date and time.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await Provider.of<EventProvider>(context, listen: false).createEvent(
        name: _nameController.text.trim(),
        dateTime: _selectedDateTime!,
        maxCapacity: int.parse(_capacityController.text.trim()),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created successfully.')),
      );

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const ScanScreen()));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _formatSelectedDateTime() {
    final value = _selectedDateTime;
    if (value == null) return 'Select date and time';
    return MaterialLocalizations.of(context).formatFullDate(value) +
        ' • ' +
        MaterialLocalizations.of(
          context,
        ).formatTimeOfDay(TimeOfDay.fromDateTime(value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Event Name',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter an event name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDateTime,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date & Time',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_formatSelectedDateTime()),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _capacityController,
                  decoration: const InputDecoration(
                    labelText: 'Max Capacity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter max capacity';
                    }
                    final capacity = int.tryParse(value.trim());
                    if (capacity == null || capacity <= 0) {
                      return 'Enter a valid number greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(_isSubmitting ? 'Saving...' : 'Create Event'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
