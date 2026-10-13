import 'dart:math';

/// Secure CSPRNG password and passphrase generator for x_tool.
class PasswordGenerator {
  static final Random _secureRandom = Random.secure();

  static const String _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const String _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _digits = '0123456789';
  static const String _symbols = '!@#\$%^&*()-_=+[]{}<>?';

  static const List<String> _dicewareWords = [
    'alpha', 'anchor', 'anthem', 'apollo', 'arctic', 'arrow', 'artist', 'aspect',
    'beacon', 'breeze', 'bridge', 'bronze', 'canyon', 'castle', 'cedar', 'cipher',
    'clarity', 'cloud', 'comet', 'coral', 'crystal', 'delta', 'domain', 'dragon',
    'eagle', 'echo', 'ember', 'energy', 'falcon', 'feather', 'flame', 'forest',
    'galaxy', 'glacier', 'golden', 'granite', 'harbor', 'haven', 'hawk', 'horizon',
    'island', 'jaguar', 'javelin', 'journey', 'jungle', 'knight', 'lagoon', 'legend',
    'liberty', 'lotus', 'lunar', 'magnet', 'marble', 'matrix', 'meadow', 'meteor',
    'mirage', 'monarch', 'nebula', 'nexus', 'noble', 'oasis', 'ocean', 'olive',
    'orbit', 'orchid', 'origin', 'ozone', 'pacific', 'palace', 'panther', 'phoenix',
    'pillar', 'planet', 'portal', 'prism', 'pulsar', 'pyramid', 'quantum', 'quartz',
    'radiant', 'rainbow', 'raven', 'reef', 'river', 'rocket', 'safari', 'sapphire',
    'shadow', 'shield', 'sierra', 'silver', 'solar', 'spark', 'sphinx', 'spirit',
    'summit', 'temple', 'thunder', 'timber', 'titan', 'topaz', 'torrent', 'tower',
    'tundra', 'valiant', 'valley', 'vector', 'velvet', 'vessel', 'vortex', 'voyage',
    'walnut', 'warrior', 'willow', 'winter', 'zenith', 'zephyr', 'zodiac', 'acorn',
    'blaze', 'boulder', 'canopy', 'cliff', 'crater', 'dune', 'flint', 'frost',
    'grove', 'mesa', 'ridge', 'stream', 'thorn', 'vibe', 'wave', 'wind',
  ];

  /// Generates a high-entropy random password with mixed character classes.
  static String generateRandomPassword({
    int length = 16,
    bool includeSymbols = true,
  }) {
    if (length < 8) length = 8;
    final chars = StringBuffer();
    final allChars = '$_lowercase$_uppercase$_digits${includeSymbols ? _symbols : ""}';

    // Ensure at least one of each required category
    chars.write(_lowercase[_secureRandom.nextInt(_lowercase.length)]);
    chars.write(_uppercase[_secureRandom.nextInt(_uppercase.length)]);
    chars.write(_digits[_secureRandom.nextInt(_digits.length)]);
    if (includeSymbols) {
      chars.write(_symbols[_secureRandom.nextInt(_symbols.length)]);
    }

    // Fill the remainder
    final remaining = length - chars.length;
    for (var i = 0; i < remaining; i++) {
      chars.write(allChars[_secureRandom.nextInt(allChars.length)]);
    }

    // Shuffle the result
    final list = chars.toString().split('');
    list.shuffle(_secureRandom);
    return list.join('');
  }

  /// Generates a memorable Diceware-style passphrase composed of random words.
  static String generatePassphrase({int wordCount = 4, String separator = '-'}) {
    final words = <String>[];
    for (var i = 0; i < wordCount; i++) {
      words.add(_dicewareWords[_secureRandom.nextInt(_dicewareWords.length)]);
    }
    return words.join(separator);
  }
}
