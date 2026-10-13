import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:x_tool/crypto/crypto_envelope.dart';
import 'package:x_tool/crypto/crypto_exceptions.dart';
import 'package:x_tool/crypto/crypto_service.dart';

void main() {
  group('CryptoEnvelope Tests', () {
    test('Envelope serialization and deserialization round-trip', () {
      final envelope = CryptoEnvelope(
        version: CryptoEnvelope.currentVersion,
        kdfId: CryptoEnvelope.kdfArgon2id,
        kdfMemoryKiB: 19456,
        kdfIterations: 2,
        kdfParallelism: 1,
        cipherId: CryptoEnvelope.cipherXChaCha20Poly1305,
        salt: Uint8List.fromList(List.generate(16, (i) => i)),
        nonce: Uint8List.fromList(List.generate(24, (i) => i + 10)),
        ciphertext: Uint8List.fromList(utf8.encode('EncryptedPayload123')),
        mac: Uint8List.fromList(List.generate(16, (i) => i + 50)),
      );

      final binary = envelope.serializeBinary();
      final recovered = CryptoEnvelope.deserializeBinary(binary);

      expect(recovered.version, envelope.version);
      expect(recovered.kdfId, envelope.kdfId);
      expect(recovered.kdfMemoryKiB, envelope.kdfMemoryKiB);
      expect(recovered.kdfIterations, envelope.kdfIterations);
      expect(recovered.kdfParallelism, envelope.kdfParallelism);
      expect(recovered.cipherId, envelope.cipherId);
      expect(recovered.salt, envelope.salt);
      expect(recovered.nonce, envelope.nonce);
      expect(recovered.ciphertext, envelope.ciphertext);
      expect(recovered.mac, envelope.mac);

      final armored = envelope.serializeArmored();
      expect(CryptoEnvelope.isArmoredText(armored), isTrue);

      final recoveredArmored = CryptoEnvelope.deserializeArmored(armored);
      expect(recoveredArmored.salt, envelope.salt);
      expect(recoveredArmored.ciphertext, envelope.ciphertext);
      expect(recoveredArmored.mac, envelope.mac);
    });

    test('Deserialize markdown code-block wrapped armored text', () {
      final envelope = CryptoEnvelope(
        version: CryptoEnvelope.currentVersion,
        kdfId: CryptoEnvelope.kdfArgon2id,
        kdfMemoryKiB: 19456,
        kdfIterations: 2,
        kdfParallelism: 1,
        cipherId: CryptoEnvelope.cipherXChaCha20Poly1305,
        salt: Uint8List.fromList(List.generate(16, (i) => i)),
        nonce: Uint8List.fromList(List.generate(24, (i) => i)),
        ciphertext: Uint8List.fromList(utf8.encode('test')),
        mac: Uint8List.fromList(List.generate(16, (i) => i)),
      );
      final armored = envelope.serializeArmored();
      final markdownWrapped = '```text\n$armored\n```';

      final recovered = CryptoEnvelope.deserializeArmored(markdownWrapped);
      expect(recovered.ciphertext, envelope.ciphertext);
    });

    test('Invalid format rejects garbage', () {
      expect(
        () => CryptoEnvelope.deserializeArmored('invalid-not-base64-!@#\$%^&*()'),
        throwsA(isA<InvalidEnvelopeException>()),
      );

      expect(
        () => CryptoEnvelope.deserializeBinary(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<InvalidEnvelopeException>()),
      );
    });
  });

  group('CryptoEngine & CryptoService Tests', () {
    final service = CryptoService(useIsolate: false); // Direct for deterministic test runner

    test('Encrypt and decrypt plain ASCII text', () async {
      const plaintext = 'Hello, this is a secret note in Obsidian!';
      const password = 'MySuperSecretPassword#2026';

      final armored = await service.encrypt(
        plaintext: plaintext,
        password: password,
      );

      final decrypted = await service.decrypt(
        armoredOrBase64: armored,
        password: password,
      );

      expect(decrypted, plaintext);
    });

    test('Encrypt and decrypt Unicode, CJK, Emoji, and multiline text', () async {
      const complexText = '''
# 个人机密备忘录 🛡️
这是第一行内容：中文汉字、ひらがな、カタカナ、한국어。
Special chars: <>&"'\t\r\n\\/
Mathematical symbols: ∀x ∈ ℝ, x² ≥ 0
Emoji test: 🔐🎉✨🚀👨‍💻
End of message.
''';
      const password = '密码🔑Password_123';

      final armored = await service.encrypt(
        plaintext: complexText,
        password: password,
      );

      final decrypted = await service.decrypt(
        armoredOrBase64: armored,
        password: password,
      );

      expect(decrypted, complexText);
    });

    test('Encrypt and decrypt empty text', () async {
      const emptyText = '';
      const password = 'AnyPassword123';

      final armored = await service.encrypt(
        plaintext: emptyText,
        password: password,
      );

      final decrypted = await service.decrypt(
        armoredOrBase64: armored,
        password: password,
      );

      expect(decrypted, emptyText);
    });

    test('Reject empty password', () async {
      expect(
        () => service.encrypt(plaintext: 'hello', password: ''),
        throwsA(isA<EmptyPasswordException>()),
      );

      expect(
        () => service.decrypt(armoredOrBase64: 'some_text', password: ''),
        throwsA(isA<EmptyPasswordException>()),
      );
    });

    test('Fresh salt and nonce on every encryption (Indistinguishability)', () async {
      const text = 'Identical plaintext message';
      const password = 'IdenticalPassword123';

      final c1 = await service.encrypt(plaintext: text, password: password);
      final c2 = await service.encrypt(plaintext: text, password: password);

      expect(c1, isNot(equals(c2)));

      final env1 = CryptoEnvelope.deserializeArmored(c1);
      final env2 = CryptoEnvelope.deserializeArmored(c2);

      expect(env1.salt, isNot(equals(env2.salt)));
      expect(env1.nonce, isNot(equals(env2.nonce)));
      expect(env1.ciphertext, isNot(equals(env2.ciphertext)));
    });

    test('Wrong password fails authentication with AuthenticationFailedException', () async {
      const plaintext = 'Secret data';
      const correctPass = 'CorrectPassword123';
      const wrongPass = 'WrongPassword456';

      final armored = await service.encrypt(
        plaintext: plaintext,
        password: correctPass,
      );

      expect(
        () => service.decrypt(armoredOrBase64: armored, password: wrongPass),
        throwsA(isA<AuthenticationFailedException>()),
      );
    });

    test('Tampering ciphertext fails authentication', () async {
      const plaintext = 'Sensitive financial records';
      const password = 'StrongPassword987';

      final armored = await service.encrypt(
        plaintext: plaintext,
        password: password,
      );

      final env = CryptoEnvelope.deserializeArmored(armored);
      final tamperedCiphertext = Uint8List.fromList(env.ciphertext);
      tamperedCiphertext[0] ^= 0x01; // flip 1 bit

      final tamperedEnv = CryptoEnvelope(
        version: env.version,
        kdfId: env.kdfId,
        kdfMemoryKiB: env.kdfMemoryKiB,
        kdfIterations: env.kdfIterations,
        kdfParallelism: env.kdfParallelism,
        cipherId: env.cipherId,
        salt: env.salt,
        nonce: env.nonce,
        ciphertext: tamperedCiphertext,
        mac: env.mac,
      );

      expect(
        () => service.decrypt(
          armoredOrBase64: tamperedEnv.serializeArmored(),
          password: password,
        ),
        throwsA(isA<AuthenticationFailedException>()),
      );
    });

    test('Tampering header (AAD) fails authentication', () async {
      const plaintext = 'Protected header test';
      const password = 'PasswordSecure';

      final armored = await service.encrypt(
        plaintext: plaintext,
        password: password,
      );

      final env = CryptoEnvelope.deserializeArmored(armored);
      // Tamper iterations in header
      final tamperedEnv = CryptoEnvelope(
        version: env.version,
        kdfId: env.kdfId,
        kdfMemoryKiB: env.kdfMemoryKiB,
        kdfIterations: env.kdfIterations + 1, // tampered!
        kdfParallelism: env.kdfParallelism,
        cipherId: env.cipherId,
        salt: env.salt,
        nonce: env.nonce,
        ciphertext: env.ciphertext,
        mac: env.mac,
      );

      expect(
        () => service.decrypt(
          armoredOrBase64: tamperedEnv.serializeArmored(),
          password: password,
        ),
        throwsA(isA<AuthenticationFailedException>()),
      );
    });

    test('Tampering MAC tag fails authentication', () async {
      const plaintext = 'Protected MAC test';
      const password = 'PasswordSecure';

      final armored = await service.encrypt(
        plaintext: plaintext,
        password: password,
      );

      final env = CryptoEnvelope.deserializeArmored(armored);
      final tamperedMac = Uint8List.fromList(env.mac);
      tamperedMac[0] ^= 0x01; // flip 1 bit

      final tamperedEnv = CryptoEnvelope(
        version: env.version,
        kdfId: env.kdfId,
        kdfMemoryKiB: env.kdfMemoryKiB,
        kdfIterations: env.kdfIterations,
        kdfParallelism: env.kdfParallelism,
        cipherId: env.cipherId,
        salt: env.salt,
        nonce: env.nonce,
        ciphertext: env.ciphertext,
        mac: tamperedMac,
      );

      expect(
        () => service.decrypt(
          armoredOrBase64: tamperedEnv.serializeArmored(),
          password: password,
        ),
        throwsA(isA<AuthenticationFailedException>()),
      );
    });

    test('Isolate execution roundtrip with CryptoService(useIsolate: true)', () async {
      final isolateService = const CryptoService(useIsolate: true);
      const plaintext = 'Testing Isolate execution thread';
      const password = 'IsolatePassword123';

      final armored = await isolateService.encrypt(
        plaintext: plaintext,
        password: password,
      );

      final decrypted = await isolateService.decrypt(
        armoredOrBase64: armored,
        password: password,
      );

      expect(decrypted, plaintext);
    });
  });
}
