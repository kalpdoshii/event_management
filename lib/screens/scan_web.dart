import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/event_provider.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EventProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR (Web)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Camera scanning is not available on web in this app.'),
            const SizedBox(height: 8),
            const Text(
              'You can paste a scanned event id here to simulate a scan.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Scanned payload'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final raw = _controller.text.trim();
                if (raw.isEmpty) return;
                await provider.processScanned(raw);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Processed: $raw')));
                }
              },
              child: const Text('Process'),
            ),
          ],
        ),
      ),
    );
  }
}
