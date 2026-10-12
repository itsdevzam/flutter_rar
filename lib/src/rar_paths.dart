import 'package:path/path.dart' as p;

/// Joins [destination] and an archive-relative [entryPath].
///
/// Returns null when the entry is absolute, contains `..`, or would resolve
/// outside [destination].
String? safeDestinationPath(String destination, String entryPath) {
  if (entryPath.isEmpty) return null;
  final raw = entryPath.replaceAll('\\', '/');
  if (raw.startsWith('/')) return null;
  if (raw.length >= 2 && raw[1] == ':') return null;
  if (raw.split('/').contains('..')) return null;

  final root = p.normalize(destination);
  final full = p.normalize(p.join(root, raw));
  if (full != root && !p.isWithin(root, full)) return null;
  return full;
}
