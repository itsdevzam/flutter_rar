import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_rar/flutter_rar.dart';
import 'package:flutter_rar/src/rar_paths.dart';
import 'package:flutter_test/flutter_test.dart';

/// RAR5 archive with encrypted headers (`rar -hpsecret`), inlined from the
/// koni_rar test corpus. Entries: hello.txt, lorem.txt, nested/notes.txt.
final Uint8List _encryptedHeaders = base64Decode(
  'UmFyIRoHAQABoG2gIQQAAAEPQ+Y3H94N1esE9QAHoSnGi5lPbMGkTZD+e2lB8mFtr/eXiZ7qNL2Z'
  '6END7Wjdv75N1W14NN/LDFZ4jhLG0N8hsna8f4d2x62Oa46K9jmvYV6nTS35znUAwCZ0uQakIlKZ'
  'qSF5PshlkZM/30/9hXP+RIDYIHHpLv6eANAkInTJsIUc3qjoUvUQT4BDhCvXb09yoJR4LyBvkjmd'
  'YgQlW49NskR1QEwL9gDNha4VhyZ0dZ3lntVHJUFHTdyrQncbFVg3Y5BvosydxwM9h3zL6A7LjWfM'
  'eqAw8bct3Ga5ltC9e7X02+0OoIXR7nN1p9XakrMrseBCWKwTDqHHoNLruv8b+jch8eeuUBzLz5fp'
  'BDMQItieJT9Kk5x1Hq4tk8lhGVNCldUup3lRK0BEULNdG0dv8L8JzDhdR6pDH+UxTOX56veahdBF'
  'tnOCKK1iKxlbwk1cFsNkRUbjBDg/dw48hlvfAhyICxejgjNwUSShMf5oYF86gWVsXHEtDXJRGLf1'
  'KK2Vz9kokE7QWjkVAaMZ1hMinzPqBeaZt24TtEIHUkSOvR7C28U4dyD3dGHY2xek2Wx6jr20dIhB'
  'Dw6pKLzeGbsP1DxxdHqbeaP/2S/CzlGnpEMCUrYC9qHkjAIfaTMwfLXf3T9/04AMnCVuMCioY0u9'
  'UnWqdEEkHGSPgY1151W4K/yJUAGEOOJC3Y4b/iUVZawx99LAWILEDf39s4J6qlROU7cLRT+V05LL'
  '7S2hR3EkwRNEk7yJRQXuj6v2PbhiDvEC4W+Ao3p0gcRk2gc+',
);

const _expected = {
  'hello.txt': 'hello, encrypted headers!\n',
  'lorem.txt':
      'lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor\n',
  'nested/notes.txt': 'deep nested data\n',
};

void main() {
  test('rejects paths that escape the destination', () {
    expect(safeDestinationPath('/tmp/out', '../etc/passwd'), isNull);
    expect(safeDestinationPath('/tmp/out', '/etc/passwd'), isNull);
    expect(safeDestinationPath('/tmp/out', r'C:\Windows\notepad.exe'), isNull);
    expect(safeDestinationPath('/tmp/out', 'nested/notes.txt'), '/tmp/out/nested/notes.txt');
  });

  test('create never writes a RAR archive', () async {
    final result = await FlutterRar.create(
      outputPath: '/tmp/ignored.rar',
      sourcePaths: const ['a.txt'],
    );
    expect(result.success, isFalse);
    expect(result.message, contains('not supported'));
  });

  test('listBytes rejects a file that is not a RAR', () async {
    final result = await FlutterRar.listBytes(bytes: Uint8List.fromList([1, 2, 3, 4]));
    expect(result.success, isFalse);
    expect(result.message, 'Not a RAR archive');
  });

  test('lists and extracts a password-protected RAR5 archive', () async {
    final listed = await FlutterRar.listBytes(bytes: _encryptedHeaders, password: 'secret');
    expect(listed.success, isTrue, reason: listed.message);
    expect(listed.rarVersion, 'RAR5');
    expect(listed.isEncrypted, isTrue);
    expect(listed.names, containsAll(_expected.keys));
    expect(listed.locations, isEmpty);

    final directory = await Directory.systemTemp.createTemp('flutter_rar_');
    try {
      final rarFile = File('${directory.path}/sample.rar');
      await rarFile.writeAsBytes(_encryptedHeaders);
      final destination = Directory('${directory.path}/out');

      final wrong = await FlutterRar.extract(
        rarFilePath: rarFile.path,
        destinationPath: destination.path,
        password: 'nope',
      );
      expect(wrong.success, isFalse, reason: wrong.message);
      expect(wrong.message.toLowerCase(), contains('password'));

      final extracted = await FlutterRar.extract(
        rarFilePath: rarFile.path,
        destinationPath: destination.path,
        password: 'secret',
      );
      expect(extracted.success, isTrue, reason: extracted.message);
      expect(extracted.destinationPath, destination.path);
      expect(await rarFile.exists(), isTrue);

      for (final entry in _expected.entries) {
        final match = extracted.entries.where((item) => item.name == entry.key).single;
        expect(match.extractedPath, endsWith(entry.key));
        expect(match.isEncrypted, isTrue);
        expect(await File(match.extractedPath).readAsString(), entry.value);
      }

      final one = await FlutterRar.extractFile(
        rarFilePath: rarFile.path,
        destinationPath: '${directory.path}/one',
        entryName: 'hello.txt',
        password: 'secret',
      );
      expect(one.success, isTrue, reason: one.message);
      expect(one.locations, hasLength(1));
      expect(await File(one.locations.single).readAsString(), _expected['hello.txt']);

      final bytes = await FlutterRar.readEntry(
        rarFilePath: rarFile.path,
        entryName: 'nested/notes.txt',
        password: 'secret',
      );
      expect(bytes.success, isTrue, reason: bytes.message);
      expect(utf8.decode(bytes.bytes), _expected['nested/notes.txt']);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
