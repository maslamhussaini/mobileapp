import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:app/services/backend_service.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<dynamic> _procedures = [];
  String? _selectedProcedure;
  List<dynamic> _params = [];
  Map<String, dynamic> _paramValues = {};
  List<dynamic> _reportData = [];
  List<String> _reportColumns = [];
  bool _isLoading = false;
  List<dynamic> _glAccounts = [];
  String? _selectedGLAccount;
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo = DateTime.now();
  bool _showReport = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProcedures();
    _loadGLAccounts();
  }

  Future<void> _loadProcedures() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final procedures = await BackendService.getStoredProcedures();
      setState(() {
        _procedures = procedures;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading procedures: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGLAccounts() async {
    try {
      final accounts = await BackendService.getGLAccounts();
      setState(() {
        _glAccounts = accounts;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading GL accounts: $e')));
    }
  }

  Future<void> _loadProcedureParams(String procedure) async {
    try {
      final params = await BackendService.getStoredProcedureParams(procedure);
      setState(() {
        _params = params;
        _paramValues = {};
        for (var param in params) {
          _paramValues[param['name']] = '';
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading parameters: $e')));
    }
  }

  Future<void> _runReport() async {
    if (_selectedProcedure == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await BackendService.executeStoredProcedure(
        _selectedProcedure!,
        _paramValues,
      );
      setState(() {
        _reportData = data;
        _reportColumns = [];
        if (data.isNotEmpty) {
          final allKeys = <String>{};
          for (var row in data) {
            if (row is Map) {
              allKeys.addAll(row.keys.map((key) => key.toString()));
            }
          }
          _reportColumns = allKeys
              .where(
                (key) => ![
                  'RowNum',
                  'AccountCode',
                  'AccountName',
                  'AccountNameSubsidairy',
                ].contains(key),
              )
              .toList();
        }
      });

      // Show report in new tab after data is loaded
      if (data.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showReportDialog(context);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error running report: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildParamInput(dynamic param) {
    final paramName = param['name'];
    final paramType = param['type'];

    if (paramType.contains('date') || paramType.contains('time')) {
      return TextFormField(
        decoration: InputDecoration(
          labelText: paramName,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        readOnly: true,
        controller: TextEditingController(text: _paramValues[paramName]),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _paramValues[paramName].isNotEmpty
                ? DateTime.tryParse(_paramValues[paramName]) ?? DateTime.now()
                : DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
          );
          if (date != null) {
            final formattedDate = DateFormat('yyyy-MM-dd').format(date);
            setState(() {
              _paramValues[paramName] = formattedDate;
            });
          }
        },
      );
    } else if (paramType.contains('int') || paramType.contains('decimal')) {
      return TextFormField(
        decoration: InputDecoration(labelText: paramName),
        keyboardType: TextInputType.number,
        onChanged: (value) => _paramValues[paramName] = value,
        initialValue: _paramValues[paramName],
      );
    } else {
      return TextFormField(
        decoration: InputDecoration(labelText: paramName),
        onChanged: (value) => _paramValues[paramName] = value,
        initialValue: _paramValues[paramName],
      );
    }
  }

  void _onProcedureSelected(String? procedure) {
    setState(() {
      _selectedProcedure = procedure;
      _reportData = [];
      _reportColumns = [];
    });
    if (procedure != null) {
      _loadProcedureParams(procedure);
    }
  }

  String _formatCellValue(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return DateFormat('dd/MM/yyyy').format(value);
    }
    // Handle string dates that might be in ISO format
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

  String _getColumnDisplayName(String columnName) {
    switch (columnName) {
      case 'TransDate':
        return 'Date';
      case 'VoucherNumber':
        return 'Voucher';
      case 'NarrationGL':
        return 'Narration';
      default:
        return columnName;
    }
  }

  Future<void> _exportToCSV() async {
    try {
      List<String> headerRow = [];
      if (_selectedProcedure == 'sp_DisplayLedger') {
        // Add custom headers for sp_DisplayLedger
        headerRow.add('Account Code: ${_paramValues['@GLCode'] ?? ''}');
        headerRow.add(
          'Account Name Subsidiary: ${_reportData.isNotEmpty && _reportData[0]['AccountNameSubsidairy'] != null ? _reportData[0]['AccountNameSubsidairy'] : ''}',
        );
        headerRow.add(
          'Transactions From ${_paramValues['@Date1'] ?? ''} Through ${_paramValues['@Date2'] ?? ''}',
        );
        headerRow.add(''); // Empty row
      }
      headerRow.addAll(_reportColumns.where((col) => col != 'RowNum'));

      List<List<String>> csvData = [
        headerRow,
        ..._reportData.map(
          (row) => _reportColumns
              .where((col) => col != 'RowNum')
              .map((col) => _formatCellValue(row[col]))
              .toList(),
        ),
      ];

      String csv = const ListToCsvConverter().convert(csvData);
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/${_selectedProcedure ?? 'report'}.csv',
      );
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(file.path)], text: 'Exported CSV');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting CSV: $e')));
    }
  }

  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            List<pw.Widget> widgets = [];

            if (_selectedProcedure == 'sp_DisplayLedger') {
              // Add custom headers for sp_DisplayLedger
              widgets.add(
                pw.Text(
                  'Account Code: ${_paramValues['@GLCode'] ?? ''}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              );
              widgets.add(
                pw.Text(
                  'Account Name Subsidiary: ${_reportData.isNotEmpty && _reportData[0]['AccountNameSubsidairy'] != null ? _reportData[0]['AccountNameSubsidairy'] : ''}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              );
              widgets.add(
                pw.Text(
                  'Line Transactions From ${_paramValues['@Date1'] ?? ''} Through ${_paramValues['@Date2'] ?? ''}',
                ),
              );
              widgets.add(pw.SizedBox(height: 16));
            }

            widgets.add(
              pw.Table.fromTextArray(
                headers: _reportColumns
                    .where((col) => col != 'RowNum')
                    .toList(),
                data: _reportData
                    .map(
                      (row) => _reportColumns
                          .where((col) => col != 'RowNum')
                          .map((col) => _formatCellValue(row[col]))
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
      final file = File(
        '${directory.path}/${_selectedProcedure ?? 'report'}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Exported PDF');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    }
  }

  String _getAccountName(String? accountCode) {
    if (accountCode == null) return '';
    final account = _glAccounts.firstWhere(
      (acc) => acc['AccountCodeSubsidairy'] == accountCode,
      orElse: () => null,
    );
    return account?['AccountNameSubsidairy'] ?? '';
  }

  Future<void> _runLedgerReport() async {
    if (_selectedProcedure == null || _selectedGLAccount == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final params = {
        '@GLCode': _selectedGLAccount,
        '@Date1': DateFormat('yyyy-MM-dd').format(_dateFrom),
        '@Date2': DateFormat('yyyy-MM-dd').format(_dateTo),
      };

      final data = await BackendService.executeStoredProcedure(
        _selectedProcedure!,
        params,
      );

      setState(() {
        _reportData = data;
        _showReport = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error running report: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showParameterDialog(BuildContext context) async {
    String? dialogSelectedProcedure = _selectedProcedure;
    String? dialogSelectedGLAccount = _selectedGLAccount;
    DateTime dialogDateFrom = _dateFrom;
    DateTime dialogDateTo = _dateTo;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
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
                        // Add some top padding to account for keyboard
                        const SizedBox(height: 50),

                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Ledger Report Parameters",
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

                        // Report Name Dropdown
                      DropdownButtonFormField<String>(
                        value: dialogSelectedProcedure,
                        decoration: const InputDecoration(
                          labelText: "Report Name",
                          border: OutlineInputBorder(),
                          labelStyle: TextStyle(fontSize: 10),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'sp_DisplayLedger',
                            child: Text('Ledger'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            dialogSelectedProcedure = value;
                          });
                        },
                      ),

                      const SizedBox(height: 10),

                      // GL Account Dropdown
                      DropdownButtonFormField<String>(
                        value: dialogSelectedGLAccount,
                        decoration: const InputDecoration(
                          labelText: "GL Account",
                          border: OutlineInputBorder(),
                          labelStyle: TextStyle(fontSize: 10),
                        ),
                        items: _glAccounts.map<DropdownMenuItem<String>>((acc) {
                          final code =
                              acc['AccountCodeSubsidairy']?.toString() ?? '';
                          final name =
                              acc['AccountNameSubsidairy']?.toString() ?? '';
                          return DropdownMenuItem<String>(
                            value: code,
                            child: Text(
                              '$code - $name',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            dialogSelectedGLAccount = value;
                          });
                        },
                      ),

                      const SizedBox(height: 10),

                      // Date pickers
                      Column(
                        children: [
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: "From Date",
                              border: OutlineInputBorder(),
                              labelStyle: TextStyle(fontSize: 10),
                            ),
                            readOnly: true,
                            controller: TextEditingController(
                              text: DateFormat(
                                'yyyy-MM-dd',
                              ).format(dialogDateFrom),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dialogDateFrom,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2101),
                              );
                              if (picked != null) {
                                setState(() => dialogDateFrom = picked);
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: "To Date",
                              border: OutlineInputBorder(),
                              labelStyle: TextStyle(fontSize: 10),
                            ),
                            readOnly: true,
                            controller: TextEditingController(
                              text: DateFormat(
                                'yyyy-MM-dd',
                              ).format(dialogDateTo),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dialogDateTo,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2101),
                              );
                              if (picked != null) {
                                setState(() => dialogDateTo = picked);
                              }
                            },
                          ),
                        ],
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
                              onPressed: () async {
                                // Update state with dialog values
                                setState(() {
                                  _selectedProcedure = dialogSelectedProcedure;
                                  _selectedGLAccount = dialogSelectedGLAccount;
                                  _dateFrom = dialogDateFrom;
                                  _dateTo = dialogDateTo;
                                });
                                Navigator.pop(context); // Close dialog
                                await _runLedgerReport(); // Run the report
                              },
                              child: const Text(
                                "Show Report",
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
          // Header inside report - FIXED: Use SizedBox with fixed width
          SizedBox(
            width:
                MediaQuery.of(context).size.width - 16, // Account for padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "GL Account: $_selectedGLAccount",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 8,
                            ),
                          ),
                          Text(
                            "GL Account Name: ${_getAccountName(_selectedGLAccount)}",
                            style: const TextStyle(fontSize: 8),
                          ),
                          Text(
                            "Transactions from ${DateFormat('yyyy-MM-dd').format(_dateFrom)} through ${DateFormat('yyyy-MM-dd').format(_dateTo)}",
                            style: const TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 120, // Fixed width for buttons
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, size: 14),
                            onPressed: () => _exportToPDF(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download, size: 14),
                            onPressed: () => _exportToCSV(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () =>
                                setState(() => _showReport = false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),

          // Scrollable Table - FIXED: Use LayoutBuilder for proper constraints
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            textTheme: const TextTheme(
                              bodyMedium: TextStyle(
                                fontSize: 7.0,
                                fontFamily: 'MS Sans Serif',
                              ),
                            ),
                          ),
                          child: DataTable2(
                            columnSpacing: 8.0,
                            headingTextStyle: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            dataTextStyle: const TextStyle(fontSize: 7),
                            columns: [
                              const DataColumn(label: Text('Date')),
                              const DataColumn(label: Text('Voucher No')),
                              const DataColumn(label: Text('Narration')),
                              const DataColumn(label: Text('Debit')),
                              const DataColumn(label: Text('Credit')),
                              const DataColumn(label: Text('Running Balance')),
                            ],
                            rows: _reportData.map((row) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(_formatCellValue(row['TransDate'])),
                                  ),
                                  DataCell(
                                    Text(
                                      row['VoucherNumber']?.toString() ?? '',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      row['NarrationGL']?.toString() ??
                                          row['Narration']?.toString() ??
                                          '',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      row['Debit'] != null
                                          ? row['Debit'].toString()
                                          : '',
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      row['Credit'] != null
                                          ? row['Credit'].toString()
                                          : '',
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      row['RunningBalance'] != null
                                          ? row['RunningBalance'].toString()
                                          : '',
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('General Ledger Report'),
        actions: [
          ElevatedButton(
            onPressed: () => _showParameterDialog(context),
            child: const Text(
              "Select Parameters",
              style: TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox.expand(
            child: Column(
              children: [
                if (_showReport && _reportData.isNotEmpty)
                  Expanded(child: _buildReportView()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16.0),
          child: Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.9,
            child: Column(
              children: [
                // Header with report name and export buttons
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedProcedure == 'sp_DisplayLedger'
                            ? 'Ledger Report'
                            : _selectedProcedure ?? 'Report',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              _exportToCSV();
                            },
                            icon: const Icon(Icons.file_download),
                            label: const Text('CSV'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              _exportToPDF();
                            },
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('PDF'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Parameters section
                if (_params.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Parameters:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16.0,
                          runSpacing: 8.0,
                          children: _params.map((param) {
                            final paramName = param['name'];
                            return Text(
                              '${paramName}: ${_paramValues[paramName] ?? ''}',
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
                // Report data
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedProcedure == 'sp_DisplayLedger') ...[
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account Code: ${_paramValues['@GLCode'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Account Name Subsidiary: ${_reportData.isNotEmpty && _reportData[0]['AccountNameSubsidairy'] != null ? _reportData[0]['AccountNameSubsidairy'] : ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Line Transactions From ${_paramValues['@Date1'] ?? ''} Through ${_paramValues['@Date2'] ?? ''}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width,
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable2(
                              columnSpacing: 8.0,
                              columns: _reportColumns
                                  .map(
                                    (col) => DataColumn(
                                      label: Text(_getColumnDisplayName(col)),
                                    ),
                                  )
                                  .toList(),
                              rows: _reportData.map((row) {
                                return DataRow(
                                  cells: _reportColumns
                                      .map(
                                        (col) => DataCell(
                                          Text(_formatCellValue(row[col])),
                                        ),
                                      )
                                      .toList(),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
