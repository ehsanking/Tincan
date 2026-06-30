import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Stores a Tincan backup in the user's Google Drive — in the hidden,
/// app-private `appDataFolder`.
///
/// IMPORTANT: the bytes handed to [upload] are already sealed by
/// `BackupVault` (Argon2id + XChaCha20-Poly1305). Google therefore only ever
/// stores ciphertext; it cannot read, index, or hand over the backup's
/// contents. The user's passphrase never leaves the device.
class GoogleDriveBackup {
  GoogleDriveBackup({GoogleSignIn? signIn})
      : _signIn = signIn ??
            GoogleSignIn(
                scopes: const <String>[drive.DriveApi.driveAppdataScope]);

  final GoogleSignIn _signIn;
  static const String _fileName = 'tincan-backup.tcb';

  Future<bool> signIn() async => (await _signIn.signIn()) != null;
  Future<void> signOut() => _signIn.signOut();
  Future<bool> isSignedIn() => _signIn.isSignedIn();

  Future<drive.DriveApi> _api() async {
    final client = await _signIn.authenticatedClient();
    if (client == null) {
      throw StateError('Not signed in to Google Drive');
    }
    return drive.DriveApi(client);
  }

  /// Uploads or replaces the encrypted backup blob.
  Future<void> upload(Uint8List sealedBlob) async {
    final api = await _api();
    final existing = await _find(api);
    final media =
        drive.Media(Stream<List<int>>.value(sealedBlob), sealedBlob.length);

    if (existing == null) {
      final metadata = drive.File()
        ..name = _fileName
        ..parents = <String>['appDataFolder'];
      await api.files.create(metadata, uploadMedia: media);
    } else {
      await api.files.update(drive.File(), existing.id!, uploadMedia: media);
    }
  }

  /// Downloads the latest encrypted backup blob, or null if none exists.
  Future<Uint8List?> download() async {
    final api = await _api();
    final existing = await _find(api);
    if (existing == null) return null;

    final media = await api.files.get(
      existing.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return Uint8List.fromList(bytes);
  }

  Future<drive.File?> _find(drive.DriveApi api) async {
    final result = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_fileName'",
      $fields: 'files(id,name,modifiedTime)',
    );
    final files = result.files;
    if (files == null || files.isEmpty) return null;
    return files.first;
  }
}
