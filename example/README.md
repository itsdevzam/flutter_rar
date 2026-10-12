# flutter_rar example

Separate demo app for the `flutter_rar` package. It is not BookNest.

On launch it runs a password-protected RAR5 archive through list, extract, wrong-password, single-file extract, read, checksum test, and the unsupported create call. Web runs the checks that a browser can do: list bytes, read one entry, and reject creation.

```bash
cd example
flutter run
```
