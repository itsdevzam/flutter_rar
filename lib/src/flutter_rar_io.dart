import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import 'rar_models.dart';

/// Android, iOS, macOS, Linux, and Windows extract with native UnRAR.
const bool canExtractToDirectory = true;

const int _modeList = 0;
const int _modeExtract = 1;
const int _modeExtractOne = 2;
const int _modeTest = 3;

const MethodChannel _iosChannel = MethodChannel('com.booknest.flutter_rar');

/// Lists the entries in the RAR file at [rarFilePath].
Future<RarResult> listContents({
  required String rarFilePath,
  String? password,
  Future<String?> Function(int volumeNumber)? nextVolumePath,
}) {
  if (Platform.isIOS) {
    return _iosResult('list', {
      'rarFilePath': rarFilePath,
      'password': password ?? '',
    }, nextVolumePath);
  }
  return _run(
    nextVolumePath: nextVolumePath,
    body: () => _call(
      mode: _modeList,
      rarFilePath: rarFilePath,
      destinationPath: '',
      password: password,
    ),
  );
}

/// Lists entries in an in-memory RAR archive.
Future<RarResult> listBytes({
  required Uint8List bytes,
  String? password,
}) {
  if (Platform.isIOS) {
    return _withTempArchive(bytes, (path) {
      return _iosResult('list', {
        'rarFilePath': path,
        'password': password ?? '',
      }, null);
    });
  }
  return Isolate.run(() => _withTempArchive(bytes, (path) async {
    return _call(
      mode: _modeList,
      rarFilePath: path,
      destinationPath: '',
      password: password,
    );
  }));
}

/// Extracts every file into [destinationPath] and returns each written path.
Future<RarResult> extract({
  required String rarFilePath,
  required String destinationPath,
  String? password,
  String? entryName,
  Future<String?> Function(int volumeNumber)? nextVolumePath,
}) {
  if (Platform.isIOS) {
    return _iosResult('extract', {
      'rarFilePath': rarFilePath,
      'destinationPath': destinationPath,
      'password': password ?? '',
      'entryName': entryName ?? '',
    }, nextVolumePath);
  }
  return _run(
    nextVolumePath: nextVolumePath,
    body: () => _call(
      mode: entryName == null || entryName.isEmpty ? _modeExtract : _modeExtractOne,
      rarFilePath: rarFilePath,
      destinationPath: destinationPath,
      password: password,
      entryName: entryName ?? '',
    ),
  );
}

/// Decodes every file entry and checks its checksum without writing files.
Future<RarResult> testArchive({
  required String rarFilePath,
  String? password,
  Future<String?> Function(int volumeNumber)? nextVolumePath,
}) {
  if (Platform.isIOS) {
    return _iosResult('test', {
      'rarFilePath': rarFilePath,
      'password': password ?? '',
    }, nextVolumePath);
  }
  return _run(
    nextVolumePath: nextVolumePath,
    body: () => _call(
      mode: _modeTest,
      rarFilePath: rarFilePath,
      destinationPath: '',
      password: password,
    ),
  );
}

/// Reads one entry. Pass either [rarFilePath] or [bytes].
Future<RarFileBytes> readEntry({
  String? rarFilePath,
  Uint8List? bytes,
  required String entryName,
  String? password,
  Future<String?> Function(int volumeNumber)? nextVolumePath,
}) {
  if (Platform.isIOS) {
    final blocked = _volumeBlock(nextVolumePath);
    if (blocked != null) {
      return Future<RarFileBytes>.value(
        RarFileBytes(success: false, message: blocked.message),
      );
    }
    return _readEntry(
      rarFilePath: rarFilePath,
      bytes: bytes,
      entryName: entryName,
      password: password,
    );
  }
  return _runBytes(
    nextVolumePath: nextVolumePath,
    body: () => _readEntry(
      rarFilePath: rarFilePath,
      bytes: bytes,
      entryName: entryName,
      password: password,
    ),
  );
}

