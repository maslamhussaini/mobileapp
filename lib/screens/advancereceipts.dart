import 'package:flutter/material.dart';
import 'package:app/services/backend_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:pdf/widgets.dart' as pw show Font, Theme;

class AdvanceReceipts extends StatefulWidget {
  const AdvanceReceipts({super.key});

  @override
  State<AdvanceReceipts> createState() => _AdvanceReceiptsState();
}

class _AdvanceReceiptsState extends State<AdvanceReceipts> {
  List<dynamic> _reportData = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _cities = [];
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      // Load cities from tblcity table
      // await BackendService.refreshMaterializedView();
      //               _startPeriodicRefresh();
      //             }

      await BackendService.refreshMaterializedView(viewName: 'mv_customer_balance_summary');
      final cities = await BackendService.getAll('tblcity');
      print('Loaded ${cities.length} cities');
      if (cities.isNotEmpty) {
        print('First city: ${cities[0]}');
      }
      setState(() {
        _cities = [
          {'cityname': 'All'},
          ...cities,
        ]; // Add "All" option at the beginning
        _selectedCity = 'All'; // Default to "All"
      });
      // Show parameter dialog instead of loading report automatically
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showParameterDialog(context);
      });
    } catch (e) {
      print('Error loading cities: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading cities: $e')));
    }
  }

  // Test search functionality
  void _testSearch(String query) {
    final results = _cities.where((city) {
      final cityName = city['cityname']?.toString() ?? '';
      final searchText = query.toLowerCase();
      return cityName.toLowerCase().contains(searchText);
    }).toList();

    print('Search query: "$query"');
    print('Results found: ${results.length}');
    if (results.isNotEmpty) {
      print('First result: ${results[0]['cityname']}');
    }
  }

  Future<void> _loadReport() async {
    if (_selectedCity == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Execute raw query to get customer balance summary filtered by city
      final whereClause = _selectedCity == 'All'
          ? "Where 1 = 1"
          : "Where lower(address) = lower('${_selectedCity}')";
      final query =
          "Select customername, billamountbalance, advance, chequebounced, pdc, total from mv_customer_balance_summary $whereClause Order by customername";

      print('Loading report with query: $query');

      final data = await BackendService.executeRawQuery(query);

      print('Received data length: ${data.length}');
      if (data.isNotEmpty) {
        print('First record: ${data[0]}');
      }

      setState(() {
        _reportData = data;
      });
    } catch (e) {
      print('Error loading report: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading report: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatCellValue(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return DateFormat('dd/MM/yyyy').format(value);
    }
    if (value is String) {
      try {
        final date = DateTime.tryParse(value);
        if (date != null) {
          return DateFormat('dd/MM/yyyy').format(date);
        }
      } catch (e) {
        // If parsing fails, return as is
      }
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('NOC Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showParameterDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _exportToPDF(),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportToCSV(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _reportData.isEmpty
              ? const Center(child: Text('No data available'))
              : _buildReportView(),
        ),
      ),
    );
  }

  Widget _buildReportView() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                "Hussain Oils",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          SizedBox(
            width: MediaQuery.of(context).size.width - 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "NOC Reports",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  "Address: ${_selectedCity == 'All' ? 'All Addresses' : _selectedCity}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),

                const Divider(),
              ],
            ),
          ),

          // Data Table - Simple version without LayoutBuilder
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - 32,
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        textTheme: const TextTheme(
                          bodyMedium: TextStyle(
                            fontSize: 10.0,
                            fontFamily: 'MS Sans Serif',
                          ),
                        ),
                      ),
                      child: DataTable(
                        columnSpacing: 4.0,
                        headingTextStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        dataTextStyle: const TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                        ),
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Customer Name',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Bill Amount Balance',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Advance',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Cheque Bounced',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'PDC',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Total',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        rows: [
                          ..._reportData.map((row) {
                            final billAmountBalance =
                                row['billamountbalance'] != null
                                ? double.tryParse(
                                        row['billamountbalance'].toString(),
                                      ) ??
                                      0
                                : 0;
                            final advance = row['advance'] != null
                                ? double.tryParse(row['advance'].toString()) ??
                                      0
                                : 0;
                            final chequeBounced = row['chequebounced'] != null
                                ? double.tryParse(
                                        row['chequebounced'].toString(),
                                      ) ??
                                      0
                                : 0;
                            final pdc = row['pdc'] != null
                                ? double.tryParse(row['pdc'].toString()) ?? 0
                                : 0;
                            final total = row['total'] != null
                                ? double.tryParse(row['total'].toString()) ?? 0
                                : 0;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Container(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      row['customername']?.toString() ?? '',
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      billAmountBalance != 0
                                          ? NumberFormat(
                                              '#,##0.00',
                                            ).format(billAmountBalance)
                                          : '',
                                      style: TextStyle(
                                        color: billAmountBalance < 0
                                            ? Colors.red
                                            : (billAmountBalance > 0
                                                  ? Colors.black
                                                  : null),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      advance != 0
                                          ? NumberFormat(
                                              '#,##0.00',
                                            ).format(advance)
                                          : '',
                                      style: TextStyle(
                                        color: advance < 0
                                            ? Colors.red
                                            : (advance > 0
                                                  ? Colors.black
                                                  : null),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      chequeBounced != 0
                                          ? NumberFormat(
                                              '#,##0.00',
                                            ).format(chequeBounced)
                                          : '',
                                      style: TextStyle(
                                        color: chequeBounced < 0
                                            ? Colors.red
                                            : (chequeBounced > 0
                                                  ? Colors.black
                                                  : null),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      pdc != 0
                                          ? NumberFormat('#,##0.00').format(pdc)
                                          : '',
                                      style: TextStyle(
                                        color: pdc < 0
                                            ? Colors.red
                                            : (pdc > 0 ? Colors.black : null),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      total != 0
                                          ? NumberFormat(
                                              '#,##0.00',
                                            ).format(total)
                                          : '',
                                      style: TextStyle(
                                        color: total < 0
                                            ? Colors.red
                                            : (total > 0 ? Colors.black : null),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                          // Totals row
                          DataRow(
                            cells: [
                              DataCell(
                                Container(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Grand Total',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 1,
                                  ),
                                  child: Text(
                                    NumberFormat('#,##0.00').format(
                                      _reportData.fold<double>(
                                        0.0,
                                        (sum, row) =>
                                            sum +
                                            (row['billamountbalance'] != null
                                                ? double.tryParse(
                                                        row['billamountbalance']
                                                            .toString(),
                                                      ) ??
                                                      0
                                                : 0),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 1,
                                  ),
                                  child: Text(
                                    NumberFormat('#,##0.00').format(
                                      _reportData.fold<double>(
                                        0.0,
                                        (sum, row) =>
                                            sum +
                                            (row['advance'] != null
                                                ? double.tryParse(
                                                        row['advance']
                                                            .toString(),
                                                      ) ??
                                                      0
                                                : 0),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 1,
                                  ),
                                  child: Text(
                                    NumberFormat('#,##0.00').format(
                                      _reportData.fold<double>(
                                        0.0,
                                        (sum, row) =>
                                            sum +
                                            (row['chequebounced'] != null
                                                ? double.tryParse(
                                                        row['chequebounced']
                                                            .toString(),
                                                      ) ??
                                                      0
                                                : 0),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 1,
                                  ),
                                  child: Text(
                                    NumberFormat('#,##0.00').format(
                                      _reportData.fold<double>(
                                        0.0,
                                        (sum, row) =>
                                            sum +
                                            (row['pdc'] != null
                                                ? double.tryParse(
                                                        row['pdc'].toString(),
                                                      ) ??
                                                      0
                                                : 0),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 1,
                                  ),
                                  child: Text(
                                    NumberFormat('#,##0.00').format(
                                      _reportData.fold<double>(
                                        0.0,
                                        (sum, row) =>
                                            sum +
                                            (row['total'] != null
                                                ? double.tryParse(
                                                        row['total'].toString(),
                                                      ) ??
                                                      0
                                                : 0),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCityName(String? cityName) {
    if (cityName == null) return '';
    final city = _cities.firstWhere(
      (c) => c['cityname'] == cityName,
      orElse: () => null,
    );
    return city?['cityname'] ?? '';
  }

  // Remove unused variables and methods
  void _removeUnusedVariables() {
    // This method is just to satisfy the compiler
  }

  Future<void> _showParameterDialog(BuildContext context) async {
    String? dialogSelectedCity = _selectedCity;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 500,
                    maxHeight: 300,
                  ),
                  child: Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    insetPadding: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 50),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "NOC Report Parameters",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                            const Divider(),
                            const SizedBox(height: 10),

                            // City Dropdown
                            DropdownButtonFormField<String>(
                              value: dialogSelectedCity,
                              decoration: const InputDecoration(
                                labelText: "Address",
                                border: OutlineInputBorder(),
                                labelStyle: TextStyle(fontSize: 12),
                              ),
                              style: const TextStyle(fontSize: 12),
                              items: _cities.map((city) {
                                return DropdownMenuItem<String>(
                                  value: city['cityname']?.toString(),
                                  child: Text(
                                    city['cityname']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  dialogSelectedCity = value;
                                });
                              },
                            ),

                            const SizedBox(height: 20),

                            // Action buttons
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      "Cancel",
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed:
                                        dialogSelectedCity != null &&
                                            dialogSelectedCity!.isNotEmpty
                                        ? () async {
                                            this.setState(() {
                                              _selectedCity =
                                                  dialogSelectedCity;
                                            });
                                            Navigator.pop(context);
                                            await _loadReport();
                                          }
                                        : null,
                                    child: const Text(
                                      "Go",
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportToCSV() async {
    try {
      List<List<String>> csvData = [
        ['Address: ${_selectedCity == 'All' ? 'All Addresses' : _selectedCity}'],
        ['NOC Report'],
        [''], // Empty row
        [
          'Customer Name',
          'Bill Amount Balance',
          'Advance',
          'Cheque Bounced',
          'PDC',
          'Total',
        ],
        ..._reportData.map(
          (row) => [
            row['customername']?.toString() ?? '',
            () {
              final billAmountBalance = row['billamountbalance'] != null
                  ? double.tryParse(row['billamountbalance'].toString()) ?? 0
                  : 0;
              return billAmountBalance != 0
                  ? NumberFormat('#,##0.00').format(billAmountBalance)
                  : '';
            }(),
            () {
              final advance = row['advance'] != null
                  ? double.tryParse(row['advance'].toString()) ?? 0
                  : 0;
              return advance != 0
                  ? NumberFormat('#,##0.00').format(advance)
                  : '';
            }(),
            () {
              final chequeBounced = row['chequebounced'] != null
                  ? double.tryParse(row['chequebounced'].toString()) ?? 0
                  : 0;
              return chequeBounced != 0
                  ? NumberFormat('#,##0.00').format(chequeBounced)
                  : '';
            }(),
            () {
              final pdc = row['pdc'] != null
                  ? double.tryParse(row['pdc'].toString()) ?? 0
                  : 0;
              return pdc != 0 ? NumberFormat('#,##0.00').format(pdc) : '';
            }(),
            () {
              final total = row['total'] != null
                  ? double.tryParse(row['total'].toString()) ?? 0
                  : 0;
              return total != 0 ? NumberFormat('#,##0.00').format(total) : '';
            }(),
          ],
        ),
        // Totals row
        [
          'Total',
          NumberFormat('#,##0.00').format(
            _reportData.fold<double>(
              0.0,
              (sum, row) =>
                  sum +
                  (row['billamountbalance'] != null
                      ? double.tryParse(row['billamountbalance'].toString()) ??
                            0
                      : 0),
            ),
          ),
          NumberFormat('#,##0.00').format(
            _reportData.fold<double>(
              0.0,
              (sum, row) =>
                  sum +
                  (row['advance'] != null
                      ? double.tryParse(row['advance'].toString()) ?? 0
                      : 0),
            ),
          ),
          NumberFormat('#,##0.00').format(
            _reportData.fold<double>(
              0.0,
              (sum, row) =>
                  sum +
                  (row['chequebounced'] != null
                      ? double.tryParse(row['chequebounced'].toString()) ?? 0
                      : 0),
            ),
          ),
          NumberFormat('#,##0.00').format(
            _reportData.fold<double>(
              0.0,
              (sum, row) =>
                  sum +
                  (row['pdc'] != null
                      ? double.tryParse(row['pdc'].toString()) ?? 0
                      : 0),
            ),
          ),
          NumberFormat('#,##0.00').format(
            _reportData.fold<double>(
              0.0,
              (sum, row) =>
                  sum +
                  (row['total'] != null
                      ? double.tryParse(row['total'].toString()) ?? 0
                      : 0),
            ),
          ),
        ],
      ];

      String csv = const ListToCsvConverter().convert(csvData);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'advance_receipts_${timestamp}.csv';

      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        // For desktop platforms, save to Downloads directory
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          final file = File('${directory.path}/$fileName');
          await file.writeAsString(csv);

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('CSV saved to: ${file.path}')));
        } else {
          // Fallback to documents directory
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$fileName');
          await file.writeAsString(csv);

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('CSV saved to: ${file.path}')));
        }
      } else {
        // For mobile/web platforms, use share functionality
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(csv);

        await Share.shareXFiles([XFile(file.path)], text: 'Ledger Report CSV');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting CSV: $e')));
    }
  }

  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();

      // Define a custom theme with fallback fonts
      final theme = pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          theme: theme,
          build: (context) => [
            // Header Section
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Hussain Oils',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'NOC Report',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Divider(),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // City Information
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'NOC Report',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Address: ${_selectedCity == 'All' ? 'All Addresses' : _selectedCity}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 15),

            // Data Table
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.0), // Customer Name
                1: const pw.FlexColumnWidth(0.8), // Bill Amount Balance
                2: const pw.FlexColumnWidth(0.8), // Advance
                3: const pw.FlexColumnWidth(0.8), // Cheque Bounced
                4: const pw.FlexColumnWidth(0.8), // PDC
                5: const pw.FlexColumnWidth(0.8), // Total
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Customer Name',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.left,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Bill Amount Balance',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Advance',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Cheque Bounced',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'PDC',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Total',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
                // Data rows
                ..._reportData.map((row) {
                  final billAmountBalance = (row['billamountbalance'] is num)
                      ? row['billamountbalance']
                      : double.tryParse(
                              row['billamountbalance']?.toString() ?? '0',
                            ) ??
                            0.0;
                  final advance = (row['advance'] is num)
                      ? row['advance']
                      : double.tryParse(row['advance']?.toString() ?? '0') ??
                            0.0;
                  final chequeBounced = (row['chequebounced'] is num)
                      ? row['chequebounced']
                      : double.tryParse(
                              row['chequebounced']?.toString() ?? '0',
                            ) ??
                            0.0;
                  final pdc = (row['pdc'] is num)
                      ? row['pdc']
                      : double.tryParse(row['pdc']?.toString() ?? '0') ?? 0.0;
                  final total = (row['total'] is num)
                      ? row['total']
                      : double.tryParse(row['total']?.toString() ?? '0') ?? 0.0;

                  return pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          row['customername']?.toString() ?? '',
                          style: const pw.TextStyle(fontSize: 8),
                          textAlign: pw.TextAlign.left,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          billAmountBalance != 0
                              ? NumberFormat(
                                  '#,##0.00',
                                ).format(billAmountBalance)
                              : '',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: billAmountBalance < 0
                                ? PdfColors.red
                                : (billAmountBalance > 0
                                      ? PdfColors.black
                                      : null),
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          advance != 0
                              ? NumberFormat('#,##0.00').format(advance)
                              : '',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: advance < 0
                                ? PdfColors.red
                                : (advance > 0 ? PdfColors.black : null),
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          chequeBounced != 0
                              ? NumberFormat('#,##0.00').format(chequeBounced)
                              : '',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: chequeBounced < 0
                                ? PdfColors.red
                                : (chequeBounced > 0 ? PdfColors.black : null),
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          pdc != 0 ? NumberFormat('#,##0.00').format(pdc) : '',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: pdc < 0
                                ? PdfColors.red
                                : (pdc > 0 ? PdfColors.black : null),
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          total != 0
                              ? NumberFormat('#,##0.00').format(total)
                              : '',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: total < 0
                                ? PdfColors.red
                                : (total > 0 ? PdfColors.black : null),
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  );
                }).toList(),
                // Totals row
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Total',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.left,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        NumberFormat('#,##0.00').format(
                          _reportData.fold<double>(
                            0.0,
                            (sum, row) =>
                                sum +
                                ((row['billamountbalance'] is num)
                                    ? row['billamountbalance']
                                    : double.tryParse(
                                            row['billamountbalance']
                                                    ?.toString() ??
                                                '0',
                                          ) ??
                                          0.0),
                          ),
                        ),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        NumberFormat('#,##0.00').format(
                          _reportData.fold<double>(
                            0.0,
                            (sum, row) =>
                                sum +
                                ((row['advance'] is num)
                                    ? row['advance']
                                    : double.tryParse(
                                            row['advance']?.toString() ?? '0',
                                          ) ??
                                          0.0),
                          ),
                        ),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        NumberFormat('#,##0.00').format(
                          _reportData.fold<double>(
                            0.0,
                            (sum, row) =>
                                sum +
                                ((row['chequebounced'] is num)
                                    ? row['chequebounced']
                                    : double.tryParse(
                                            row['chequebounced']?.toString() ??
                                                '0',
                                          ) ??
                                          0.0),
                          ),
                        ),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        NumberFormat('#,##0.00').format(
                          _reportData.fold<double>(
                            0.0,
                            (sum, row) =>
                                sum +
                                ((row['pdc'] is num)
                                    ? row['pdc']
                                    : double.tryParse(
                                            row['pdc']?.toString() ?? '0',
                                          ) ??
                                          0.0),
                          ),
                        ),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        NumberFormat('#,##0.00').format(
                          _reportData.fold<double>(
                            0.0,
                            (sum, row) =>
                                sum +
                                ((row['total'] is num)
                                    ? row['total']
                                    : double.tryParse(
                                            row['total']?.toString() ?? '0',
                                          ) ??
                                          0.0),
                          ),
                        ),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Footer
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'Designed by Magical Digits - ${DateTime.now().toString()}',
                style: const pw.TextStyle(
                  fontSize: 6,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          ],
        ),
      );

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'advance_receipts_${timestamp}.pdf';

      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        // For desktop platforms, save to Downloads directory
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(await pdf.save());

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('PDF saved to: ${file.path}')));
        } else {
          // Fallback to documents directory
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(await pdf.save());

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('PDF saved to: ${file.path}')));
        }
      } else {
        // For mobile/web platforms, use share functionality
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(await pdf.save());

        await Share.shareXFiles([XFile(file.path)], text: 'Ledger Report PDF');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
