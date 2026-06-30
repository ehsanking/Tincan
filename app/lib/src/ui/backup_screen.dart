import 'package:flutter/material.dart';
import 'package:tincan_core/tincan_core.dart';

import '../backup/google_drive_backup.dart';
import '../engine/tincan_engine.dart';

/// Backup & restore via Google Drive. The backup is sealed on-device with the
/// user's passphrase before it is uploaded, so Drive only ever holds ciphertext.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.engine});

  final TincanEngine engine;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final GoogleDriveBackup _drive = GoogleDriveBackup();
  final BackupVault _vault = BackupVault();
  final TextEditingController _passphrase = TextEditingController();
  String _status = '';
  bool _busy = false;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    final pass = _passphrase.text;
    if (pass.length < 8) {
      setState(() => _status = 'Use a passphrase of at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _status = '$label…';
    });
    try {
      if (!await _drive.isSignedIn()) {
        final ok = await _drive.signIn();
        if (!ok) {
          setState(() => _status = 'Google sign-in was cancelled.');
          return;
        }
      }
      await action();
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backup() => _run('Backing up', () async {
        final archive = BackupArchive(
          createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
          mnemonic: widget.engine.mnemonic,
          appVersion: '0.1.0',
          contacts: widget.engine.contactsByShortCode.values
              .map((c) => BackupContact(
                    shortCode: c.shortCode,
                    address: c.address,
                    displayName: c.displayName,
                  ))
              .toList(),
        );
        final blob = await _vault.seal(
            plaintext: archive.toBytes(), passphrase: _passphrase.text);
        await _drive.upload(blob);
        setState(() => _status = 'Backed up to Google Drive (encrypted).');
      });

  Future<void> _restore() => _run('Restoring', () async {
        final blob = await _drive.download();
        if (blob == null) {
          setState(() => _status = 'No backup found in Google Drive.');
          return;
        }
        final bytes =
            await _vault.open(blob: blob, passphrase: _passphrase.text);
        final archive = BackupArchive.fromBytes(bytes);
        setState(() => _status =
            'Restored ${archive.contacts.length} contact(s). '
            'Re-open the app with this recovery phrase to use them.');
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const Text(
              'Your backup is encrypted on this device with your passphrase '
              'before it ever reaches Google Drive. Google stores only random '
              'bytes — it cannot read your data. If you lose this passphrase, '
              'the backup cannot be recovered.'),
          const SizedBox(height: 20),
          TextField(
            controller: _passphrase,
            obscureText: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Backup passphrase',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _backup,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Back up'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : _restore,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('Restore'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_busy) const LinearProgressIndicator(),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_status),
            ),
        ],
      ),
    );
  }
}
