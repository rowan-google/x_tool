import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'crypto_envelope.dart';
import 'crypto_exceptions.dart';

/// Low-level cryptographic engine for x_tool.
/// Implements Argon2id key derivation and XChaCha20-Poly1305 AEAD authenticated encryption.
class CryptoEngine {
  final Random _secureRandom;
  final Cipher _cipher;

  CryptoEngine({
    Random? secureRandom,
    Cipher? cipher,
  })  : _secureRandom = secureRandom ?? Random.secure(),
        _cipher = cipher ?? Xchacha20.poly1305Aead();

  /// Generates cryptographically secure random bytes of given [length].
  Uint8List generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return bytes;
  }

  /// Encrypts raw [plaintextBytes] using the given [password] and KDF parameters.
  Future<CryptoEnvelope> encrypt({
    required Uint8List plaintextBytes,
    required String password,
    int memoryKiB = CryptoEnvelope.defaultMemoryKiB,
    int iterations = CryptoEnvelope.defaultIterations,
    int parallelism = CryptoEnvelope.defaultParallelism,
  }) async {
    if (password.isEmpty) {
      throw const EmptyPasswordException();
    }

    // 1. Generate fresh salt and nonce using CSPRNG
    final salt = generateRandomBytes(CryptoEnvelope.saltLength);
    final nonce = generateRandomBytes(CryptoEnvelope.nonceLength);

    // 2. Build preliminary envelope header to serve as Associated Authenticated Data (AAD)
    final preliminaryEnvelope = CryptoEnvelope(
      version: CryptoEnvelope.currentVersion,
      kdfId: CryptoEnvelope.kdfArgon2id,
      kdfMemoryKiB: memoryKiB,
      kdfIterations: iterations,
      kdfParallelism: parallelism,
      cipherId: CryptoEnvelope.cipherXChaCha20Poly1305,
      salt: salt,
      nonce: nonce,
      ciphertext: Uint8List(0),
      mac: Uint8List(0),
    );
    final aad = preliminaryEnvelope.headerBytes;

    // 3. Derive 256-bit key via Argon2id
    final argon2 = Argon2id(
      parallelism: parallelism,
      memory: memoryKiB,
      iterations: iterations,
      hashLength: 32,
    );

    final secretKey = await argon2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    // 4. Encrypt with XChaCha20-Poly1305 AEAD, binding AAD
    final secretBox = await _cipher.encrypt(
      plaintextBytes,
      secretKey: secretKey,
      nonce: nonce,
      aad: aad,
    );

    return CryptoEnvelope(
      version: CryptoEnvelope.currentVersion,
      kdfId: CryptoEnvelope.kdfArgon2id,
      kdfMemoryKiB: memoryKiB,
      kdfIterations: iterations,
      kdfParallelism: parallelism,
      cipherId: CryptoEnvelope.cipherXChaCha20Poly1305,
      salt: salt,
      nonce: nonce,
      ciphertext: Uint8List.fromList(secretBox.cipherText),
      mac: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  /// Decrypts a [CryptoEnvelope] using the given [password].
  Future<Uint8List> decrypt({
    required CryptoEnvelope envelope,
    required String password,
  }) async {
    if (password.isEmpty) {
      throw const EmptyPasswordException();
    }

    // Security sanity checks on KDF parameters to mitigate resource-exhaustion attacks
    if (envelope.kdfMemoryKiB > 256 * 1024) {
      throw const InvalidEnvelopeException('KDF 内存参数异常过大，拒绝解密');
    }
    if (envelope.kdfIterations > 100) {
      throw const InvalidEnvelopeException('KDF 迭代轮数异常过大，拒绝解密');
    }

    // 1. Reconstruct Associated Authenticated Data (AAD) from envelope header
    final aad = envelope.headerBytes;

    // 2. Derive key using envelope's salt and parameters
    final argon2 = Argon2id(
      parallelism: envelope.kdfParallelism,
      memory: envelope.kdfMemoryKiB,
      iterations: envelope.kdfIterations,
      hashLength: 32,
    );

    final secretKey = await argon2.deriveKeyFromPassword(
      password: password,
      nonce: envelope.salt,
    );

    // 3. Decrypt with XChaCha20-Poly1305
    final secretBox = SecretBox(
      envelope.ciphertext,
      nonce: envelope.nonce,
      mac: Mac(envelope.mac),
    );

    try {
      final decrypted = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
        aad: aad,
      );
      return Uint8List.fromList(decrypted);
    } on SecretBoxAuthenticationError {
      throw const AuthenticationFailedException();
    } catch (e) {
      if (e is CryptoException) rethrow;
      throw DecryptionException('解密失败: ${e.toString()}');
    }
  }
}
