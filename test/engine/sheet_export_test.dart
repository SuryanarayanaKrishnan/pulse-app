import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/sheet_export.dart';
import 'package:pulse/core/engine/sheet_import.dart';

void main() {
  final txRows = <List<Cell>>[
    ['Date', 'Description', 'Category', 'Amount (AED)', 'Type', 'Notes'],
    [
      '2026-11-25',
      'Regeny EV charging',
      'Transport',
      14.85,
      'Expense',
      'a "quoted", note',
    ],
    ['2026-11-24', 'Salary', 'Salary', 18000, 'Income', ''],
    [
      '2026-11-23',
      '=HYPERLINK("x")',
      'Shopping',
      120.5,
      'Expense',
      'émoji ☕ ok',
    ],
  ];

  test('csv quotes, escapes and neutralises formulas, with a BOM', () {
    final csv = buildCsv(txRows);
    expect(csv.startsWith('﻿'), isTrue);
    expect(csv, contains('"a ""quoted"", note"'));
    expect(csv, contains("'=HYPERLINK"));
    expect(csv, contains('14.85'));
    expect(parseCsv(csv).length, 4);
  });

  test(
    'xlsx opens with the importer: sheets, header, numbers and text survive',
    () {
      final bytes = buildXlsx([
        SheetTable('Budget', [
          ['Category', 'Monthly budget (AED)'],
          ['Groceries', 2000],
          ['Dining', 800.5],
        ]),
        SheetTable('Transactions', txRows),
      ]);
      final sheets = readXlsx(bytes);
      expect(sheets.keys, ['Budget', 'Transactions']);
      expect(sheets['Transactions']![1], [
        '2026-11-25',
        'Regeny EV charging',
        'Transport',
        '14.85',
        'Expense',
        'a "quoted", note',
      ]);
      expect(sheets['Transactions']![3][5], 'émoji ☕ ok');
      expect(sheets['Budget']![2][1], '800.5');
    },
  );

  test('an exported ledger imports back as the same payments', () {
    final a = analyzeSheets(
      readXlsx(buildXlsx([SheetTable('Transactions', txRows)])),
    );
    expect(a.transactions, hasLength(3));
    final regeny = a.transactions.firstWhere((t) => t.label.contains('Regeny'));
    expect(regeny.minor, 1485);
    expect(regeny.isIncome, isFalse);
    expect(
      a.transactions.firstWhere((t) => t.label == 'Salary').isIncome,
      isTrue,
    );
  });

  test('a budget table imports back as monthly budgets', () {
    final a = analyzeSheets(
      readXlsx(
        buildXlsx([
          SheetTable('Budget', [
            [
              'Category',
              'Monthly budget (AED)',
              'Spent this month (AED)',
              'Remaining (AED)',
            ],
            ['Groceries', 2000, 1500, 500],
            ['Dining', 800.5, 100, 700.5],
          ]),
        ]),
      ),
    );
    expect(
      a.labels.values.map((l) => l.label),
      containsAll(['Groceries', 'Dining']),
    );
    final g = a.labels.values.firstWhere((l) => l.label == 'Groceries');
    expect(g.budget.values.single, 200000);
  });

  test(
    'sheet names are made safe and unique; empty input still gives a workbook',
    () {
      final names = readXlsx(
        buildXlsx([
          SheetTable('A/B:C', [
            ['x'],
          ]),
          SheetTable('a b c', [
            ['y'],
          ]),
        ]),
      ).keys.toList();
      expect(names.toSet().length, 2);
      expect(readXlsx(buildXlsx([])).keys, ['Sheet1']);
      expect(utf8.encode('☕'), isNotEmpty);
    },
  );
}
