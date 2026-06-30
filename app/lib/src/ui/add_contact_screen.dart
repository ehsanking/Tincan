import 'package:flutter/material.dart';

import '../engine/tincan_engine.dart';

/// Adds a contact from their card text. (On mobile a QR scanner can be wired in
/// here; pasting the card works on every platform, including Windows desktop.)
class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key, required this.engine});

  final TincanEngine engine;

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final TextEditingController _card = TextEditingController();
  final TextEditingController _name = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _card.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.engine.addContact(
        _card.text.trim(),
        displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not add contact: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add contact')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const Text(
              'Paste your contact\'s card text (or scan their QR). Then verify '
              'their short code with them over a trusted channel before you '
              'trust the conversation.'),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Name (optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _card,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Contact card text',
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          FilledButton(
            onPressed: _busy ? null : _add,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Add'),
          ),
        ],
      ),
    );
  }
}
