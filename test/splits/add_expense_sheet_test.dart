import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/mock_repository.dart';

void main() {
  test('a new group never reuses the id of an existing one', () async {
    final repo = MockPulseRepository(latency: Duration.zero);
    final seeded = (await repo.splitGroups()).map((g) => g.id).toSet();
    for (var i = 0; i < 5; i++) {
      final g = await repo.createSplitGroup(name: 'New $i');
      expect(seeded.add(g.id), isTrue, reason: 'id ${g.id} was reused');
    }
  });

  test('sample data has no made-up groups unless seeded', () async {
    final repo = MockPulseRepository(latency: Duration.zero, seedGroups: false);
    expect(await repo.splitGroups(), isEmpty);
  });
}
