import 'dart:typed_data';

import 'rar_models.dart';
import 'rar_work.dart';

/// Web has no filesystem path to extract into.
const bool canExtractToDirectory = false;

/// Path listing is unavailable on web. Use [listBytes].
Future<RarResult> listContents({
  required String rarFilePath,
  String? password,
  Future<String?> Function(int volumeNumber)? nextVolumePath,
}) async {
  return const RarResult(
    success: false,
    message:
        'Reading a filesystem path is not available on web. Use FlutterRar.listBytes with the archive bytes.',
  );
}

/// Lists entries in an in-memory RAR archive.
Future<RarResult> listBytes({required Uint8List bytes, String? password}) {
  return listArchiveBytes(bytes, password: password);
}

/// Extracting to a directory is unavailable on web. Use [readEntry].
Future<RarResult> extract({
  required String rarFilePath,
  required String destinationPath,
  String? password,
  String? entryName,
  Future<String?> Function(int volumeNumber)? nextVolumePath,
}) async {
  return const RarResult(
    success: false,
    message:
        'Extracting to a filesystem path is not available on web. Use FlutterRar.readEntry to get the file bytes.',
  );
}

/// Testing a filesystem path is unavailable on web.
Future<RarResult> testArchive({
  required String rarFilePath,
  String? password,
  Future<String?> Function(int volumeNumber)? nextVolumePath,
}) async {
  return const RarResult(
    success: false,
    message:
        'Testing a filesystem path is not available on web. Use FlutterRar.listBytes and FlutterRar.readEntry.',
  );
}

/// Reads one entry from [bytes]. [rarFilePath] is not available on web.
Future<RarFileBytes> readEntry({
  String? rarFilePath,
  Uint8List? bytes,
  required String entryName,
  String? password,
  Future<String?> Function(int volumeNumber)? nextVolumePath,
}) {
  if (bytes == null) {
    return Future.value(
      const RarFileBytes(
        success: false,
        message:
            'Reading a filesystem path is not available on web. Pass the archive bytes to readEntry.',
      ),
    );
  }
  return readArchiveBytes(bytes, entryName: entryName, password: password);
}
