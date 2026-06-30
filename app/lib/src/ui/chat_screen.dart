import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/tincan_engine.dart';

/// A single conversation.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.engine, required this.contact});

  final TincanEngine engine;
  final Contact contact;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  StreamSubscription<InboundChat>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.engine.incoming.listen((event) {
      if (event.shortCode == widget.contact.shortCode && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    try {
      await widget.engine.send(widget.contact.shortCode, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Send failed: $e')));
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final messages =
        widget.engine.history[widget.contact.shortCode] ?? <ChatMessage>[];
    return Scaffold(
      appBar: AppBar(title: Text(widget.contact.label)),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                return Align(
                  alignment:
                      m.mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: m.mine
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(m.text),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Message',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
