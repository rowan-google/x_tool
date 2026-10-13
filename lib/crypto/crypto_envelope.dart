import 'dart:convert';
import 'dart:typed_data';
import 'crypto_exceptions.dart';

/// Representation of an x_tool cryptographic envelope.
///
/// Binary layout:
/// - Offset 0..3   (4 bytes) : Magic bytes 'XTOL' (0x58, 0x54, 0x4F, 0x4C)
/// - Offset 4      (1 byte)  : Format version (currently 1)
/// - Offset 5      (1 byte)  : KDF ID (1 = Argon2id)
/// - Offset 6..9   (4 bytes) : KDF Memory in KiB (uint32 big-endian)
/// - Offset 10..11 (2 bytes) : KDF Iterations (uint16 big-endian)
/// - Offset 12     (1 byte)  : KDF Parallelism (uint8)
/// - Offset 13     (1 byte)  : Cipher ID (1 = XChaCha20-Poly1305)
/// - Offset 14     (1 byte)  : Salt length (16)
/// - Offset 15..30 (16 bytes): Salt
/// - Offset 31     (1 byte)  : Nonce length (24)
/// - Offset 32..55 (24 bytes): Nonce
///
/// Followed by:
/// - Offset 56..end-16 : Ciphertext (N bytes)
/// - Offset end-16..end: Poly1305 MAC tag (16 bytes)
///
/// The entire 56-byte header is used as Associated Authenticated Data (AAD).
class CryptoEnvelope {
  static const List<int> magicBytes = [0x58, 0x54, 0x4F, 0x4C]; // 'XTOL'
  static const int currentVersion = 1;
  static const int kdfArgon2id = 1;
  static const int cipherXChaCha20Poly1305 = 1;
  static const int defaultMemoryKiB = 19 * 1024; // 19 MiB
  static const int defaultIterations = 2;
  static const int defaultParallelism = 1;
  static const int saltLength = 16;
  static const int nonceLength = 24;
  static const int macLength = 16;
  static const int headerLength = 4 + 1 + 1 + 4 + 2 + 1 + 1 + 1 + saltLength + 1 + nonceLength; // 56 bytes

  static const String armorHeader = '-----BEGIN XTOOL ENCRYPTED MESSAGE-----';
  static const String armorFooter = '-----END XTOOL ENCRYPTED MESSAGE-----';

  final int version;
  final int kdfId;
  final int kdfMemoryKiB;
  final int kdfIterations;
  final int kdfParallelism;
  final int cipherId;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List mac;

