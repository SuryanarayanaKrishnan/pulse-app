import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/sheet_import.dart';

String fx(String n) => File('test/fixtures/sheets/$n').readAsStringSync();

void main() {
  group('amounts', () {
    test('formats seen in sheets', () {
      expect(parseAmountMinor('2,200.00'), 220000);
      expect(parseAmountMinor('AED 1,200'), 120000);
      expect(parseAmountMinor('(120)'), -12000);
      expect(parseAmountMinor('-45.5'), -4550);
      expect(parseAmountMinor('1.234,50'), 123450);
      expect(parseAmountMinor('12,50'), 1250);
      expect(parseAmountMinor('1,234,567'), 123456700);
      expect(parseAmountMinor('abc'), isNull);
      expect(parseAmountMinor(''), isNull);
    });
  });

  group('dates', () {
    test('formats', () {
      expect(parseDateCell('2026-08-05'), DateTime(2026, 8, 5));
      expect(parseDateCell('5 Aug 2026'), DateTime(2026, 8, 5));
      expect(parseDateCell('Aug 5, 2026'), DateTime(2026, 8, 5));
      expect(parseDateCell('03/04/2026', dayFirst: true), DateTime(2026, 4, 3));
      expect(
        parseDateCell('03/04/2026', dayFirst: false),
        DateTime(2026, 3, 4),
      );
      expect(parseDateCell('46239'), DateTime(2026, 8, 5));
      expect(parseDateCell('hello'), isNull);
      expect(parseDateCell('31/02/2026'), isNull);
    });
    test('day first is detected from the data', () {
      expect(detectDayFirst(['13/02/2026', '01/02/2026']), isTrue);
      expect(detectDayFirst(['02/13/2026', '01/02/2026']), isFalse);
      expect(detectDayFirst(['01/02/2026']), isTrue);
    });
  });

  test('csv quotes, delimiters and BOM', () {
    expect(parseCsv('﻿a,b\n"x, y","say ""hi"""\r\n'), [
      ['a', 'b'],
      ['x, y', 'say "hi"'],
    ]);
    expect(parseCsv('a;b\n1;2'), [
      ['a', 'b'],
      ['1', '2'],
    ]);
  });

  group('matching', () {
    test('known words map to Pulse categories', () {
      expect(matchCategory('Groceries')?.id, 'groceries');
      expect(matchCategory('DEWA')?.id, 'utilities');
      expect(matchCategory('Salik & cleaning')?.id, 'transport');
      expect(matchCategory('Car loan')?.id, 'car_loan');
      expect(matchCategory('Cell Phone')?.id, 'telecom');
      expect(matchCategory('Dining & Delivery')?.exact, isTrue);
      expect(matchCategory('Gifts for Mum')?.id, 'shopping');
      expect(matchCategory('Quantum flux'), isNull);
    });
    test('income labels only map to income categories', () {
      expect(matchCategory('Salary', income: true)?.id, 'salary');
      expect(matchCategory('Bonus', income: true)?.id, 'other_income');
      expect(matchCategory('Groceries', income: true)?.id, 'other_income');
      expect(matchCategory('Salary'), isNotNull);
    });
  });

  group('grid sheet', () {
    final a = analyzeCsv(fx('budget_grid.csv'));
    test('detected, year read from the sheet', () {
      expect(a.kinds, {SheetKind.monthlyGrid});
      expect(
        a.labels.keys,
        containsAll([
          'salary',
          'rent',
          'car loan',
          'groceries',
          'parking',
          'overall fun',
        ]),
      );
      expect(a.labels.containsKey('total'), isFalse);
    });
    test('budget and actual rows read per month; groups carry down', () {
      final loan = a.labels['car loan']!;
      expect(loan.group, 'FIXED');
      expect(loan.budget['2026-01-01'], 90000);
      expect(loan.budget['2026-12-01'], 120000);
      expect(loan.actual['2026-09-01'], 120000);
      expect(a.labels['parking']!.group, 'FIXED VARIABLE');
    });
    test('income recognised from its group', () {
      expect(a.labels['salary']!.isIncome, isTrue);
      expect(a.labels['rent']!.isIncome, isFalse);
    });
    test(
      'history months counted from actuals',
      () => expect(a.historyMonths, 3),
    );
  });

  group('ledger', () {
    final a = analyzeCsv(fx('ledger.csv'));
    test('rows become dated payments; month-first dates detected', () {
      expect(a.kinds, {SheetKind.ledger});
      expect(a.transactions, hasLength(4));
      final g = a.transactions.firstWhere((t) => t.label == 'Groceries');
      expect(g.date, DateTime(2026, 8, 9));
      expect(g.minor, 123450);
      expect(g.note, 'weekly shop');
    });
    test('rows with no amount are reported, not dropped silently', () {
      expect(a.warnings.single, contains('1 rows'));
    });
    test('salary row is income', () {
      expect(
        a.transactions.firstWhere((t) => t.label == 'Salary').isIncome,
        isTrue,
      );
    });
  });

  test(
    'a workbook with a grid and a ledger prefers the ledger for history',
    () {
      final a = analyzeSheets({
        'Budget': parseCsv(fx('budget_grid.csv')),
        'Ledger': parseCsv(fx('ledger.csv')),
      });
      expect(a.kinds, {SheetKind.monthlyGrid, SheetKind.ledger});
      expect(a.labels['groceries']!.budget['2026-03-01'], 60000);
      expect(a.labels['groceries']!.actual, isEmpty);
      expect(a.labels['groceries']!.txCount, 1);
    },
  );

  test('flat list becomes this month\'s budget', () {
    final a = analyzeCsv(
      'Category,Budget\nGroceries,800\nRent,"3,000"\nTotal,3800\n',
    );
    expect(a.kinds, {SheetKind.flatList});
    expect(a.labels.keys, ['groceries', 'rent']);
    expect(a.labels['rent']!.budget.values.single, 300000);
  });

  test('nothing useful gives a warning, not a crash', () {
    final a = analyzeCsv('hello\nworld\n');
    expect(a.isEmpty, isTrue);
    expect(a.warnings, isNotEmpty);
  });

  group('xlsx', () {
    Uint8List book() {
      final z = Archive();
      void add(String n, String c) => z.addFile(ArchiveFile.string(n, c));
      add(
        'xl/workbook.xml',
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Plan" sheetId="1" r:id="rId1"/><sheet name="Hidden" sheetId="2" state="hidden" r:id="rId2"/></sheets></workbook>',
      );
      add(
        'xl/_rels/workbook.xml.rels',
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Target="worksheets/sheet2.xml"/></Relationships>',
      );
      add(
        'xl/sharedStrings.xml',
        '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>Category</t></si><si><t>Budget</t></si><si><t>Groceries</t></si><si><t>Rent</t></si></sst>',
      );
      add(
        'xl/worksheets/sheet1.xml',
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
            '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>'
            '<row r="2"><c r="A2" t="s"><v>2</v></c><c r="B2"><v>800</v></c></row>'
            '<row r="3"><c r="A3" t="s"><v>3</v></c><c r="B3"><f>1500+1500</f><v>3000</v></c></row>'
            '</sheetData></worksheet>',
      );
      add(
        'xl/worksheets/sheet2.xml',
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData/></worksheet>',
      );
      return Uint8List.fromList(ZipEncoder().encode(z));
    }

    test('reads shared strings, formulas as values, skips hidden sheets', () {
      final sheets = readXlsx(book());
      expect(sheets.keys, ['Plan']);
      expect(sheets['Plan']![2], ['Rent', '3000']);
      final a = analyzeSheets(sheets);
      expect(a.labels['rent']!.budget.values.single, 300000);
    });
    test('not a workbook', () {
      expect(
        () => readXlsx(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });
  });
}
