import 'dart:typed_data';

import 'src/flutter_rar_web.dart'
    if (dart.library.io) 'src/flutter_rar_io.dart'
    as rar;
import 'src/rar_models.dart';

export 'src/rar_models.dart';

/// Lists, tests, and extracts RAR archives.
///
/// Password-protected RAR4 and RAR5 archives, including encrypted headers,
/// are supported. Creating a RAR archive is not supported.
class FlutterRar {
  /// Whether [extract] can write files on this platform.
  ///
  /// Android, iOS, macOS, Linux, and Windows can. Web can list and read
  /// bytes, but it has no destination directory.
  static bool get canExtractToDirectory => rar.canExtractToDirectory;

  /// Lists every entry in the archive at [rarFilePath].
  ///
  /// [password] is required when the archive uses encrypted headers.
  /// Multi-volume archives are not supported. Passing [nextVolumePath]
  /// returns a failure.
  static Future<RarResult> listContents({
    required String rarFilePath,
    String? password,
    Future<String?> Function(int volumeNumber)? nextVolumePath,
  }) {
    return rar.listContents(
      rarFilePath: rarFilePath,
      password: password,
      nextVolumePath: nextVolumePath,
    );
  }

  /// Lists every entry in an in-memory archive.
  ///
  /// This is the web entry point: read the file the user picked, then pass
  /// the bytes here.
  static Future<RarResult> listBytes({
    required Uint8List bytes,
    String? password,
  }) {
    return rar.listBytes(bytes: bytes, password: password);
  }

  /// Extracts the archive into [destinationPath].
  ///
  /// Each written file and directory is returned in [RarResult.locations]
  /// and on [RarEntry.extractedPath]. The original RAR file is left in place.
  /// Pass [entryName] to write only that one archive path.
  static Future<RarResult> extract({
    required String rarFilePath,
    required String destinationPath,
    String? password,
    String? entryName,
    Future<String?> Function(int volumeNumber)? nextVolumePath,
  }) {
    return rar.extract(
      rarFilePath: rarFilePath,
      destinationPath: destinationPath,
      password: password,
      entryName: entryName,
      nextVolumePath: nextVolumePath,
    );
  }

  /// Extracts the single archive path [entryName] into [destinationPath].
  static Future<RarResult> extractFile({
    required String rarFilePath,
    required String destinationPath,
    required String entryName,
    String? password,
    Future<String?> Function(int volumeNumber)? nextVolumePath,
  }) {
    return extract(
      rarFilePath: rarFilePath,
      destinationPath: destinationPath,
      password: password,
      entryName: entryName,
      nextVolumePath: nextVolumePath,
    );
  }

  /// Decodes every file and checks its checksum without writing anything.
  static Future<RarResult> test({
    required String rarFilePath,
    String? password,
    Future<String?> Function(int volumeNumber)? nextVolumePath,
  }) {
    return rar.testArchive(
      rarFilePath: rarFilePath,
      password: password,
      nextVolumePath: nextVolumePath,
    );
  }

  /// Returns the decoded bytes of [entryName].
  ///
  /// On a phone or desktop, pass [rarFilePath]. On web, pass [bytes].
  static Future<RarFileBytes> readEntry({
    String? rarFilePath,
    Uint8List? bytes,
    required String entryName,
    String? password,
    Future<String?> Function(int volumeNumber)? nextVolumePath,
  }) {
    return rar.readEntry(
      rarFilePath: rarFilePath,
      bytes: bytes,
      entryName: entryName,
      password: password,
      nextVolumePath: nextVolumePath,
    );
  }

  /// RAR creation is not supported.
  ///
  /// The RAR compression algorithm is proprietary. This method always
  /// returns [RarResult.success] `false` and does not write [outputPath].
  static Future<RarResult> create({
    required String outputPath,
    required List<String> sourcePaths,
    String? password,
    int compressionLevel = 5,
  }) {
    return Future<RarResult>.value(
      RarResult(
        success: false,
        message:
            'Creating RAR archives is not supported, so $outputPath was not written. '
            'RAR compression is proprietary. ${sourcePaths.length} source path(s) '
            'and compression level $compressionLevel were ignored'
            '${password == null ? '' : ', including the password'}.',
      ),
    );
  }
}
