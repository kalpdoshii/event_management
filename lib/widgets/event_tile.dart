import 'package:flutter/material.dart';
import '../models/event.dart';

class EventTile extends StatelessWidget {
  final Event event;
  const EventTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(event.name),
      subtitle: event.checkedIn && event.checkedInAt != null
          ? Text('Checked in at ${event.checkedInAt}')
          : null,
      trailing: Icon(
        event.checkedIn ? Icons.check_circle : Icons.radio_button_unchecked,
        color: event.checkedIn ? Colors.green : null,
      ),
    );
  }
}
