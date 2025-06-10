import 'package:flutter/material.dart';
import '../services/export_service.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

class EnhancedExportDialog extends StatefulWidget {
  final List<Transaction> transactions;
  final String title;

  const EnhancedExportDialog({
    Key? key,
    required this.transactions,
    this.title = 'Export Transactions',
  }) : super(key: key);

  @override
  State<EnhancedExportDialog> createState() => _EnhancedExportDialogState();

  static Future<void> show(BuildContext context, List<Transaction> transactions, {String? title}) async {
    await showDialog(
      context: context,
      builder: (context) => EnhancedExportDialog(
        transactions: transactions,
        title: title ?? 'Export Transactions',
      ),
    );
  }
}

class _EnhancedExportDialogState extends State<EnhancedExportDialog> with TickerProviderStateMixin {
  bool _isExporting = false;
  String? _currentlyExporting;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exportFormats = ExportService.getExportFormats();
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 16,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.file_download_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${widget.transactions.length} transactions',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose Export Format',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Export format options
                          ...exportFormats.entries.map((entry) {
                            final format = entry.key;
                            final description = entry.value;
                            final isCurrentlyExporting = _currentlyExporting == format;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isExporting ? null : () => _exportData(format),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isCurrentlyExporting 
                                        ? AppTheme.primaryColor.withOpacity(0.1)
                                        : AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isCurrentlyExporting 
                                          ? AppTheme.primaryColor
                                          : Colors.grey.withOpacity(0.2),
                                        width: isCurrentlyExporting ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: _getFormatColor(format).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            _getFormatIcon(format),
                                            color: _getFormatColor(format),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                format,
                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                description,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isCurrentlyExporting)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                            ),
                                          )
                                        else
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            color: AppTheme.textSecondary,
                                            size: 16,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                          
                          const SizedBox(height: 20),
                          
                          // Export all button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isExporting ? null : _exportAllFormats,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              icon: _isExporting && _currentlyExporting == 'ALL'
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.all_inclusive_rounded),
                              label: Text(
                                'Export All Formats',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  IconData _getFormatIcon(String format) {
    switch (format) {
      case 'PDF':
        return Icons.picture_as_pdf_rounded;
      case 'CSV':
        return Icons.table_chart_rounded;
      default:
        return Icons.file_download_rounded;
    }
  }
  
  Color _getFormatColor(String format) {
    switch (format) {
      case 'PDF':
        return Colors.red;
      case 'CSV':
        return Colors.green;
      default:
        return AppTheme.primaryColor;
    }
  }
  
  Future<void> _exportData(String format) async {
    if (_isExporting) return;
    
    setState(() {
      _isExporting = true;
      _currentlyExporting = format;
    });
    
    try {
      bool success = false;
      
      switch (format) {
        case 'PDF':
          success = await ExportService.exportToPDF(widget.transactions);
          break;
        case 'CSV':
          success = await ExportService.exportToCSV(widget.transactions);
          break;
      }
      
      if (mounted) {
        _showResult(success, format);
      }
    } catch (e) {
      if (mounted) {
        _showResult(false, format, error: e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _currentlyExporting = null;
        });
      }
    }
  }
  
  Future<void> _exportAllFormats() async {
    if (_isExporting) return;
    
    setState(() {
      _isExporting = true;
      _currentlyExporting = 'ALL';
    });
    
    try {
      final results = await ExportService.exportAllFormats(widget.transactions);
      
      if (mounted) {
        final successCount = results.values.where((success) => success).length;
        final totalCount = results.length;
        
        _showResult(successCount > 0, 'All Formats', 
          customMessage: '$successCount of $totalCount formats exported successfully');
      }
    } catch (e) {
      if (mounted) {
        _showResult(false, 'All Formats', error: e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _currentlyExporting = null;
        });
      }
    }
  }
  
  void _showResult(bool success, String format, {String? error, String? customMessage}) {
    if (!mounted) return;
    
    Navigator.of(context).pop(); // Close dialog
    
    String message;
    if (customMessage != null) {
      message = customMessage;
    } else if (success) {
      message = '$format export completed successfully!';
    } else {
      message = error != null 
        ? 'Export failed: $error'
        : '$format export failed. Please try again.';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    success ? 'Export Successful!' : 'Export Failed',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
} 