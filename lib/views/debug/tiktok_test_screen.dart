import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/string_constants.dart';
import 'package:medito/services/tiktok_events_service.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';

class TikTokTestScreen extends ConsumerStatefulWidget {
  const TikTokTestScreen({super.key});

  @override
  ConsumerState<TikTokTestScreen> createState() => _TikTokTestScreenState();
}

class _TikTokTestScreenState extends ConsumerState<TikTokTestScreen> {
  final _eventNameController = TextEditingController(text: 'TestEvent');
  final _eventKeyController = TextEditingController(text: 'testKey');
  final _eventValueController = TextEditingController(text: 'testValue');
  final _logEntries = <String>[];
  bool _isLoading = false;

  @override
  void dispose() {
    _eventNameController.dispose();
    _eventKeyController.dispose();
    _eventValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TikTok Event Testing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildEventForm(),
            const Divider(height: 32),
            _buildPresetButtons(),
            const Divider(height: 32),
            Expanded(child: _buildLogViewer()),
          ],
        ),
      ),
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildEventForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _eventNameController,
          decoration: const InputDecoration(
            labelText: 'Event Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _eventKeyController,
                decoration: const InputDecoration(
                  labelText: 'Property Key',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _eventValueController,
                decoration: const InputDecoration(
                  labelText: 'Property Value',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendCustomEvent,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Send Custom Event'),
        ),
      ],
    );
  }

  Widget _buildPresetButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : () => _sendPresetEvent('ViewContent'),
          child: const Text('ViewContent'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _sendPresetEvent('Search'),
          child: const Text('Search'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _sendPresetEvent('AddToCart'),
          child: const Text('AddToCart'),
        ),
        ElevatedButton(
          onPressed:
              _isLoading ? null : () => _sendPresetEvent('InitiateCheckout'),
          child: const Text('InitiateCheckout'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _sendPresetEvent('Subscribe'),
          child: const Text('Subscribe'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _sendPresetEvent('Purchase'),
          child: const Text('Purchase'),
        ),
      ],
    );
  }

  Widget _buildLogViewer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Event Logs:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: _logEntries.isEmpty
                ? const Center(child: Text('No events sent yet'))
                : ListView.builder(
                    itemCount: _logEntries.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _logEntries[_logEntries.length - index - 1],
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendCustomEvent() async {
    final eventName = _eventNameController.text.trim();
    final propertyKey = _eventKeyController.text.trim();
    final propertyValue = _eventValueController.text.trim();

    if (eventName.isEmpty) {
      _addLogEntry('Error: Event name cannot be empty');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final customProperties = <String, dynamic>{};
      if (propertyKey.isNotEmpty && propertyValue.isNotEmpty) {
        customProperties[propertyKey] = propertyValue;
      }

      await ref
          .read(tiktokEventsServiceProvider)
          .logEvent(eventName, customProperties: customProperties);

      _addLogEntry(
          '✅ Sent event: $eventName ${customProperties.isNotEmpty ? 'with $customProperties' : ''}');
    } catch (e) {
      _addLogEntry('❌ Error sending event: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendPresetEvent(String eventName) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(tiktokEventsServiceProvider).logEvent(
        eventName,
        customProperties: {
          'timestamp': DateTime.now().toIso8601String(),
          'test': true,
        },
      );

      _addLogEntry('✅ Sent preset event: $eventName');
    } catch (e) {
      _addLogEntry('❌ Error sending event: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addLogEntry(String entry) {
    setState(() {
      _logEntries.add('[${DateTime.now().toString().split('.').first}] $entry');
    });
  }

  void _clearLogs() {
    setState(() {
      _logEntries.clear();
    });
  }
}
