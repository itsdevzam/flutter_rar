/// One line in the example app's platform check.
class RarCheck {
  const RarCheck({
    required this.name,
    required this.passed,
    required this.detail,
  });

  final String name;
  final bool passed;
  final String detail;
}
