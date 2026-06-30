import 'dart:convert';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

/// A shareable "contact card": everything a peer needs to open an encrypted
/// session with you, with no server and no directory lookup. Exchanged in
/// person via a QR code, or by pasting the encoded string over any channel.
///
/// It carries your short code, your transport address, and a one-time X3DH
/// pre-key bundle. The card is **not secret** — it contains only public keys —
/// but the recipient MUST still verify your identity out of band (compare the
/// short code / safety number) to defeat a machine-in-the-middle.
class ContactCard {
  ContactCard({
    required this.shortCode,
    required this.address,
    required this.bundle,
  });

  /// The owner's 10-digit short code.
  final String shortCode;

  /// The owner's transport address (e.g. a libp2p `peerId|multiaddrs` string).
  final String address;

  /// A fresh X3DH pre-key bundle the recipient uses to start a session.
  final PreKeyBundle bundle;

  static const int _version = 1;

  /// Encodes the card to a compact, URL-safe string (base64url of JSON).
  String encode() {
    final json = <String, dynamic>{
      'v': _version,
      'sc': shortCode,
      'addr': address,
      'reg': bundle.getRegistrationId(),
      'dev': bundle.getDeviceId(),
      'pkId': bundle.getPreKeyId(),
      'pk': base64.encode(bundle.getPreKey()!.serialize()),
      'spkId': bundle.getSignedPreKeyId(),
      'spk': base64.encode(bundle.getSignedPreKey()!.serialize()),
      'sig': base64.encode(bundle.getSignedPreKeySignature()!),
      'ik': base64.encode(bundle.getIdentityKey().serialize()),
    };
    return base64Url.encode(utf8.encode(jsonEncode(json)));
  }

  /// Parses a card produced by [encode]. Throws [FormatException] on a malformed
  /// or unsupported card.
  static ContactCard decode(String encoded) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(base64Url.decode(encoded)))
          as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Malformed contact card: $e');
    }
    if (json['v'] != _version) {
      throw FormatException('Unsupported contact card version: ${json['v']}');
    }
    final bundle = PreKeyBundle(
      json['reg'] as int,
      json['dev'] as int,
      json['pkId'] as int,
      Curve.decodePoint(base64.decode(json['pk'] as String), 0),
      json['spkId'] as int,
      Curve.decodePoint(base64.decode(json['spk'] as String), 0),
      base64.decode(json['sig'] as String),
      IdentityKey.fromBytes(base64.decode(json['ik'] as String), 0),
    );
    return ContactCard(
      shortCode: json['sc'] as String,
      address: json['addr'] as String,
      bundle: bundle,
    );
  }
}