Future<RarResult> _run({
  required Future<String?> Function(int volumeNumber)? nextVolumePath,
  required RarResult Function() body,
}) {
  final blocked = _volumeBlock(nextVolumePath);
  if (blocked != null) return Future<RarResult>.value(blocked);
  return Isolate.run(body);
}

Future<RarFileBytes> _runBytes({
  required Future<String?> Function(int volumeNumber)? nextVolumePath,
  required Future<RarFileBytes> Function() body,
}) {
  final blocked = _volumeBlock(nextVolumePath);
  if (blocked != null) {
    return Future<RarFileBytes>.value(
      RarFileBytes(success: false, message: blocked.message),
    );
  }
  return Isolate.run(body);
}

RarResult? _volumeBlock(Future<String?> Function(int volumeNumber)? nextVolumePath) {
  if (nextVolumePath == null) return null;
  return const RarResult(
    success: false,
    message: 'Multi-volume archives are not supported by the native extractor.',
  );
}

Future<RarResult> _iosResult(
  String method,
  Map<String, String> args,
  Future<String?> Function(int volumeNumber)? nextVolumePath,
) async {
  final blocked = _volumeBlock(nextVolumePath);
  if (blocked != null) return blocked;
  try {
    final text = await _iosChannel.invokeMethod<String>(method, args);
    if (text == null || text.isEmpty) {
      return const RarResult(success: false, message: 'UnrarKit returned no result.');
    }
    return _parseResult(text);
  } on PlatformException catch (error) {
    return RarResult(
      success: false,
      message: error.message ?? 'UnrarKit failed',
    );
  }
}

Future<RarFileBytes> _readEntry({
  String? rarFilePath,
  Uint8List? bytes,
  required String entryName,
  String? password,
}) async {
  if (bytes != null) {
    return _withTempArchive(bytes, (path) {
      return _readExtracted(path, entryName, password);
    });
  }
  if (rarFilePath == null) {
    return const RarFileBytes(success: false, message: 'Provide rarFilePath or bytes');
  }
  return _readExtracted(rarFilePath, entryName, password);
}

