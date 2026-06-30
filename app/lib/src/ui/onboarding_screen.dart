import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tincan_core/tincan_core.dart';

import '../engine/tincan_engine.dart';
import 'home_screen.dart';

/// First-run screen: create a new identity (generate a recovery phrase) or
/// restore an existing one.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _restoreController = TextEditingController();
  String? _generated;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _restoreController.dispose();
    super.dispose();
  }

  Future<void> _boot(String mnemonic) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final engine = await TincanEngine.start(mnemonic);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => HomeScreen(engine: engine),
      ));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tincan')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const Text(
              'Two tin cans and a string — secured by modern cryptography.\n'
              'No servers. No accounts. No one in the middle.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ),
            // --- Create new identity ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Create a new identity',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                        'Your identity is a 12-word recovery phrase. Write it '
                        'down and keep it safe — it is the ONLY way to restore '
                        'your account. There is no server to reset it.'),
                    const SizedBox(height: 12),
                    if (_generated == null)
                      FilledButton(
                        onPressed: () =>
                            setState(() => _generated = Bip39.generate()),
                        child: const Text('Generate recovery phrase'),
                      )
                    else ...<Widget>[
                      SelectableText(
                        _generated!,
                        style: const TextStyle(
                            fontFamily: 'monospace', height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          TextButton.icon(
                            onPressed: () => Clipboard.setData(
                                ClipboardData(text: _generated!)),
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => _boot(_generated!),
                            child: const Text('I saved it — continue'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // --- Restore existing identity ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Restore an identity',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _restoreController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter your 12-word recovery phrase',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () {
                        final phrase = _restoreController.text.trim();
                        if (!Bip39.validate(phrase)) {
                          setState(() => _error =
                              'That is not a valid recovery phrase.');
                          return;
                        }
                        _boot(phrase);
                      },
                      child: const Text('Restore'),
                    ),
                  ],
                ),
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
