import 'dart:typed_data';

import 'package:koni_archive_core/koni_archive_core.dart';
import 'package:koni_rar/koni_rar.dart';

import 'rar_models.dart';
import 'rar_paths.dart';
import 'rar_version.dart';

/// Reads a RAR archive from memory and lists its entries.
Future<RarResult> listArchiveBytes(Uint8List bytes, {String? password}) {
  return _openBytes(bytes, password: password, job: _ArchiveJob.list);
}

/// Decodes one entry from an in-memory RAR archive.
Future<RarFileBytes> readArchiveBytes(
  Uint8List bytes, {
  required String entryName,
  String? password,
}) async {
  final opened = await _open(bytes, password);
  if (opened.result != null) {
    return RarFileBytes(success: false, message: opened.result!.message);
  }
  final archive = opened.archive!;
  try {
    final entry = _find(archive, entryName);
    if (entry == null) {
      return const RarFileBytes(success: false, message: 'Entry not found');
    }
    if (!entry.isFile) {
      return const RarFileBytes(success: false, message: 'Entry is not a file');
    }
    final data = await _readAll(archive, entry);
    return RarFileBytes(
      success: true,
      message: 'Read ${entry.path}',
      name: entry.path,
      bytes: data,
    );
  } on ArchiveException catch (error) {
    return RarFileBytes(
      success: false,
      message: describeArchiveError(error, password),
    );
  } finally {
    await opened.close();
  }
}

/// Shared list, test, and extract walk over an already open archive.
Future<RarResult> collectArchive({
  required ArchiveReader archive,
  required String rarVersion,
  required String destinationPath,
  String? onlyEntry,
  bool test = false,
  Future<void> Function(ArchiveEntry entry, String outputPath)? writeFile,
  Future<void> Function(String outputPath)? createDirectory,
}) async {
  final extracting = writeFile != null;
  final entries = <RarEntry>[];
  var wroteFiles = 0;
  var skipped = 0;
  var matched = onlyEntry == null;

  for (final entry in archive.entries) {
    final wanted = onlyEntry == null || _sameEntry(entry.path, onlyEntry);
    if (wanted && onlyEntry != null) matched = true;

    if (!extracting) {
      if (test && wanted && entry.isFile) {
        await for (final _ in archive.openRead(entry)) {}
      }
      final unsafe = entry.pathEscapedRoot;
      if (unsafe) skipped++;
      entries.add(_describe(entry, skipped: unsafe));
      continue;
    }

    if (!wanted) {
      entries.add(_describe(entry));
      continue;
    }
    if (entry.path.isEmpty || entry.pathEscapedRoot) {
      skipped++;
      entries.add(_describe(entry, skipped: true));
      continue;
    }
    final output = safeDestinationPath(destinationPath, entry.path);
    if (output == null) {
      skipped++;
      entries.add(_describe(entry, skipped: true));
      continue;
    }
    if (entry.isDirectory) {
      await createDirectory?.call(output);
      entries.add(_describe(entry, extractedPath: output));
    } else if (entry.isFile) {
      await writeFile(entry, output);
      wroteFiles++;
      entries.add(_describe(entry, extractedPath: output));
    } else {
      skipped++;
      entries.add(_describe(entry, skipped: true));
    }
  }

  final encrypted = archive.entries.any((entry) => entry.isEncrypted);
  if (onlyEntry != null && !matched) {
    return RarResult(
      success: false,
      message: 'Entry not found',
      rarVersion: rarVersion,
      isEncrypted: encrypted,
      destinationPath: extracting ? destinationPath : '',
      entries: entries,
    );
  }

  final skipNote = skipped == 0
      ? ''
      : ' Skipped $skipped unsafe or unsupported entries.';
  final message = test
      ? 'Archive is valid'
      : extracting
      ? 'Extracted $wroteFiles files.$skipNote'
      : 'Listed ${entries.length} entries.$skipNote';
  return RarResult(
    success: true,
    message: message.trim(),
    rarVersion: rarVersion,
    isEncrypted: encrypted,
    destinationPath: extracting ? destinationPath : '',
    entries: entries,
  );
}

