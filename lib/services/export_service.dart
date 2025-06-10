import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/transaction.dart';

class ExportService {
  
  static Future<bool> exportToCSV(List<Transaction> transactions, {String? customPath}) async {
    try {
      debugPrint('Starting CSV export with ${transactions.length} transactions');
      
      // Create CSV content with proper formatting
      final StringBuffer csvBuffer = StringBuffer();
      csvBuffer.writeln('Date,Title,Category,Type,Amount');
      
      for (final transaction in transactions) {
        final formattedDate = DateFormat('yyyy-MM-dd').format(transaction.date);
        final formattedAmount = transaction.amount.toStringAsFixed(2);
        
        csvBuffer.writeAll([
          '"$formattedDate"',
          '"${transaction.title.replaceAll('"', '""')}"', // Escape quotes
          '"${transaction.category.replaceAll('"', '""')}"',
          transaction.isIncome ? 'Income' : 'Expense',
          formattedAmount
        ], ',');
        csvBuffer.writeln();
      }
      
      final csvContent = csvBuffer.toString();
      debugPrint('CSV content created, length: ${csvContent.length}');
      
      // Generate filename with timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final fileName = 'ExpenseTracker_Transactions_$timestamp.csv';
      
      return await _saveAndShareFile(
        content: csvContent,
        fileName: fileName,
        mimeType: 'text/csv',
        customPath: customPath,
      );
      
    } catch (e, stackTrace) {
      debugPrint('CSV export error: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<bool> exportToPDF(List<Transaction> transactions, {String? customPath}) async {
    try {
      debugPrint('Starting PDF export with ${transactions.length} transactions');
      
      // Calculate summary data
      final totalIncome = transactions.where((t) => t.isIncome).fold(0.0, (sum, t) => sum + t.amount);
      final totalExpense = transactions.where((t) => !t.isIncome).fold(0.0, (sum, t) => sum + t.amount);
      final netAmount = totalIncome - totalExpense;
      
      // Create PDF document
      final pdf = pw.Document();
      
      // Group transactions by category for better organization
      final expensesByCategory = <String, List<Transaction>>{};
      final incomeByCategory = <String, List<Transaction>>{};
      
      for (final transaction in transactions) {
        if (transaction.isIncome) {
          incomeByCategory.putIfAbsent(transaction.category, () => []).add(transaction);
        } else {
          expensesByCategory.putIfAbsent(transaction.category, () => []).add(transaction);
        }
      }
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(width: 2, color: PdfColors.blue)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Financial Report',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Generated: ${DateFormat('MMMM dd, yyyy \'at\' hh:mm a').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Total Transactions: ${transactions.length}',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Summary Section
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Financial Summary',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Income:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                          NumberFormat.currency(symbol: '\$').format(totalIncome),
                          style: const pw.TextStyle(color: PdfColors.green),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Expenses:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                          NumberFormat.currency(symbol: '\$').format(totalExpense),
                          style: const pw.TextStyle(color: PdfColors.red),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(thickness: 1),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Net Amount:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                          NumberFormat.currency(symbol: '\$').format(netAmount),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: netAmount >= 0 ? PdfColors.green : PdfColors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Category Breakdown
              if (expensesByCategory.isNotEmpty) ...[
                pw.Text(
                  'Expense Breakdown by Category',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                ...expensesByCategory.entries.map((entry) {
                  final categoryTotal = entry.value.fold(0.0, (sum, t) => sum + t.amount);
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(entry.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                          '${NumberFormat.currency(symbol: '\$').format(categoryTotal)} (${entry.value.length} transactions)',
                          style: const pw.TextStyle(color: PdfColors.red),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                pw.SizedBox(height: 20),
              ],
              
              // Detailed Transaction List
              pw.Text(
                'Transaction Details',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              
              // Table header
              pw.Container(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 2, child: pw.Container(padding: const pw.EdgeInsets.all(8), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))),
                    pw.Expanded(flex: 3, child: pw.Container(padding: const pw.EdgeInsets.all(8), child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))),
                    pw.Expanded(flex: 2, child: pw.Container(padding: const pw.EdgeInsets.all(8), child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))),
                    pw.Expanded(flex: 2, child: pw.Container(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))),
                  ],
                ),
              ),
              
              // Transaction rows
              ...transactions.asMap().entries.map((entry) {
                final index = entry.key;
                final transaction = entry.value;
                final isEven = index % 2 == 0;
                
                return pw.Container(
                  decoration: pw.BoxDecoration(
                    color: isEven ? PdfColors.grey50 : PdfColors.white,
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 2, child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(DateFormat('MMM dd, yyyy').format(transaction.date), style: const pw.TextStyle(fontSize: 10)),
                      )),
                      pw.Expanded(flex: 3, child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(transaction.title, style: const pw.TextStyle(fontSize: 10)),
                      )),
                      pw.Expanded(flex: 2, child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(transaction.category, style: const pw.TextStyle(fontSize: 10)),
                      )),
                      pw.Expanded(flex: 2, child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '${transaction.isIncome ? '+' : '-'}${NumberFormat.currency(symbol: '\$').format(transaction.amount)}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: transaction.isIncome ? PdfColors.green : PdfColors.red,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      )),
                    ],
                  ),
                );
              }).toList(),
            ];
          },
        ),
      );
      
      // Save PDF
      final bytes = await pdf.save();
      final timestamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final fileName = 'ExpenseTracker_Report_$timestamp.pdf';
      
      return await _saveAndShareFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/pdf',
        customPath: customPath,
      );
      
    } catch (e, stackTrace) {
      debugPrint('PDF export error: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<bool> exportToHTML(List<Transaction> transactions, {String? customPath}) async {
    try {
      debugPrint('Starting HTML export with ${transactions.length} transactions');
      
      // Calculate summary data
      final totalIncome = transactions.where((t) => t.isIncome).fold(0.0, (sum, t) => sum + t.amount);
      final totalExpense = transactions.where((t) => !t.isIncome).fold(0.0, (sum, t) => sum + t.amount);
      final netAmount = totalIncome - totalExpense;
      final currencyFormat = NumberFormat.currency(symbol: '\$');
      
      // Create HTML content with modern styling
      final htmlContent = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Expense Tracker Report</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f5f5f5;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            font-weight: 300;
        }
        
        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        
        .content {
            padding: 30px;
        }
        
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        
        .summary-card {
            background: #f8f9fa;
            padding: 25px;
            border-radius: 10px;
            border-left: 4px solid;
            transition: transform 0.2s;
        }
        
        .summary-card:hover {
            transform: translateY(-2px);
        }
        
        .summary-card.income {
            border-left-color: #28a745;
        }
        
        .summary-card.expense {
            border-left-color: #dc3545;
        }
        
        .summary-card.net {
            border-left-color: #007bff;
        }
        
        .summary-card.net.positive {
            border-left-color: #28a745;
        }
        
        .summary-card.net.negative {
            border-left-color: #dc3545;
        }
        
        .summary-card h3 {
            color: #666;
            font-size: 0.9em;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .summary-card .amount {
            font-size: 2em;
            font-weight: bold;
            color: #333;
        }
        
        .summary-card.income .amount {
            color: #28a745;
        }
        
        .summary-card.expense .amount {
            color: #dc3545;
        }
        
        .summary-card.net.positive .amount {
            color: #28a745;
        }
        
        .summary-card.net.negative .amount {
            color: #dc3545;
        }
        
        .transactions {
            margin-top: 30px;
        }
        
        .section-title {
            font-size: 1.5em;
            margin-bottom: 20px;
            color: #333;
            border-bottom: 2px solid #eee;
            padding-bottom: 10px;
        }
        
        .transaction-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .transaction-table th {
            background: #f8f9fa;
            padding: 15px;
            text-align: left;
            font-weight: 600;
            color: #555;
            border-bottom: 2px solid #dee2e6;
        }
        
        .transaction-table td {
            padding: 12px 15px;
            border-bottom: 1px solid #eee;
        }
        
        .transaction-table tr:hover {
            background: #f8f9fa;
        }
        
        .transaction-table tr:last-child td {
            border-bottom: none;
        }
        
        .amount-positive {
            color: #28a745;
            font-weight: bold;
        }
        
        .amount-negative {
            color: #dc3545;
            font-weight: bold;
        }
        
        .category-badge {
            display: inline-block;
            padding: 4px 8px;
            background: #e9ecef;
            border-radius: 4px;
            font-size: 0.8em;
            color: #495057;
        }
        
        .footer {
            text-align: center;
            padding: 20px;
            color: #666;
            font-size: 0.9em;
            border-top: 1px solid #eee;
            background: #f8f9fa;
        }
        
        @media (max-width: 768px) {
            .container {
                margin: 10px;
                border-radius: 8px;
            }
            
            .header {
                padding: 20px;
            }
            
            .header h1 {
                font-size: 2em;
            }
            
            .content {
                padding: 20px;
            }
            
            .transaction-table {
                font-size: 0.9em;
            }
            
            .transaction-table th,
            .transaction-table td {
                padding: 8px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>💰 Financial Report</h1>
            <p>Generated on ${DateFormat('MMMM dd, yyyy \'at\' hh:mm a').format(DateTime.now())}</p>
            <p>Total Transactions: ${transactions.length}</p>
        </div>
        
        <div class="content">
            <div class="summary">
                <div class="summary-card income">
                    <h3>Total Income</h3>
                    <div class="amount">${currencyFormat.format(totalIncome)}</div>
                </div>
                <div class="summary-card expense">
                    <h3>Total Expenses</h3>
                    <div class="amount">${currencyFormat.format(totalExpense)}</div>
                </div>
                <div class="summary-card net ${netAmount >= 0 ? 'positive' : 'negative'}">
                    <h3>Net Amount</h3>
                    <div class="amount">${currencyFormat.format(netAmount)}</div>
                </div>
            </div>
            
            <div class="transactions">
                <h2 class="section-title">📋 Transaction Details</h2>
                <table class="transaction-table">
                    <thead>
                        <tr>
                            <th>Date</th>
                            <th>Description</th>
                            <th>Category</th>
                            <th>Amount</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${transactions.map((transaction) => '''
                        <tr>
                            <td>${DateFormat('MMM dd, yyyy').format(transaction.date)}</td>
                            <td>${transaction.title}</td>
                            <td><span class="category-badge">${transaction.category}</span></td>
                            <td class="${transaction.isIncome ? 'amount-positive' : 'amount-negative'}">
                                ${transaction.isIncome ? '+' : '-'}${currencyFormat.format(transaction.amount)}
                            </td>
                        </tr>
                        ''').join('')}
                    </tbody>
                </table>
            </div>
        </div>
        
        <div class="footer">
            <p>Generated by Financial App • ${DateFormat('yyyy').format(DateTime.now())}</p>
        </div>
    </div>
</body>
</html>
      ''';
      
      final timestamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final fileName = 'ExpenseTracker_Report_$timestamp.html';
      
      return await _saveAndShareFile(
        content: htmlContent,
        fileName: fileName,
        mimeType: 'text/html',
        customPath: customPath,
      );
      
    } catch (e, stackTrace) {
      debugPrint('HTML export error: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<bool> _saveAndShareFile({
    String? content,
    Uint8List? bytes,
    required String fileName,
    required String mimeType,
    String? customPath,
  }) async {
    try {
      // Determine which content to use
      final fileContent = bytes ?? (content != null ? content.codeUnits : null);
      if (fileContent == null) {
        throw Exception('No content provided for file');
      }
      
      // Try multiple save locations
      List<String> savedPaths = [];
      
      // 1. Try external storage (Downloads folder)
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final downloadsPath = Directory('/storage/emulated/0/Download');
          if (await downloadsPath.exists()) {
            final filePath = '${downloadsPath.path}/$fileName';
            await File(filePath).writeAsBytes(fileContent);
            savedPaths.add(filePath);
            debugPrint('File saved to Downloads: $filePath');
          }
        }
      } catch (e) {
        debugPrint('External storage save failed: $e');
      }
      
      // 2. Try application documents directory
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final filePath = '${appDir.path}/$fileName';
        await File(filePath).writeAsBytes(fileContent);
        savedPaths.add(filePath);
        debugPrint('File saved to app documents: $filePath');
      } catch (e) {
        debugPrint('App documents save failed: $e');
      }
      
      // 3. Try custom path if provided
      if (customPath != null) {
        try {
          final filePath = '$customPath/$fileName';
          await File(filePath).writeAsBytes(fileContent);
          savedPaths.add(filePath);
          debugPrint('File saved to custom path: $filePath');
        } catch (e) {
          debugPrint('Custom path save failed: $e');
        }
      }
      
      // Create XFile for sharing
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(fileContent);
      
      final xFile = XFile(tempFile.path, mimeType: mimeType);
      
      // Enhanced sharing with multiple options
             final shareText = '''
📊 Financial Export Complete!

File: $fileName
Format: ${mimeType.split('/').last.toUpperCase()}
Size: ${(fileContent.length / 1024).toStringAsFixed(1)} KB

${savedPaths.isNotEmpty ? '💾 Saved to device:' : ''}
${savedPaths.map((path) => '• $path').join('\n')}

${savedPaths.isNotEmpty ? '\n📱 Access via:' : ''}
${savedPaths.isNotEmpty ? '• File Manager → Downloads folder' : ''}
${savedPaths.isNotEmpty ? '• Android Studio → Device Explorer' : ''}
${savedPaths.isNotEmpty ? '• ADB pull command' : ''}

💡 Tip: You can also open this file directly from the share dialog below!
      ''';
      
      await Share.shareXFiles(
        [xFile],
        text: shareText,
        subject: 'Financial Report - $fileName',
      );
      
      return true;
      
    } catch (e, stackTrace) {
      debugPrint('File save and share error: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  // Helper method to get file extension info
  static Map<String, String> getExportFormats() {
    return {
      'PDF': 'Professional PDF report with charts and formatting',
      'CSV': 'Spreadsheet format for Excel, Google Sheets, etc.',
    };
  }
  
  // Helper method to export in multiple formats at once
  static Future<Map<String, bool>> exportAllFormats(List<Transaction> transactions) async {
    final results = <String, bool>{};
    
    try {
      // Export all formats concurrently for better performance
      final futures = [
        exportToPDF(transactions).then((success) => results['PDF'] = success),
        exportToCSV(transactions).then((success) => results['CSV'] = success),
      ];
      
      await Future.wait(futures);
      
      return results;
    } catch (e) {
      debugPrint('Multi-format export error: $e');
      return {'PDF': false, 'CSV': false};
    }
  }
}