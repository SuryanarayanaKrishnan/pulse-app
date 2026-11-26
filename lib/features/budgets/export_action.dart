import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart'
    show ScaffoldMessenger, SnackBar, SnackBarBehavior;
import 'package:share_plus/share_plus.dart';

import '../../data/providers.dart';
import '../../data/spreadsheet_export.dart';

enum ExportFormat { xlsx, csv }

/// "Export to Excel or CSV": the month's budget (every column) and all
/// payments, handed to the share sheet (Files, Drive, Sheets, Mail...).
Future<void> exportSpreadsheet(
  BuildContext context,
  WidgetRef ref,
  ExportFormat format,
) async {
  try {
    final plan = await ref.read(budgetPlanProvider.future);
    final cats = await ref.read(categoriesProvider.future);
    final txs = await ref.read(repositoryProvider).transactions();
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final List<XFile> files;
    if (format == ExportFormat.xlsx) {
      files = [
        XFile.fromData(
          SpreadsheetExport.xlsx(plan, cats, txs),
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: 'pulse-$stamp.xlsx',
        ),
      ];
    } else {
      Uint8List utf8Bytes(String s) => Uint8List.fromList(utf8.encode(s));
      files = [
        XFile.fromData(
          utf8Bytes(SpreadsheetExport.budgetCsv(plan, cats)),
          mimeType: 'text/csv',
          name: 'pulse-budget-$stamp.csv',
        ),
        XFile.fromData(
          utf8Bytes(SpreadsheetExport.transactionsCsv(txs)),
          mimeType: 'text/csv',
          name: 'pulse-transactions-$stamp.csv',
        ),
      ];
    }
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        fileNameOverrides: [for (final f in files) f.name],
        subject: 'Pulse export',
      ),
    );
  } catch (e) {
    debugPrint('Export failed: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not create the file. Try again in a moment.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}
