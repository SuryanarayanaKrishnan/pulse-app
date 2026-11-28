import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/sms_parser.dart';
import 'package:pulse/core/engine/types.dart';
import 'package:pulse/core/packs/parser_rules.dart';
import 'package:pulse/core/packs/tips.dart';

void main() {
  const text =
      'Dear customer, Dhs 42.50 was settled via your ENBD wallet ending 1234 towards Spinneys';

  ParserRegistry fresh() => buildDefaultRegistry();

  test('a wording the app does not know is read once the pack teaches it', () {
    final reg = fresh();
    expect(reg.parse(text, institution: 'enbd'), isNull);
    final n = applyParserRules(reg, {
      'version': 2,
      'sms': [
        {
          'institution': 'enbd',
          'direction': 'debit',
          'pattern':
              r'{AMT} was settled via your enbd wallet ending {L4} towards {M}',
        },
      ],
    });
    expect(n, 1);
    final p = reg.parse(text, institution: 'enbd')!;
    expect(p.amountMinor, 4250);
    expect(p.last4, '1234');
    expect(p.merchantRaw, 'Spinneys');
    expect(p.direction, Direction.debit);
  });

  test('applying again replaces earlier rules; an empty pack clears them', () {
    final reg = fresh();
    applyParserRules(reg, {
      'sms': [
        {
          'institution': 'enbd',
          'pattern':
              '{AMT} was settled via your enbd wallet ending {L4} towards {M}',
        },
      ],
    });
    expect(reg.parse(text, institution: 'enbd'), isNotNull);
    applyParserRules(reg, {'version': 3, 'sms': []});
    expect(reg.parse(text, institution: 'enbd'), isNull);
  });

  test('bad rules are skipped, never thrown', () {
    final reg = fresh();
    final n = applyParserRules(reg, {
      'sms': [
        'nonsense',
        {'institution': 'enbd'},
        {'institution': 'enbd', 'pattern': 'no amount placeholder'},
        {'institution': 'enbd', 'pattern': '{AMT} ((unclosed'},
        {'institution': 'no-such-bank', 'pattern': '{AMT} x'},
      ],
    });
    expect(n, 0);
    expect(applyParserRules(reg, null), 0);
  });

  test('OTP messages are still dropped when a rule would match them', () {
    final reg = fresh();
    applyParserRules(reg, {
      'sms': [
        {'institution': 'enbd', 'pattern': '{AMT} otp {M}'},
      ],
    });
    expect(
      reg.parse('AED 10 OTP 123456 do not share', institution: 'enbd'),
      isNull,
    );
  });

  test('tips: valid entries kept, malformed and non-https links dropped', () {
    final tips = tipsFromPack({
      'version': 2,
      'items': [
        {
          'id': 'a',
          'title': 'Annual fee changed',
          'body': 'Card X now AED 300',
          'audience': 'all',
          'url': 'https://example.com/x',
        },
        {
          'id': 'b',
          'title': 'Plain',
          'body': 'No link',
          'url': 'javascript:alert(1)',
        },
        {'id': 'c', 'title': 'Other audience', 'body': 'x', 'audience': 'plus'},
        {'title': 'no id', 'body': 'x'},
        42,
      ],
    });
    expect(tips.map((t) => t.id), ['a', 'b']);
    expect(tips[0].url, 'https://example.com/x');
    expect(tips[1].url, isNull);
    expect(tipsFromPack(null), isEmpty);
  });
}
