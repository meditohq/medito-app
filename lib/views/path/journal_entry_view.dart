import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/path_notifier.dart';
import '../../constants/strings/string_constants.dart';

class JournalEntryView extends ConsumerStatefulWidget {
  final String taskId;
  final String initialText;
  final bool isCompleted;

  const JournalEntryView({
    Key? key,
    required this.taskId,
    required this.isCompleted,
    this.initialText = '',
  }) : super(key: key);

  @override
  _JournalEntryViewState createState() => _JournalEntryViewState();
}

class _JournalEntryViewState extends ConsumerState<JournalEntryView> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(StringConstants.journalEntry),
        actions: [
          _isSaving
              ? const Center(child: CircularProgressIndicator())
              : IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveJournalEntry,
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          decoration: InputDecoration(
            hintText: StringConstants.writeYourJournalEntryHere,
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Future<void> _saveJournalEntry() async {
    setState(() {
      _isSaving = true;
    });
    await ref.read(pathNotifierProvider.notifier).updateJournalEntry(
          widget.taskId,
          _controller.text,
          !widget.isCompleted,
        );
    setState(() {
      _isSaving = false;
    });
    Navigator.of(context).pop();
  }
}