  const CryptoEnvelope({
    required this.version,
    required this.kdfId,
    required this.kdfMemoryKiB,
    required this.kdfIterations,
    required this.kdfParallelism,
    required this.cipherId,
    required this.salt,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  /// Extracts the exact Associated Data (AAD) bytes corresponding to the header.
  Uint8List get headerBytes {
    final buffer = ByteData(headerLength);
    // Magic
    for (var i = 0; i < 4; i++) {
      buffer.setUint8(i, magicBytes[i]);
    }
    // Version
    buffer.setUint8(4, version);
    // KDF ID
    buffer.setUint8(5, kdfId);
    // KDF Memory
    buffer.setUint32(6, kdfMemoryKiB, Endian.big);
    // KDF Iterations
    buffer.setUint16(10, kdfIterations, Endian.big);
    // KDF Parallelism
    buffer.setUint8(12, kdfParallelism);
    // Cipher ID
    buffer.setUint8(13, cipherId);
    // Salt length & Salt
    buffer.setUint8(14, salt.length);
    var offset = 15;
    for (var i = 0; i < salt.length; i++) {
      buffer.setUint8(offset++, salt[i]);
    }
    // Nonce length & Nonce
    buffer.setUint8(offset++, nonce.length);
    for (var i = 0; i < nonce.length; i++) {
      buffer.setUint8(offset++, nonce[i]);
    }

    return buffer.buffer.asUint8List();
  }

  /// Serializes the envelope into binary bytes.
  Uint8List serializeBinary() {
    final header = headerBytes;
    final totalLength = header.length + ciphertext.length + mac.length;
    final result = Uint8List(totalLength);
    result.setRange(0, header.length, header);
    result.setRange(header.length, header.length + ciphertext.length, ciphertext);
    result.setRange(header.length + ciphertext.length, totalLength, mac);
    return result;
  }

  /// Serializes the envelope into armored ASCII text format.
  String serializeArmored({int lineWrap = 64}) {
    final binary = serializeBinary();
    final base64String = base64Encode(binary);
    final buffer = StringBuffer();
    buffer.writeln(armorHeader);

    if (lineWrap > 0) {
      for (var i = 0; i < base64String.length; i += lineWrap) {
        final end = (i + lineWrap < base64String.length) ? i + lineWrap : base64String.length;
        buffer.writeln(base64String.substring(i, end));
      }
    } else {
      buffer.writeln(base64String);
    }

    buffer.write(armorFooter);
    return buffer.toString();
  }

  /// Deserializes binary bytes into a [CryptoEnvelope].
  static CryptoEnvelope deserializeBinary(Uint8List bytes) {
    if (bytes.length < headerLength + macLength) {
      throw const InvalidEnvelopeException('数据长度过短，无法解析密文信封');
    }

    // Verify magic bytes
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != magicBytes[i]) {
        throw const InvalidEnvelopeException('无效的魔数标识，非 x_tool 加密数据');
      }
    }

    final byteData = ByteData.sublistView(bytes);
    final version = byteData.getUint8(4);
    if (version != currentVersion) {
      throw UnsupportedVersionException(version);
    }

    final kdfId = byteData.getUint8(5);
    if (kdfId != kdfArgon2id) {
      throw InvalidEnvelopeException('不支持的密钥派生算法: $kdfId');
    }

    final kdfMemoryKiB = byteData.getUint32(6, Endian.big);
    final kdfIterations = byteData.getUint16(10, Endian.big);
    final kdfParallelism = byteData.getUint8(12);
    final cipherId = byteData.getUint8(13);
    if (cipherId != cipherXChaCha20Poly1305) {
      throw InvalidEnvelopeException('不支持的加密算法: $cipherId');
    }

    final saltLen = byteData.getUint8(14);
    if (saltLen != saltLength) {
      throw InvalidEnvelopeException('无效的盐长度: $saltLen');
    }

    final salt = bytes.sublist(15, 15 + saltLen);
    var offset = 15 + saltLen;

    final nonceLen = byteData.getUint8(offset++);
    if (nonceLen != nonceLength) {
      throw InvalidEnvelopeException('无效的 Nonce 长度: $nonceLen');
    }

    final nonce = bytes.sublist(offset, offset + nonceLen);
    offset += nonceLen;

    if (offset != headerLength) {
      throw const InvalidEnvelopeException('头部长度解析异常');
    }

    final ciphertextLength = bytes.length - headerLength - macLength;
    if (ciphertextLength < 0) {
      throw const InvalidEnvelopeException('密文长度异常');
    }

    final ciphertext = bytes.sublist(headerLength, headerLength + ciphertextLength);
    final mac = bytes.sublist(headerLength + ciphertextLength, bytes.length);

    return CryptoEnvelope(
      version: version,
      kdfId: kdfId,
      kdfMemoryKiB: kdfMemoryKiB,
      kdfIterations: kdfIterations,
      kdfParallelism: kdfParallelism,
      cipherId: cipherId,
      salt: salt,
      nonce: nonce,
      ciphertext: ciphertext,
      mac: mac,
    );
  }

  /// Deserializes armored text or raw Base64 string into a [CryptoEnvelope].
  static CryptoEnvelope deserializeArmored(String input) {
    var raw = input.trim();
    if (raw.isEmpty) {
      throw const InvalidEnvelopeException('输入内容为空');
    }

    // Strip markdown code fences if present (e.g. ``` ... ```)
    if (raw.startsWith('```') && raw.endsWith('```')) {
      final lines = raw.split('\n');
      if (lines.length >= 2) {
        raw = lines.sublist(1, lines.length - 1).join('\n').trim();
      }
    }

    // Check for armor headers
    final startIndex = raw.indexOf(armorHeader);
    final endIndex = raw.indexOf(armorFooter);

    String base64Body;
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      base64Body = raw.substring(startIndex + armorHeader.length, endIndex);
    } else {
      // Allow raw Base64 directly
      base64Body = raw;
    }

    // Remove all whitespace and linebreaks
    base64Body = base64Body.replaceAll(RegExp(r'\s+'), '');

    Uint8List binary;
    try {
      binary = base64Decode(base64Body);
    } catch (_) {
      throw const InvalidEnvelopeException('Base64 解码失败，内容可能损坏或不完整');
    }

    return deserializeBinary(binary);
  }

  /// Checks whether a given string appears to contain an x_tool armored block.
  static bool isArmoredText(String text) {
    return text.contains(armorHeader) && text.contains(armorFooter);
  }
}
