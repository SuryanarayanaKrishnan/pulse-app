import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/cashflow.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/dues.dart';
import 'package:pulse/core/engine/health.dart';
import 'package:pulse/core/engine/networth.dart';
import 'package:pulse/core/engine/recurring.dart';
import 'package:pulse/core/engine/salary.dart';
import 'package:pulse/core/engine/types.dart';

import 'fixtures.dart';

CalDate d(Object? s) => CalDate.parse((s! as String).substring(0, 10));
CalDate? dn(Object? s) => s == null ? null : d(s);
Map<String, Object?> mp(Object? o) => Map<String, Object?>.from(o! as Map);
double num_(Object? v) => double.parse('$v');

void main() {
  final fx = mp(loadFixture('insights.json'));

  group('recurring (Python parity)', () {
    for (final raw in loadFixture('recurring.json')! as List) {
      final sc = mp(raw);
      test(sc['name']! as String, () {
        final today = d(sc['today']);
        final charges = [
          for (final c in sc['charges']! as List)
            () {
              final m = mp(c);
              return Charge(d(m['posted_on']), m['amount_minor']! as int, m['merchant']! as String, m['key']! as String, m['category_slug'] as String?);
            }(),
        ];
        final got = detect(charges, today);
        final exp = sc['series']! as List;
        expect(got.length, exp.length);
        for (var i = 0; i < got.length; i++) {
          final s = got[i];
          final e = mp(exp[i]);
          expect(s.key, e['key']);
          expect(s.merchant, e['merchant']);
          expect(s.cadence, e['cadence']);
          expect(s.intervalDays, e['interval_days']);
          expect(s.amountKind, e['amount_kind']);
          expect(s.typicalAmountMinor, e['typical_amount_minor']);
          expect(s.lastAmountMinor, e['last_amount_minor']);
          expect(s.lastChargeOn, d(e['last_charge_on']));
          expect(s.nextExpectedOn, d(e['next_expected_on']));
          expect(s.occurrences, e['occurrences']);
          expect(s.firstChargeOn, d(e['first_charge_on']));
          expect(s.categorySlug, e['category_slug']);
          expect(s.isSubscription, e['is_subscription']);
          expect(s.status, e['status']);
          expect(s.anchorDay, e['anchor_day']);
          expect(s.flags, e['flags']);
          final pi = e['price_increase'] == null ? null : mp(e['price_increase']);
          expect(s.priceIncrease == null, pi == null);
          if (pi != null) {
            expect(s.priceIncrease!.fromMinor, pi['from_minor']);
            expect(s.priceIncrease!.toMinor, pi['to_minor']);
            expect(s.priceIncrease!.increaseMinor, pi['increase_minor']);
            expect(s.priceIncrease!.pct, closeTo(num_(pi['pct']), 1e-9));
          }
          expect(forgotten(s, reviewed: false), e['forgotten']);
          expect(forgotten(s, reviewed: true), e['forgotten_reviewed']);
          expect(monthlyCostMinor(s), e['monthly_cost_minor']);
          expect(
            [for (final x in occurrencesBetween(s, today, today.addDays(100))) x.toIso()],
            [for (final x in e['occurrences_between']! as List) x],
          );
        }
      });
    }
    test('fixture covers the interesting cases', () {
      final names = [for (final r in loadFixture('recurring.json')! as List) mp(r)['name']];
      expect(names, containsAll(['netflix_steady', 'spotify_increase', 'lapsed', 'month_end', 'weekly']));
    });
  });

  group('card dues (Python parity)', () {
    for (final (i, raw) in (fx['dues']! as List).indexed) {
      test('case $i', () {
        final m = mp(raw);
        final inp = mp(m['input']);
        final got = cardDue(
          CardInput(
            accountId: inp['account_id']! as String,
            name: inp['name']! as String,
            last4: inp['last4'] as String?,
            creditLimitMinor: inp['credit_limit_minor'] as int?,
            dueDay: inp['due_day'] as int?,
            statementDate: dn(inp['statement_date']),
            dueDate: dn(inp['due_date']),
            minDueMinor: inp['min_due_minor'] as int?,
            totalDueMinor: inp['total_due_minor'] as int?,
            paidSinceStatementMinor: inp['paid_since_statement_minor']! as int,
            owedNowMinor: inp['owed_now_minor'] as int?,
          ),
          d(m['today']),
        );
        final e = mp(m['output']);
        expect(got.source, e['source']);
        expect(got.dueDate, dn(e['due_date']));
        expect(got.daysLeft, e['days_left']);
        expect(got.status, e['status']);
        expect(got.minimumDueMinor, e['minimum_due_minor']);
        expect(got.totalDueMinor, e['total_due_minor']);
        expect(got.remainingMinimumDueMinor, e['remaining_minimum_due_minor']);
        expect(got.remainingTotalDueMinor, e['remaining_total_due_minor']);
        expect(got.utilisationPct, e['utilisation_pct'] == null ? isNull : closeTo(num_(e['utilisation_pct']), 1e-9));
        expect(got.availableCreditMinor, e['available_credit_minor']);
        final nudges = [for (final n in e['nudges']! as List) mp(n)];
        expect([for (final n in got.nudges) n.level], [for (final n in nudges) n['level']]);
        expect([for (final n in got.nudges) n.message], [for (final n in nudges) n['message']]);
      });
    }
    test('due day rolls to next month and clamps', () {
      for (final raw in fx['next_due']! as List) {
        final m = mp(raw);
        expect(nextDueFromDay(d(m['today']), m['day']! as int), d(m['out']));
      }
    });
  });

  group('cashflow, projection, safe to spend (Python parity)', () {
    test('monthly cashflow excludes transfers, card payments and savings', () {
      final c = mp(fx['cashflow']);
      final flows = [
        for (final f in c['flows']! as List)
          () {
            final m = mp(f);
            return Flow(d(m['day']), m['amount_minor']! as int, isCredit: m['is_credit']! as bool, slug: m['slug'] as String?, excluded: m['excluded']! as bool);
          }(),
      ];
      final got = monthlyCashflow(flows, d(c['today']), c['months']! as int);
      final exp = c['out']! as List;
      expect(got.length, exp.length);
      for (var i = 0; i < got.length; i++) {
        final e = mp(exp[i]);
        expect(got[i].month, d(e['month']));
        expect((got[i].incomeMinor, got[i].spendMinor, got[i].savedMinor, got[i].netMinor), (e['income'], e['spend'], e['saved'], e['net']));
        expect(got[i].savingsRate, e['rate'] == null ? isNull : closeTo(num_(e['rate']), 1e-9));
      }
      for (final raw in c['months_back']! as List) {
        final m = mp(raw);
        expect([for (final x in monthsBack(d(m['today']), m['n']! as int)) x.toIso()], [for (final x in m['out']! as List) (x as String).substring(0, 10)]);
      }
    });
    test('projection applies daily spend then events', () {
      final p = mp(fx['projection']);
      final events = [
        for (final e in p['events']! as List)
          () {
            final m = mp(e);
            return FlowEvent(d(m['day']), m['label']! as String, m['amount_minor']! as int, m['kind']! as String);
          }(),
      ];
      final got = projectBalance(p['start']! as int, d(p['today']), p['days']! as int, events, p['daily']! as int);
      final exp = p['out']! as List;
      expect(got.length, exp.length);
      for (var i = 0; i < got.length; i++) {
        final e = mp(exp[i]);
        expect(got[i].day, d(e['day']));
        expect(got[i].balanceMinor, e['balance']);
        expect([for (final x in got[i].events) x.label], e['events']);
      }
    });
    test('safe to spend breakdown and unknown balance', () {
      final items = [
        for (final c in fx['commitments']! as List)
          () {
            final m = mp(c);
            return Commitment(m['kind']! as String, m['label']! as String, m['amount_minor']! as int, dn(m['due_on']));
          }(),
      ];
      for (final raw in fx['safe_to_spend']! as List) {
        final m = mp(raw);
        final got = computeSafeToSpend(m['liquid'] as int?, items, d(m['today']), d(m['end']));
        final e = mp(m['out']);
        expect(got.liquidMinor, e['liquid_minor']);
        expect(got.committedMinor, e['committed_minor']);
        expect(got.safeMinor, e['safe_minor']);
        expect(got.perDayMinor, e['per_day_minor']);
        expect(got.daysLeft, e['days_left']);
        expect(got.status, e['status']);
        expect(got.byKind, mp(e['by_kind']));
      }
    });
    test('goal arithmetic', () {
      for (final raw in fx['goals']! as List) {
        final m = mp(raw);
        final today = d(m['today']);
        final target = dn(m['target']);
        expect(goalMonthsLeft(today, target), m['months_left']);
        expect(requiredMonthly(100000, today, target), m['required_100k']);
        expect(requiredMonthly(0, today, target), m['required_0']);
        expect(monthlyReserve(100000, 30000, today, target), m['reserve_plan']);
        expect(monthlyReserve(10000, 30000, today, target), m['reserve_small']);
        expect(monthlyReserve(100000, null, today, target), m['reserve_none']);
      }
    });
  });

  group('health score (Python parity)', () {
    Map<String, Object?> comp(Component c) => {'score': c.score, 'value': c.value, 'detail': c.detail};
    void same(Component c, Object? exp) {
      final e = mp(exp);
      expect(c.key, e['key']);
      expect(c.weight, e['weight']);
      expect(c.score, e['score']);
      expect(c.value, e['value'] == null ? isNull : closeTo(num_(e['value']), 1e-9));
      expect(c.detail, e['detail'], reason: '${comp(c)}');
    }

    test('components', () {
      final inp = mp(fx['health_inputs']);
      final out = mp(fx['health_components']);
      int? i(Object? v) => (v as num?)?.toInt();
      final sav = out['savings']! as List, util = out['util']! as List, ot = out['ontime']! as List, run = out['runway']! as List;
      for (final (k, x) in (inp['savings']! as List).indexed) {
        same(savingsComponent((x as num?)?.toDouble()), sav[k]);
      }
      for (final (k, x) in (inp['util']! as List).indexed) {
        same(utilisationComponent(i((x as List)[0]), i(x[1])), util[k]);
      }
      for (final (k, x) in (inp['ontime']! as List).indexed) {
        same(onTimeComponent(i((x as List)[0])!, i(x[1])!), ot[k]);
      }
      for (final (k, x) in (inp['runway']! as List).indexed) {
        same(runwayComponent(i((x as List)[0]), i(x[1])), run[k]);
      }
    });
    test('overall renormalises and refuses thin data', () {
      for (final raw in fx['health_overall']! as List) {
        final m = mp(raw);
        final inp = m['input']! as List;
        int? i(Object? v) => (v as num?)?.toInt();
        final h = computeHealth([
          savingsComponent((inp[0] as num?)?.toDouble()),
          utilisationComponent(i((inp[1] as List)[0]), i((inp[1] as List)[1])),
          onTimeComponent(i((inp[2] as List)[0])!, i((inp[2] as List)[1])!),
          runwayComponent(i((inp[3] as List)[0]), i((inp[3] as List)[1])),
        ]);
        expect(h.score, m['score']);
        expect(h.band, m['band']);
        expect(h.coverage, closeTo(num_(m['coverage']), 1e-9));
        expect(h.summary, m['summary']);
      }
    });
  });

  group('net worth (Python parity)', () {
    test('cases', () {
      for (final raw in fx['net_worth']! as List) {
        final m = mp(raw);
        final r = computeNetWorth(
          [for (final a in m['assets']! as List) AssetInput((a as List)[0] as String, a[1] as String, a[2] as int?, a[3] as int?)],
          [for (final l in m['liabilities']! as List) LiabilityInput((l as List)[0] as String, l[1] as String, l[2] as int)],
          fxRates: {for (final e in mp(m['fx']).entries) e.key: num_(e.value)},
        );
        final e = mp(m['out']);
        expect(r.totalAssetsMinor, e['total_assets_minor']);
        expect(r.totalLiabilitiesMinor, e['total_liabilities_minor']);
        expect(r.netWorthMinor, e['net_worth_minor']);
        expect(r.assetsByKind, mp(e['assets_by_kind']));
        expect(r.liabilitiesByKind, mp(e['liabilities_by_kind']));
        expect(r.unconvertedCurrencies, e['unconverted']);
      }
    });
  });

  group('salary (Python parity)', () {
    test('detection', () {
      final cases = fx['salary_detect']! as List;
      expect(cases.length, greaterThan(50));
      for (final raw in cases) {
        final m = mp(raw);
        final got = detectSalary(m['text'] as String?, Direction.tryParse(m['direction'] as String?), m['amount'] as int?, m['sms'] as String?);
        final e = m['out'] == null ? null : mp(m['out']);
        expect(got?.matchedBy, e?['matched_by'], reason: '$m');
        expect(got?.employer, e?['employer'], reason: '$m');
      }
    });
    test('summary', () {
      for (final raw in fx['salary_summary']! as List) {
        final m = mp(raw);
        final s = summariseSalary(
          [
            for (final p in m['payments']! as List)
              () {
                final x = mp(p);
                return SalaryPayment(d(x['received_on']), x['amount_minor']! as int, x['employer'] as String?, x['currency']! as String);
              }(),
          ],
          d(m['today']),
        );
        final e = mp(m['out']);
        expect(s.currency, e['currency']);
        expect(s.monthsObserved, e['months_observed']);
        expect(s.isRecurring, e['is_recurring']);
        expect(s.averageMonthlyMinor, e['average_monthly_minor']);
        expect(s.typicalDay, e['typical_day']);
        expect(s.nextExpectedOn, dn(e['next_expected_on']));
        expect(s.latestMonthMinor, e['latest_month_minor']);
        expect(s.previousMonthMinor, e['previous_month_minor']);
        expect([for (final (a, b) in s.monthly) [a.toIso(), b]], [for (final x in e['monthly']! as List) [(x as List)[0].toString().substring(0, 10), x[1]]]);
        expect([for (final (a, b, c) in s.employers) [a, b, c]], e['employers']);
      }
    });
  });
}
