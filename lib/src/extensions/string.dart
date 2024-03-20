extension StringExtension on String {
  bool isNotExclude(List<String> excludePaths) =>
      !excludePaths.any((path) => contains(path));
}