/// Maps a koni archive error to a short message.
String describeArchiveError(Object error, String? password) {
  final supplied = password != null && password.isNotEmpty;
  if (error is InvalidPasswordException) return 'Wrong password';
  if (error is EncryptedArchiveException) {
    if (!supplied) return 'Password required';
    return error.message;
  }
  if (error is ChecksumMismatchException && supplied) {
    return 'Wrong password or archive data is corrupt';
  }
  if (error is ArchiveException) return error.message;
  return error.toString();
}

String? normalizePassword(String? password) {
  if (password == null || password.isEmpty) return null;
  return password;
}

enum _ArchiveJob { list, test }

Future<RarResult> _openBytes(
  Uint8List bytes, {
  required String? password,
  required _ArchiveJob job,
  String? onlyEntry,
}) async {
  final opened = await _open(bytes, password);
  if (opened.result != null) return opened.result!;
  final archive = opened.archive!;
  try {
    return await collectArchive(
      archive: archive,
      rarVersion: opened.version,
      destinationPath: '',
      onlyEntry: onlyEntry,
      test: job == _ArchiveJob.test,
    );
  } on ArchiveException catch (error) {
    return RarResult(
      success: false,
      message: describeArchiveError(error, password),
      rarVersion: opened.version,
    );
  } finally {
    await opened.close();
  }
}

/// Tests an in-memory archive by decoding every file entry.
Future<RarResult> testArchiveBytes(Uint8List bytes, {String? password}) {
  return _openBytes(bytes, password: password, job: _ArchiveJob.test);
}

class _Opened {
  _Opened.archive(this.archive, this.source, this.version) : result = null;
  _Opened.failure(this.result) : archive = null, source = null, version = '';

  final ArchiveReader? archive;
  final ByteSource? source;
  final String version;
  final RarResult? result;

  Future<void> close() async {
    await archive?.close();
    await source?.close();
  }
}

Future<_Opened> _open(Uint8List bytes, String? password) async {
  final version = detectRarVersion(bytes);
  if (version.isEmpty) {
    return _Opened.failure(
      const RarResult(success: false, message: 'Not a RAR archive'),
    );
  }
  if (version == 'RAR15') {
    return _Opened.failure(
      const RarResult(
        success: false,
        message: 'RAR 1.5 archives are not supported',
        rarVersion: 'RAR15',
      ),
    );
  }
  MemoryByteSource? source;
  try {
    source = MemoryByteSource(bytes);
    final format = const RarFormat();
    if (!await format.matches(source)) {
      await source.close();
      source = null;
      return _Opened.failure(
        RarResult(
          success: false,
          message: 'Not a RAR archive',
          rarVersion: version,
        ),
      );
    }
    final archive = await format.createReader(
      source,
      ArchiveReadOptions(password: normalizePassword(password)),
    );
    final opened = _Opened.archive(archive, source, version);
    source = null;
    return opened;
  } on ArchiveException catch (error) {
    await source?.close();
    return _Opened.failure(
      RarResult(
        success: false,
        message: describeArchiveError(error, password),
        rarVersion: version,
      ),
    );
  }
}

ArchiveEntry? _find(ArchiveReader archive, String entryName) {
  for (final entry in archive.entries) {
    if (_sameEntry(entry.path, entryName)) return entry;
  }
  return null;
}

bool _sameEntry(String stored, String requested) {
  return _norm(stored) == _norm(requested);
}

Future<Uint8List> _readAll(ArchiveReader archive, ArchiveEntry entry) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in archive.openRead(entry)) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

String _norm(String value) {
  var text = value.replaceAll('\\', '/');
  while (text.startsWith('./')) {
    text = text.substring(2);
  }
  while (text.endsWith('/')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

RarEntry _describe(
  ArchiveEntry entry, {
  String extractedPath = '',
  bool skipped = false,
}) {
  return RarEntry(
    name: entry.path,
    extractedPath: extractedPath,
    isDirectory: entry.isDirectory,
    uncompressedSize: entry.uncompressedSize,
    compressedSize: entry.compressedSize ?? 0,
    isEncrypted: entry.isEncrypted,
    compression: entry.compression.name,
    modifiedAt: entry.modified,
    crc32: entry.crc32,
    skipped: skipped,
  );
}
