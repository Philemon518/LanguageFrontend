import 'dart:math';

import 'package:canto_mobile/utils/exercise_shuffle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shuffleExerciseOptions preserves ids without mutating input', () {
    final options = [
      {'id': 'correct', 'label': 'correct answer'},
      {'id': 'wrong-1', 'label': 'wrong one'},
      {'id': 'wrong-2', 'label': 'another wrong'},
    ];
    final originalOrder = options.map((option) => option['id']).toList();

    final shuffled = shuffleExerciseOptions(options, Random(17));

    expect(options.map((option) => option['id']).toList(), originalOrder);
    expect(shuffled.length, options.length);
    expect(
      shuffled.map((option) => option['id']).toSet(),
      {'correct', 'wrong-1', 'wrong-2'},
    );
    expect(
      shuffled.map((option) => option['id']).toList(),
      isNot(originalOrder),
    );
  });
}
