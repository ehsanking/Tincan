import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:tincan_core/tincan_core.dart';
import 'package:tincan_net/tincan_net.dart';

/// A known contact.
class Contact {
  Contact({required this.shortCode, required this.address, this.displayName});

  final String shortCode;
  final String address;
  String? displayName;

  String get label => displayName?.isNotEmpty == true ? displayName! : shortCode;
}

/// A single chat message, from the local user or a peer.
class ChatMessage {
  ChatMessage({required this.text, required this.mine, required this.at});

  final String text;
  final bool mine;
  final DateTime at;
}

/// An inbound message paired with the contact short code it belongs to.
class InboundChat {
  InboundChat(this.shortCode, this.message);
  final String shortCode;
  final ChatMessage message;
}

/// High-level facade that wires the tested `tincan_core` engine to the
/// `tincan_net` peer-to-peer transport for the UI to drive.
///
/// The cryptographic mechanics (identity, X3DH, Double Ratchet, the delivery
/// queue, contact cards) are all implemented and unit-tested in the packages;
/// this class is the thin orchestration layer the app talks to.
class TincanEngine {
  TincanEngine._(
    this.mnemonic,
    this.identity,
    this._account,
    this._transport,
    this._queue,
  );

  final String mnemonic;
  final Identity identity;
  final SignalAccount _account;
  final Libp2pTransport _transport;
  final OutboundQueue _queue;

  final Map<String, Contact> contactsByShortCode = <String, Contact>{};
  final Map<String, List<ChatMessage>> history = <String, List<ChatMessage>>{};

  final Map<String, SecureSession> _sessions = <String, SecureSession>{};
  final Map<String, String> _shortCodeByPeerId = <String, String>{};
  final StreamController<InboundChat> _incoming =
      StreamController<InboundChat>.broadcast();
  StreamSubscription<InboundFrame>? _sub;

  Stream<InboundChat> get incoming => _incoming.stream;
  String get myShortCode => identity.shortCode;
  String get myShortCodeFormatted => ShortCode.format(identity.shortCode);
  String get myAddress => _transport.localAddress.value;

  /// Boots the full stack from a recovery phrase: identity, Signal account,
  /// a libp2p host with a seed-derived (stable) peer id, transport and the
  /// auto-retrying delivery queue.
  static Future<TincanEngine> start(String mnemonic) async {
    final seed = await Bip39.mnemonicToSeed(mnemonic);
    final identity = await Identity.fromSeed(seed);
    final account = await SignalAccount.fromSeed(seed);

    // Domain-separated 32-byte seed for the libp2p identity, so the peer id is
    // stable and controlled by the same recovery phrase.
    final p2pSeed = Uint8List.fromList(crypto.sha256
        .convert(<int>[...utf8.encode('tincan/libp2p/identity/v1'), ...seed])
        .bytes);

    final host = await createTcpHost(identitySeed: p2pSeed);
    final transport = Libp2pTransport(host);
    await transport.start();
    final queue = OutboundQueue(transport)..startAutoRetry();

    final engine =
        TincanEngine._(mnemonic, identity, account, transport, queue);
    engine._listen();
    return engine;
  }

  /// Your shareable contact card (short code + address + a fresh pre-key bundle).
  Future<ContactCard> myCard() async => ContactCard(
        shortCode: identity.shortCode,
        address: myAddress,
        bundle: await _account.createBundle(),
      );

  /// Adds a contact from their scanned/pasted card and opens an outbound session.
  Future<Contact> addContact(String encodedCard, {String? displayName}) async {
    final card = ContactCard.decode(encodedCard);
    final contact = Contact(
      shortCode: card.shortCode,
      address: card.address,
      displayName: displayName,
    );
    contactsByShortCode[card.shortCode] = contact;
    history.putIfAbsent(card.shortCode, () => <ChatMessage>[]);
    _shortCodeByPeerId[_peerIdOf(card.address)] = card.shortCode;

    final session =
        SecureSession(_account.store, SignalProtocolAddress(card.shortCode, 1));
    await session.initiateFromBundle(card.bundle);
    _sessions[card.shortCode] = session;
    return contact;
  }

  /// Encrypts [text] for [shortCode] and enqueues it for delivery.
  Future<void> send(String shortCode, String text) async {
    final contact = contactsByShortCode[shortCode];
    final session = _sessions[shortCode];
    if (contact == null || session == null) {
      throw StateError('Unknown contact: $shortCode');
    }
    final frame = await session.encrypt(utf8.encode(text));
    _queue.enqueue(PeerAddress(contact.address), frame);
    history.putIfAbsent(shortCode, () => <ChatMessage>[]).add(
        ChatMessage(text: text, mine: true, at: DateTime.now()));
  }

  void _listen() {
    _sub = _transport.inbound.listen((frame) async {
      try {
        final peerId = _peerIdOf(frame.from.value);
        final shortCode = _shortCodeByPeerId[peerId] ?? peerId;
        final session = _sessions.putIfAbsent(
          shortCode,
          () => SecureSession(
              _account.store, SignalProtocolAddress(shortCode, 1)),
        );
        final clear = await session.decrypt(frame.bytes);
        final message = ChatMessage(
            text: utf8.decode(clear), mine: false, at: DateTime.now());
        history.putIfAbsent(shortCode, () => <ChatMessage>[]).add(message);
        _incoming.add(InboundChat(shortCode, message));
      } catch (_) {
        // Undecryptable frames (e.g. replays) are ignored.
      }
    });
  }

  String _peerIdOf(String address) {
    final i = address.indexOf('|');
    return i < 0 ? address : address.substring(0, i);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _queue.stop();
    await _transport.close();
    await _incoming.close();
  }
}
