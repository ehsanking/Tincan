# Tincan app (Flutter)

The Tincan client for **Android and Windows**. It wires the tested engine
(`tincan_core`) and peer-to-peer transport (`tincan_net`) to a UI for creating
an identity, exchanging contact cards, chatting, and backing up to Google Drive.

> **Status: early scaffold.** This directory is written but has **not been
> compiled here** (the build environment has no Flutter SDK). The packages it
> depends on are fully tested; this app layer needs to be built and run on a
> machine with Flutter and the platform toolchains, and is the best place for
> contributors to jump in.

## What's here

```
lib/
  main.dart                       app entry
  src/app.dart                    MaterialApp + theme
  src/engine/tincan_engine.dart   facade over tincan_core + tincan_net
  src/backup/google_drive_backup.dart   client-side-encrypted Drive backup
  src/ui/
    onboarding_screen.dart        create / restore a recovery phrase
    home_screen.dart              contacts + your QR card
    add_contact_screen.dart       add by pasted/scanned card
    chat_screen.dart              a conversation
    backup_screen.dart           Google Drive backup & restore
```

## Build & run

You need Flutter (3.24+) with the Android and/or Windows toolchains.

```bash
cd app

# Generate the platform runner folders the first time (android/, windows/, …).
flutter create . --platforms=android,windows

flutter pub get
flutter run -d windows      # or: flutter run -d android
```

`flutter create .` is needed because this repo checks in only the Dart source,
not the generated platform projects.

## Google Drive backup setup

The backup feature uploads an **already-encrypted** blob to the app's private
`appDataFolder` in the user's Drive (scope `drive.appdata`). To enable sign-in
you must register OAuth clients in a Google Cloud project:

1. Create a project at <https://console.cloud.google.com/> and enable the
   **Google Drive API**.
2. Configure the OAuth consent screen.
3. Create OAuth client IDs for each platform you target (Android needs your
   signing SHA-1; desktop uses a different flow).
4. Follow the
   [`google_sign_in`](https://pub.dev/packages/google_sign_in) platform setup
   for Android, and a desktop OAuth flow for Windows.

No secrets belong in this repo — wire your client IDs through the platform
configs / environment, not source control.

## How the pieces connect

```
OnboardingScreen ──TincanEngine.start(mnemonic)──► identity + Signal account
                                                  + libp2p host (seed-derived id)
                                                  + Libp2pTransport + OutboundQueue
HomeScreen ──myCard()──► ContactCard (QR / text)
AddContactScreen ──addContact(cardText)──► SecureSession (X3DH)
ChatScreen ──send()──► Double Ratchet encrypt → OutboundQueue → peer
BackupScreen ──► BackupArchive → BackupVault.seal(passphrase) → Google Drive
```

The security-critical work all happens in the packages and is unit-tested
there; this app is orchestration and UI.

## Known gaps (good first contributions)

- QR **scanning** (display already works via `qr_flutter`) — wire a scanner on
  mobile.
- Persisting messages/contacts to the encrypted store (drift + SQLCipher)
  instead of in memory.
- Desktop Google OAuth flow for Windows.
- Background delivery within Android's execution limits.
