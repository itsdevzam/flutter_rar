/// Returns `RAR4`, `RAR5`, `RAR15`, or an empty string when [bytes] is not a
/// RAR signature.
String detectRarVersion(List<int> bytes) {
  if (bytes.length >= 7 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x61 &&
      bytes[2] == 0x72 &&
      bytes[3] == 0x21 &&
      bytes[4] == 0x1A &&
      bytes[5] == 0x07) {
    if (bytes[6] == 0x00) return 'RAR4';
    if (bytes.length >= 8 && bytes[6] == 0x01 && bytes[7] == 0x00) {
      return 'RAR5';
    }
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x45 &&
      bytes[2] == 0x7E &&
      bytes[3] == 0x5E) {
    return 'RAR15';
  }
  return '';
}
