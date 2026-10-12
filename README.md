# flutter_rar

List a RAR archive, extract it, and get the path of every file that was written.

Password-protected RAR4 and RAR5 are supported, including encrypted headers (`rar -hp`). Android, iOS, macOS, Linux, and Windows decode with **native UnRAR**, so a large encrypted archive stays fast. Web lists an archive and reads entry bytes in Dart, because a browser has no native UnRAR library here.

## Native engines

| Platform | Decoder | Extract into a folder |
| --- | --- | --- |
| Android | Official UnRAR, compiled into the app | Yes |
| iOS | [UnrarKit](https://github.com/abbeycode/UnrarKit), the same official UnRAR library | Yes |
| macOS, Linux, Windows | Official UnRAR, compiled into the app | Yes |
| Web | [`koni_rar`](https://pub.dev/packages/koni_rar) (pure Dart) | No. Use `listBytes` and `readEntry` |

`FlutterRar.canExtractToDirectory` is `true` on Android, iOS, and desktop, and `false` on web.

Creating a `.rar` file is not supported. The RAR compression algorithm is proprietary. This package only decompresses.

## Install

```yaml
dependencies:
  flutter_rar: ^0.2.0
```

## Functions

| Function | What it does | Returns |
| --- | --- | --- |
| `listContents` | Lists every entry in a `.rar` file on disk | `RarResult` |
| `listBytes` | Lists an in-memory archive. This is the web entry point | `RarResult` |
| `extract` | Writes the archive into a folder and returns each written path | `RarResult` |
| `extractFile` | Writes one archive path into a folder | `RarResult` |
| `readEntry` | Returns the decoded bytes of one entry | `RarFileBytes` |
| `test` | Decodes every file and checks its checksum, without writing | `RarResult` |
| `create` | Always fails. Nothing is written | `RarResult` |
| `canExtractToDirectory` | Whether this platform can write extracted files | `bool` |

`password` is required when the archive uses encrypted headers. Omit it when the archive is not encrypted. A wrong password comes back as `success: false` and a message that contains `password`.

The original `.rar` file is left in place. Delete it yourself after a successful extract if you want it gone.

Paths that are absolute or contain `..` are not written. Those entries come back with `skipped: true`.

Multi-volume archives are not supported. Passing `nextVolumePath` returns a failure.

## Extract

```dart
final result = await FlutterRar.extract(
  rarFilePath: '/path/book.rar',
  destinationPath: '/path/books',
  password: 'secret',
);

if (result.success) {
  for (final entry in result.entries) {
    if (entry.isDirectory || entry.extractedPath.isEmpty) continue;
    print('${entry.name} -> ${entry.extractedPath}');
  }
}
```

`result.locations` is the same list of absolute paths.

## Extract one file

```dart
final one = await FlutterRar.extractFile(
  rarFilePath: '/path/book.rar',
  destinationPath: '/path/books',
  entryName: 'chapter1.pdf',
  password: 'secret',
);
```

## List

```dart
final listed = await FlutterRar.listContents(
  rarFilePath: '/path/book.rar',
  password: 'secret',
);

for (final entry in listed.entries) {
  print('${entry.name}  ${entry.uncompressedSize} bytes  encrypted=${entry.isEncrypted}');
}
```

On web, read the file the user picked and pass the bytes:

```dart
final listed = await FlutterRar.listBytes(bytes: data, password: 'secret');
```

## Read one entry

Phone and desktop can pass a path. Web must pass bytes.

```dart
final file = await FlutterRar.readEntry(
  rarFilePath: '/path/book.rar',
  entryName: 'notes.txt',
  password: 'secret',
);

final fromBytes = await FlutterRar.readEntry(
  bytes: data,
  entryName: 'notes.txt',
  password: 'secret',
);
```

`file.bytes` is the decoded content when `file.success` is true.

## Test

```dart
final tested = await FlutterRar.test(
  rarFilePath: '/path/book.rar',
  password: 'secret',
);
```

This checks checksums and does not write files.

## What you get back

`RarResult` has `success`, `message`, `rarVersion` (`RAR4` or `RAR5`), `isEncrypted`, `destinationPath`, and `entries`.

Each `RarEntry` has:

- `name` — path inside the archive
- `extractedPath` — absolute path after extract, empty for list and test
- `isDirectory`, `isFile`, `skipped`
- `uncompressedSize`, `compressedSize`
- `isEncrypted`, `compression`
- `modifiedAt`, `crc32`

`RarFileBytes` has `success`, `message`, `name`, and `bytes`.

## What you still provide

- The password, if the archive has one. This package does not guess it.
- A destination directory your app is allowed to write.
- Whether to delete the `.rar` after a successful extract.
- A viewer for the extracted file (for example a PDF widget).
- On web, the archive bytes. Browsers do not give this package a folder to extract into.

The `example/` app runs these calls against a small password-protected RAR5 archive and shows what passed on the current platform.
