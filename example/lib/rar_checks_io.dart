import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_rar/flutter_rar.dart';

import 'rar_check.dart';
import 'sample_rar.dart';

/// Phone and desktop checks, including writing extracted files.
Future<List<RarCheck>> runRarChecks() async {
  final checks = <RarCheck>[];

  checks.add(
    RarCheck(
      name: 'Folder extract',
      passed: FlutterRar.canExtractToDirectory,
      detail: FlutterRar.canExtractToDirectory
          ? 'This platform can extract into a folder.'
          : 'This platform cannot extract into a folder.',
    ),
  );

  final junk = await FlutterRar.listBytes(bytes: Uint8List.fromList([1, 2, 3, 4]));
  checks.add(
    RarCheck(
      name: 'Reject non-RAR',
      passed: !junk.success && junk.message == 'Not a RAR archive',
      detail: junk.message,
    ),
  );

  final directory = await Directory.systemTemp.createTemp('flutter_rar_example_');
  try {
    final rarFile = File('${directory.path}/sample.rar');
    await rarFile.writeAsBytes(sampleRar);
    final destination = Directory('${directory.path}/out');

    final listed = await FlutterRar.listContents(
      rarFilePath: rarFile.path,
      password: samplePassword,
    );
    checks.add(
      RarCheck(
        name: 'List encrypted RAR5',
        passed: listed.success &&
            listed.rarVersion == 'RAR5' &&
            listed.isEncrypted &&
            sampleFiles.keys.every(listed.names.contains),
        detail: listed.success
            ? '${listed.message} ${listed.rarVersion} entries=${listed.names.join(', ')}'
            : listed.message,
      ),
    );

    final wrong = await FlutterRar.extract(
      rarFilePath: rarFile.path,
      destinationPath: destination.path,
      password: 'nope',
    );
    checks.add(
      RarCheck(
        name: 'Wrong password',
        passed: !wrong.success && wrong.message.toLowerCase().contains('password'),
        detail: wrong.message,
      ),
    );

    final extracted = await FlutterRar.extract(
      rarFilePath: rarFile.path,
      destinationPath: destination.path,
      password: samplePassword,
    );
    var filesMatch = extracted.success && await rarFile.exists();
    if (filesMatch) {
      for (final item in sampleFiles.entries) {
        final match = extracted.entries.where((entry) => entry.name == item.key);
        if (match.length != 1) {
          filesMatch = false;
          break;
        }
        final text = await File(match.single.extractedPath).readAsString();
        if (text != item.value) {
          filesMatch = false;
          break;
        }
      }
    }
    checks.add(
      RarCheck(
        name: 'Extract archive',
        passed: filesMatch,
        detail: extracted.message,
      ),
    );

    final one = await FlutterRar.extractFile(
      rarFilePath: rarFile.path,
      destinationPath: '${directory.path}/one',
      entryName: 'hello.txt',
      password: samplePassword,
    );
    final oneText = one.success && one.locations.length == 1
        ? await File(one.locations.single).readAsString()
        : '';
    checks.add(
      RarCheck(
        name: 'Extract one file',
        passed: one.success && oneText == sampleFiles['hello.txt'],
        detail: one.message,
      ),
    );

    final notes = await FlutterRar.readEntry(
      rarFilePath: rarFile.path,
      entryName: 'nested/notes.txt',
      password: samplePassword,
    );
    final notesText = notes.success ? utf8.decode(notes.bytes) : '';
    checks.add(
      RarCheck(
        name: 'Read one entry',
        passed: notes.success && notesText == sampleFiles['nested/notes.txt'],
        detail: notes.success ? notesText.trim() : notes.message,
      ),
    );

    final tested = await FlutterRar.test(
      rarFilePath: rarFile.path,
      password: samplePassword,
    );
    checks.add(
      RarCheck(
        name: 'Test checksums',
        passed: tested.success,
        detail: tested.message,
      ),
    );
  } finally {
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  final created = await FlutterRar.create(
    outputPath: '${directory.path}/ignored.rar',
    sourcePaths: const ['a.txt'],
  );
  checks.add(
    RarCheck(
      name: 'Create is unsupported',
      passed: !created.success && created.message.contains('not supported'),
      detail: created.message,
    ),
  );

  return checks;
}
