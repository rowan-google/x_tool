/// Base class for all cryptographic and format exceptions in x_tool.
sealed class CryptoException implements Exception {
  final String message;
  const CryptoException(this.message);

  @override
  String toString() => message;
}

/// Thrown when an operation is attempted with an empty password.
class EmptyPasswordException extends CryptoException {
  const EmptyPasswordException([super.message = '密码不能为空']);
}

/// Thrown when the ciphertext data is not a valid x_tool format.
class InvalidEnvelopeException extends CryptoException {
  const InvalidEnvelopeException([super.message = '密文格式无效或损坏']);
}

/// Thrown when the ciphertext format version is not supported by this version of x_tool.
class UnsupportedVersionException extends CryptoException {
  final int version;
  const UnsupportedVersionException(this.version, [String? message])
      : super(message ?? '不支持的密文版本: v$version');
}

/// Thrown when authentication fails (wrong password or ciphertext/metadata tampered).
class AuthenticationFailedException extends CryptoException {
  const AuthenticationFailedException([
    super.message = '密码错误或数据已被篡改',
  ]);
}

/// Thrown when an unexpected error occurs during encryption or decryption.
class DecryptionException extends CryptoException {
  const DecryptionException([super.message = '解密失败']);
}