Future<RarFileBytes> _readExtracted(
  String rarFilePath,
  String entryName,
  String? password,
) async {
  final directory = await Directory.systemTemp.createTemp('flutter_rar_read_');
  try {
    final result = Platform.isIOS
        ? await _iosResult('extract', {
            'rarFilePath': rarFilePath,
            'destinationPath': directory.path,
            'password': password ?? '',
            'entryName': entryName,
          }, null)
        : _call(
            mode: _modeExtractOne,
            rarFilePath: rarFilePath,
            destinationPath: directory.path,
            password: password,
            entryName: entryName,
          );
    if (!result.success) {
      return RarFileBytes(success: false, message: result.message);
    }
    final files = result.entries.where((entry) => entry.extractedPath.isNotEmpty && !entry.isDirectory);
    if (files.isEmpty) {
      return const RarFileBytes(success: false, message: 'Entry is not a file');
    }
    final file = File(files.first.extractedPath);
    return RarFileBytes(
      success: true,
      message: 'Read ${files.first.name}',
      name: files.first.name,
      bytes: await file.readAsBytes(),
    );
  } finally {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

Future<T> _withTempArchive<T>(Uint8List bytes, Future<T> Function(String path) use) async {
  final file = File('${Directory.systemTemp.path}/flutter_rar_${DateTime.now().microsecondsSinceEpoch}.rar');
  await file.writeAsBytes(bytes, flush: true);
  try {
    return await use(file.path);
  } finally {
    if (await file.exists()) await file.delete();
  }
}

RarResult _call({
  required int mode,
  required String rarFilePath,
  required String destinationPath,
  String? password,
  String entryName = '',
}) {
  if (mode == _modeExtract || mode == _modeExtractOne) {
    try {
      Directory(destinationPath).createSync(recursive: true);
    } on FileSystemException {
      return const RarResult(success: false, message: 'Could not create the destination directory');
    }
  }
  final library = _library();
  final run = library.lookupFunction<_RunNative, _RunDart>('flutter_rar_run');
  final free = library.lookupFunction<_FreeNative, _FreeDart>('flutter_rar_free');
  final pathPtr = rarFilePath.toNativeUtf8();
  final destPtr = destinationPath.toNativeUtf8();
  final passwordPtr = (password ?? '').toNativeUtf8();
  final entryPtr = entryName.toNativeUtf8();
  try {
    final resultPtr = run(pathPtr, destPtr, passwordPtr, entryPtr, mode);
    if (resultPtr == nullptr) {
      return const RarResult(success: false, message: 'The native library returned no result.');
    }
    try {
      return _parseResult(resultPtr.toDartString());
    } finally {
      free(resultPtr);
    }
  } finally {
    malloc.free(pathPtr);
    malloc.free(destPtr);
    malloc.free(passwordPtr);
    malloc.free(entryPtr);
  }
}

RarResult _parseResult(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map<String, dynamic>) {
    return const RarResult(success: false, message: 'The native library returned invalid JSON.');
  }
  final rawEntries = decoded['entries'];
  final entries = <RarEntry>[
    if (rawEntries is List)
      for (final item in rawEntries)
        if (item is Map<String, dynamic>)
          RarEntry(
            name: item['name'] as String? ?? '',
            extractedPath: item['extractedPath'] as String? ?? '',
            isDirectory: item['isDirectory'] == true,
            uncompressedSize: _asInt(item['uncompressedSize']),
            compressedSize: _asInt(item['compressedSize']),
            isEncrypted: item['isEncrypted'] == true,
            compression: item['compression'] as String? ?? '',
            modifiedAt: item['modifiedAt'] is num
                ? DateTime.fromMillisecondsSinceEpoch(
                    (item['modifiedAt'] as num).toInt(),
                    isUtc: true,
                  )
                : null,
            crc32: item['crc32'] is num ? (item['crc32'] as num).toInt() : null,
            skipped: item['skipped'] == true,
          ),
  ];
  return RarResult(
    success: decoded['success'] == true,
    message: decoded['message'] as String? ?? '',
    rarVersion: decoded['rarVersion'] as String? ?? '',
    isEncrypted: decoded['isEncrypted'] == true,
    destinationPath: decoded['destinationPath'] as String? ?? '',
    entries: entries,
  );
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

DynamicLibrary _library() {
  final existing = _opened;
  if (existing != null) return existing;
  final override = Platform.environment['FLUTTER_RAR_LIB'];
  final candidates = <String>[
    if (override != null && override.isNotEmpty) override,
    if (Platform.isMacOS || Platform.isIOS) 'flutter_rar.framework/flutter_rar',
    if (Platform.isAndroid || Platform.isLinux) 'libflutter_rar.so',
    if (Platform.isWindows) 'flutter_rar.dll',
    if (Platform.isMacOS) 'build/host/libflutter_rar.dylib',
  ];
  Object? lastError;
  for (final candidate in candidates) {
    try {
      return _opened = DynamicLibrary.open(candidate);
    } catch (error) {
      lastError = error;
    }
  }
  throw StateError('Could not load the native UnRAR library. $lastError');
}

DynamicLibrary? _opened;

typedef _RunNative = Pointer<Utf8> Function(
  Pointer<Utf8> path,
  Pointer<Utf8> dest,
  Pointer<Utf8> password,
  Pointer<Utf8> entry,
  Int32 mode,
);
typedef _RunDart = Pointer<Utf8> Function(
  Pointer<Utf8> path,
  Pointer<Utf8> dest,
  Pointer<Utf8> password,
  Pointer<Utf8> entry,
  int mode,
);
typedef _FreeNative = Void Function(Pointer<Utf8> ptr);
typedef _FreeDart = void Function(Pointer<Utf8> ptr);
