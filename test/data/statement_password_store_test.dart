import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/statement_password_store.dart';
import 'package:pulse/data/statements.dart';

void main() {
  test(
    'saves per bank, lists without exposing the password, removes',
    () async {
      final store = MemoryStatementPasswordStore();
      expect(await store.saved(), isEmpty);
      await store.save('fab', 'pw-example');
      await store.save('enbd', 'pw-other');
      final saved = await store.saved();
      expect(saved.map((p) => p.institution), ['enbd', 'fab']);
      expect(await store.read('fab'), 'pw-example');
      await store.save('fab', 'pw-new');
      expect(await store.read('fab'), 'pw-new');
      await store.remove('fab');
      expect(await store.read('fab'), isNull);
      expect((await store.saved()).single.institution, 'enbd');
    },
  );

  test('bank hint is specific for FAB and generic otherwise', () {
    expect(statementPasswordHint('fab'), contains('birth year'));
    expect(statementPasswordHint('fab'), contains('last 4 digits'));
    expect(statementPasswordHint('mashreq'), contains('statement email'));
    expect(statementPasswordHint(null), contains('statement email'));
  });
}
