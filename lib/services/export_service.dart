import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class ExportService {
  static Future<String?> _getExportPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create();
    }
    return exportDir.path;
  }

  static Future<String?> exportToCSV(List<Transaction> transactions) async {
    try {
      final path = await _getExportPath();
      if (path == null) return null;

      final csvData = [
        ['Title', 'Amount', 'Date', 'Category', 'Type', 'Description'],
        ...transactions.map((t) => [
          t.title,
          t.amount,
          DateFormat('yyyy-MM-dd').format(t.date),
          t.category,
          t.isIncome ? 'Income' : 'Expense',
          t.description ?? ''
        ])
      ];

      final csv = const ListToCsvConverter().convert(csvData);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '$path/transactions_$timestamp.csv';

      await File(filePath).writeAsString(csv);
      return filePath;
    } catch (e) {
      debugPrint('CSV export error: $e');
      return null;
    }
  }

  static Future<String?> exportToPDF(List<Transaction> transactions) async {
    try {
      final path = await _getExportPath();
      if (path == null) return null;

      final pdf = pw.Document();
      final dateFormat = DateFormat('yyyy-MM-dd');
      final currencyFormat = NumberFormat.currency(symbol: '\$');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                    level: 0,
                    text: 'Transaction History',
                    margin: const pw.EdgeInsets.only(bottom: 20)),
                pw.TableHelper.fromTextArray(
                  headers: ['Date', 'Description', 'Category', 'Amount'],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  data: transactions.map((t) => [
                    dateFormat.format(t.date),
                    t.title,
                    t.category,
                    '${t.isIncome ? '+' : '-'}${currencyFormat.format(t.amount)}',
                  ]).toList(),
                  cellPadding: const pw.EdgeInsets.all(4),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Income: ${currencyFormat.format(
                      transactions.where((t) => t.isIncome).fold(0.0, (sum, t) => sum + t.amount),
                    )}'),
                    pw.Text('Total Expense: ${currencyFormat.format(
                      transactions.where((t) => !t.isIncome).fold(0.0, (sum, t) => sum + t.amount),
                    )}'),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                    'Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            );
          },
        ),
      );

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '$path/transactions_$timestamp.pdf';
      await File(filePath).writeAsBytes(await pdf.save());
      return filePath;
    } catch (e) {
      debugPrint('PDF export error: $e');
      return null;
    }
  }
}