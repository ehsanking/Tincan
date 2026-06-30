import 'dart:convert';

import 'package:tincan_core/tincan_core.dart';
import 'package:test/test.dart';

const _aliceMnemonic = 'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';
const _bobMnemonic = 'legal winner thank year wave sausage worth useful '
    'legal winner thank yellow';

void main() {
  test('a card round-trips and bootstraps a real working session', () async {
    // Bob publishes a contact card.
    final bobAccount =
        await SignalAccount.fromSeed(await Bip39.mnemonicToSeed(_bobMnemonic));
    final bobIdentity = await Identity.fromMnemonic(_bobMnemonic);

    final bobCard = ContactCard(
      shortCode: bobIdentity.shortCode,
      address: 'bobPeerId|/ip4/127.0.0.1/tcp/4001',
      bundle: await bobAccount.createBundle(),
    );

    // The card travels as a string (QR / paste) and is parsed by Alice.
    final encoded = bobCard.encode();
    final decoded = ContactCard.decode(encoded);

    expect(decoded.shortCode, bobIdentity.shortCode);
    expect(decoded.address, 'bobPeerId|/ip4/127.0.0.1/tcp/4001');

    // Alice uses the decoded bundle to start a session and message Bob.
    final aliceAccount = await SignalAccount.fromSeed(
        await Bip39.mnemonicToSeed(_aliceMnemonic));
    final aliceToBob = SecureSession(
        aliceAccount.store, const SignalProtocolAddress('bob', 1));
    await aliceToBob.initiateFromBundle(decoded.bundle);

    final bobFromAlice = SecureSession(
        bobAccount.store, const SignalProtocolAddress('alice', 1));

    final frame = await aliceToBob.encrypt(utf8.encode('contact card works'));
    expect(
        utf8.decode(await bobFromAlice.decrypt(frame)), 'contact card works');
  });

  test('rejects a malformed card', () {
    expect(() => ContactCard.decode('not-a-valid-card'),
        throwsA(isA<FormatException>()));
  });
}
