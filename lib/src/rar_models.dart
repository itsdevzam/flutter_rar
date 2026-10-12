/// One item stored inside a RAR archive.
class RarEntry {
  /// Creates an entry description.
  const RarEntry({
    required this.name,
    required this.isDirectory,
    required this.uncompressedSize,
    required this.compressedSize,
    required this.isEncrypted,
    required this.compression,
    this.extractedPath = '',
    this.modifiedAt,
    this.crc32,
    this.skipped = false,
  });

  /// Archive-relative path, using `/` separators.
  final String name;

  /// Absolute path written by extract, or empty when the entry was only listed.
  final String extractedPath;

  /// Whether this entry is a directory.
  final bool isDirectory;

  /// Uncompressed size in bytes.
  final int uncompressedSize;

  /// Compressed size in bytes, or 0 when the archive does not record it.
  final int compressedSize;

  /// Whether the entry's data is encrypted.
  final bool isEncrypted;

  /// Compression method name, such as `stored` or `rar5`.
  final String compression;

  /// Last modified time in UTC, when the archive records one.
  final DateTime? modifiedAt;

  /// CRC-32 of the uncompressed bytes, when the archive records one.
  final int? crc32;

  /// Whether this entry was not written because its path was unsafe or its
  /// type cannot be extracted (for example a symlink).
  final bool skipped;

  /// Whether this entry is a regular file.
  bool get isFile => !isDirectory && !skipped;
}

/// Result of listing, testing, or extracting a RAR archive.
class RarResult {
  /// Creates a result.
  const RarResult({
    required this.success,
    required this.message,
    this.rarVersion = '',
    this.isEncrypted = false,
    this.destinationPath = '',
    this.entries = const [],
  });

  /// Whether the operation finished without an error.
  final bool success;

  /// Status or error text.
  final String message;

  /// `RAR4`, `RAR5`, or empty when the file is not a RAR archive.
  final String rarVersion;

  /// Whether any entry is encrypted.
  final bool isEncrypted;

  /// Directory files were written into, or empty for list and test.
  final String destinationPath;

  /// Archive entries in archive order.
  final List<RarEntry> entries;

  /// File names inside the archive, without directories.
  List<String> get names => [
    for (final entry in entries)
      if (!entry.isDirectory) entry.name,
  ];

  /// Absolute paths of entries that were written.
  List<String> get locations => [
    for (final entry in entries)
      if (entry.extractedPath.isNotEmpty) entry.extractedPath,
  ];
}

/// Bytes of a single archive entry.
class RarFileBytes {
  /// Creates a byte result.
  const RarFileBytes({
    required this.success,
    required this.message,
    this.name = '',
    this.bytes = const [],
  });

  /// Whether [bytes] holds the decoded entry.
  final bool success;

  /// Status or error text.
  final String message;

  /// Archive-relative path of the entry.
  final String name;

  /// Decoded bytes. Empty when [success] is false.
  final List<int> bytes;
}
