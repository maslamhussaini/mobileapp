import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportButtons extends StatelessWidget {
  final List<dynamic> data;
  final List<String> columns;
  final String filename;

  const ExportButtons({
    super.key,
    required this.data,
    required this.columns,
    required this.filename,
  });

  Future<void> _exportToCSV(BuildContext context) async {
    try {
      List<String> headerRow = [];
      if (filename.contains('sp_DisplayLedger')) {
        // Add custom headers for sp_DisplayLedger
        headerRow.add(
          'Account Code: ${data.isNotEmpty && data[0]['GLCode'] != null ? data[0]['GLCode'] : ''}',
        );
        headerRow.add(
          'Account Name Subsidiary: ${data.isNotEmpty && data[0]['AccountNameSubsidairy'] != null ? data[0]['AccountNameSubsidairy'] : ''}',
        );
        headerRow.add(
          'Transactions From ${data.isNotEmpty && data[0]['Date1'] != null ? data[0]['Date1'] : ''} Through ${data.isNotEmpty && data[0]['Date2'] != null ? data[0]['Date2'] : ''}',
        );
        headerRow.add(''); // Empty row
      }
      headerRow.addAll(columns.where((col) => col != 'RowNum'));

      List<List<String>> csvData = [
        headerRow,
        ...data.map(
          (row) => columns
              .where((col) => col != 'RowNum')
              .map((col) => row[col]?.toString() ?? '')
              .toList(),
        ),
      ];

      String csv = const ListToCsvConverter().convert(csvData);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(file.path)], text: 'Exported CSV');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting CSV: $e')));
    }
  }

  Future<void> _exportToPDF(BuildContext context) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            List<pw.Widget> widgets = [];

            if (filename.contains('sp_DisplayLedger')) {
              // Add custom headers for sp_DisplayLedger
              widgets.add(
                pw.Text(
                  'Account Code: ${data.isNotEmpty && data[0]['GLCode'] != null ? data[0]['GLCode'] : ''}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              );
              widgets.add(
                pw.Text(
                  'Account Name Subsidiary: ${data.isNotEmpty && data[0]['AccountNameSubsidairy'] != null ? data[0]['AccountNameSubsidairy'] : ''}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              );
              widgets.add(
                pw.Text(
                  'Line Transactions From ${data.isNotEmpty && data[0]['Date1'] != null ? data[0]['Date1'] : ''} Through ${data.isNotEmpty && data[0]['Date2'] != null ? data[0]['Date2'] : ''}',
                ),
              );
              widgets.add(pw.SizedBox(height: 16));
            }

            widgets.add(
              pw.Table.fromTextArray(
                headers: columns.where((col) => col != 'RowNum').toList(),
                data: data
                    .map(
                      (row) => columns
                          .where((col) => col != 'RowNum')
                          .map((col) => row[col]?.toString() ?? '')
                          .toList(),
                    )
                    .toList(),
              ),
            );

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: widgets,
            );
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Exported PDF');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: () => _exportToCSV(context),
          icon: const Icon(Icons.file_download),
          label: const Text('CSV'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _exportToPDF(context),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('PDF'),
        ),
      ],
    );
  }
}
