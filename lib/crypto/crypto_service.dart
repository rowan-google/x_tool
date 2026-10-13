import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'crypto_engine.dart';
import 'crypto_envelope.dart';
import 'crypto_exceptions.dart';

/// Parameters for encrypting with [CryptoService].
class CryptoParameters {
  final int memoryKiB;
  final int iterations;
  final int parallelism;

  const CryptoParameters({
    this.memoryKiB = CryptoEnvelope.defaultMemoryKiB,
    this.iterations = CryptoEnvelope.defaultIterations,
    this.parallelism = CryptoEnvelope.defaultParallelism,
  });

  /// Balanced daily profile: 19 MiB memory, 2 iterations. Fast and fluid on all devices (~150ms).
  static const CryptoParameters balanced = CryptoParameters(
    memoryKiB: 19 * 1024,
    iterations: 2,
    parallelism: 1,
  );

  /// Hardened defense profile: 64 MiB memory, 3 iterations (~500ms). RFC 9106 recommended high defense.
  static const CryptoParameters hardened = CryptoParameters(
    memoryKiB: 64 * 1024,
    iterations: 3,
    parallelism: 1,
  );

  /// Paranoid cold storage profile: 128 MiB memory, 4 iterations (~1200ms). Extreme memory-hardness.
  static const CryptoParameters paranoid = CryptoParameters(
    memoryKiB: 128 * 1024,
    iterations: 4,
    parallelism: 1,
  );
}

/// High-level crypto service providing asynchronous encryption and decryption.
/// Automatically executes heavy Argon2id and AEAD computations in background isolates
/// to avoid blocking the Flutter UI thread.
class CryptoService {
  final bool useIsolate;
  final CryptoParameters defaultParameters;

  const CryptoService({
    this.useIsolate = true,
    this.defaultParameters = const CryptoParameters(),
  });

  /// Encrypts UTF-8 [plaintext] using the provided [password].
  /// Returns standard armored ASCII text suitable for copying to clipboard or notes.
  Future<String> encrypt({
    required String plaintext,
    required String password,
    CryptoParameters? parameters,
  }) async {
    final params = parameters ?? defaultParameters;
    if (password.isEmpty) {
      throw const EmptyPasswordException();
    }

    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

    if (useIsolate) {
      return await Isolate.run(() async {
        final engine = CryptoEngine();
        final envelope = await engine.encrypt(
          plaintextBytes: plaintextBytes,
          password: password,
          memoryKiB: params.memoryKiB,
          iterations: params.iterations,
          parallelism: params.parallelism,
        );
        return envelope.serializeArmored();
      });
    } else {
      final engine = CryptoEngine();
      final envelope = await engine.encrypt(
        plaintextBytes: plaintextBytes,
        password: password,
        memoryKiB: params.memoryKiB,
        iterations: params.iterations,
        parallelism: params.parallelism,
      );
      return envelope.serializeArmored();
    }
  }

  /// Decrypts [armoredOrBase64] ciphertext using the provided [password].
  /// Returns the original decrypted UTF-8 plaintext.
  Future<String> decrypt({
    required String armoredOrBase64,
    required String password,
  }) async {
    if (password.isEmpty) {
      throw const EmptyPasswordException();
    }

    // Parse envelope first to fail fast on invalid format before spawning isolate
    final envelope = CryptoEnvelope.deserializeArmored(armoredOrBase64);

    if (useIsolate) {
      return await Isolate.run(() async {
        final engine = CryptoEngine();
        final decryptedBytes = await engine.decrypt(
          envelope: envelope,
          password: password,
        );
        try {
          return utf8.decode(decryptedBytes);
        } on FormatException {
          throw const DecryptionException('解密成功但数据不是有效的 UTF-8 文本');
        }
      });
    } else {
      final engine = CryptoEngine();
      final decryptedBytes = await engine.decrypt(
        envelope: envelope,
        password: password,
      );
      try {
        return utf8.decode(decryptedBytes);
      } on FormatException {
        throw const DecryptionException('解密成功但数据不是有效的 UTF-8 文本');
      }
    }
  }
}
