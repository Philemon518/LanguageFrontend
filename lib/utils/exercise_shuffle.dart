import 'dart:math';

List<Map<String, dynamic>> shuffleExerciseOptions(
  List<Map<String, dynamic>> options, [
  Random? random,
]) {
  final copy = options.map((option) => Map<String, dynamic>.from(option)).toList();
  copy.shuffle(random ?? Random());
  return copy;
}
