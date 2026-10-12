import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_rar/flutter_rar.dart';

import 'rar_check.dart';
import 'sample_rar.dart';

/// Browser checks. Web can list and read bytes, and cannot write a folder.
Future<List<RarCheck>> runRarChecks() async {
  final checks = <RarCheck>[];

  checks.add(
    RarCheck(
      name: 'Folder extract',
      passed: FlutterRar.canExtractToDirectory == false,
      detail: 'Web lists and reads bytes. It does not extract into a folder.',
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

  final listed = await FlutterRar.listBytes(bytes: sampleRar, password: samplePassword);
  checks.add(
    RarCheck(
      name: 'List encrypted RAR5',
      passed: listed.success &&
          listed.rarVersion == 'RAR5' &&
          listed.isEncrypted &&
          sampleFiles.keys.every(listed.names.contains),
      detail: listed.success
          ? '${listed.rarVersion} encrypted=${listed.isEncrypted} entries=${listed.names.join(', ')}'
          : listed.message,
    ),
  );

  final wrong = await FlutterRar.listBytes(bytes: sampleRar, password: 'nope');
  checks.add(
    RarCheck(
      name: 'Wrong password',
      passed: !wrong.success && wrong.message.toLowerCase().contains('password'),
      detail: wrong.message,
    ),
  );

  final notes = await FlutterRar.readEntry(
    bytes: sampleRar,
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

  final created = await FlutterRar.create(
    outputPath: 'ignored.rar',
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
