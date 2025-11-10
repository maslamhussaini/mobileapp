import 'package:flutter/material.dart';
import 'package:app/services/backend_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:io' show Platform, File;

class ReportOutScreen extends StatefulWidget {
  const ReportOutScreen({super.key});

  @override
  State<ReportOutScreen> createState() => _ReportOutScreenState();
}

class _ReportOutScreenState extends State<ReportOutScreen> {
  List<dynamic> _reportData = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _suggestionScrollController = ScrollController();
  List<dynamic> _glAccounts = [];
  String? _selectedGLAccount;
  String? _selectedGLAccountDisplay;
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Show parameter dialog immediately without loading accounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showParameterDialog(context);
    });
  }

  Future<void> _loadGLAccounts() async {
    try {
      // Query accountname from v_accounts - load all accounts initially
      final query = "Select accountname from v_accounts";
      final accounts = await BackendService.executeRawQuery(query);
      if (kDebugMode) {
        print('Loaded ${accounts.length} GL accounts from v_accounts');
        if (accounts.isNotEmpty) {
          print('First account: ${accounts[0]}');
        }
      }
      setState(() {
        _glAccounts = accounts;
        _selectedGLAccount = accounts.isNotEmpty
            ? accounts[0]['accountname']?.toString().split(',').last ??
                  accounts[0]['accountname']
            : null;
      });
      if (kDebugMode)
        print('Available accounts after loading: ${_glAccounts.length}');
      // Show parameter dialog instead of loading report automatically
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showParameterDialog(context);
      });
    } catch (e) {
      if (kDebugMode) print('Error loading GL accounts: $e');
      // Set empty list on error to prevent crashes
      setState(() {
        _glAccounts = [];
        _selectedGLAccount = null;
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading GL accounts: $e')));
    }
  }

  Future<void> _loadReport() async {
    if (_selectedGLAccount == null) return;

    setState(() {
      _isLoading = true;
    });

    // Show a snackbar to indicate the query is running
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading report data... This may take a few moments.'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    try {
      final params = {
        'glcode': _selectedGLAccount,
        'date1': DateFormat('yyyy-MM-dd').format(_dateFrom),
        'date2': DateFormat('yyyy-MM-dd').format(_dateTo),
      };

      if (kDebugMode) print('Loading report with params: $params');

      // Use Supabase function call instead of stored procedure with timeout
      final data = await BackendService.supabase
          .rpc('sp_displayledger', params: params)
          .timeout(
            const Duration(seconds: 60), // Increased timeout to 60 seconds
            onTimeout: () {
              throw Exception(
                'Query timed out. Please try with a shorter date range (1-3 months) or select a different account.',
              );
            },
          );

      if (kDebugMode) {
        print('Received data length: ${data.length}');
        if (data.isNotEmpty) {
          print('First record: ${data[0]}');
        }
      }

      setState(() {
        _reportData = data;
      });
    } catch (e) {
      if (kDebugMode) print('Error loading report: $e');
      if (!context.mounted) return;

      String errorMessage = 'Error loading report';
      if (e.toString().contains('timeout') || e.toString().contains('57014')) {
        errorMessage =
            'Query timed out. Please try with a shorter date range (e.g., 1-3 months) or select a different account.';
      } else if (e.toString().contains('connection')) {
        errorMessage =
            'Connection error. Please check your internet connection and try again.';
      } else {
        errorMessage = 'Error loading report: ${e.toString().split(':').first}';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
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
        title: const Text('Account Statement'),
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
          SizedBox(
            width: MediaQuery.of(context).size.width - 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "GL Account: ${_selectedGLAccountDisplay ?? _selectedGLAccount ?? ''}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  "Transactions from ${DateFormat('dd-MMM-yyyy').format(_dateFrom)} Through ${DateFormat('dd-MMM-yyyy').format(_dateTo)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 10,
                  ),
                ),
                // Text("", style: const TextStyle(fontSize: 10)),
                // Text("", style: const TextStyle(fontSize: 10)),
                // const Divider(),
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
                        columnSpacing: 12.0,
                        headingTextStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        dataTextStyle: const TextStyle(fontSize: 10),
                        columns: const [
                          DataColumn(
                            label: Text('Date', textAlign: TextAlign.right),
                          ),

                          DataColumn(
                            label: Text('Voucher', textAlign: TextAlign.right),
                          ),
                          DataColumn(
                            label: Text(
                              'Narration',
                              textAlign: TextAlign.right,
                            ),
                          ),
                          DataColumn(
                            label: Text('Debit', textAlign: TextAlign.right),
                          ),
                          DataColumn(
                            label: Text('Credit', textAlign: TextAlign.right),
                          ),
                          DataColumn(
                            label: Text('Balance', textAlign: TextAlign.right),
                          ),
                        ],
                        rows: [
                          ..._reportData.map((row) {
                            final debit = row['debit'] != null
                                ? double.tryParse(row['debit'].toString()) ?? 0
                                : 0;
                            final credit = row['credit'] != null
                                ? double.tryParse(row['credit'].toString()) ?? 0
                                : 0;
                            final balance = row['runningbalance'] != null
                                ? double.tryParse(
                                        row['runningbalance'].toString(),
                                      ) ??
                                      0
                                : 0;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(_formatCellValue(row['transdate'])),
                                ),
                                DataCell(
                                  Text(row['vouchernumber']?.toString() ?? ''),
                                ),
                                DataCell(
                                  Text(
                                    row['narrationsgl']?.toString() ??
                                        row['narration']?.toString() ??
                                        '',
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    alignment: Alignment.centerRight,
                                    color: debit > 0
                                        ? Colors.green[50]
                                        : Colors.green[50],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      debit > 0
                                          ? NumberFormat(
                                              '#,##0.00',
                                            ).format(debit)
                                          : '',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: debit > 0
                                            ? FontWeight.bold
                                            : null,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    alignment: Alignment.centerRight,
                                    color: credit > 0
                                        ? Colors.red[50]
                                        : Colors.red[50],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      credit > 0
                                          ? NumberFormat(
                                              '#,##0.00',
                                            ).format(credit)
                                          : '',
                                      style: TextStyle(
                                        color: credit > 0
                                            ? Colors.black
                                            : Colors.black,
                                        fontWeight: credit > 0
                                            ? FontWeight.bold
                                            : null,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      balance != 0
                                          ? NumberFormat(
                                              '#,##0.00',
                                            ).format(balance)
                                          : '',
                                      style: TextStyle(
                                        color: balance < 0
                                            ? Colors.red
                                            : (balance > 0
                                                  ? Colors.green[800]
                                                  : null),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                          // Totals row
                          DataRow(
                            cells: [
                              DataCell(
                                Container(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Total',
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
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    '',
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
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    '',
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
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    NumberFormat('#,##0.00').format(
                                      _reportData.fold<double>(
                                        0.0,
                                        (sum, row) =>
                                            sum +
                                            (row['debit'] != null
                                                ? double.tryParse(
                                                        row['debit'].toString(),
                                                      ) ??
                                                      0
                                                : 0),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    NumberFormat('#,##0.00').format(
                                      _reportData.fold<double>(
                                        0.0,
                                        (sum, row) =>
                                            sum +
                                            (row['credit'] != null
                                                ? double.tryParse(
                                                        row['credit']
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
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    NumberFormat('#,##0.00').format(
                                      _reportData.fold<double>(
                                            0.0,
                                            (sum, row) =>
                                                sum +
                                                (row['debit'] != null
                                                    ? double.tryParse(
                                                            row['debit']
                                                                .toString(),
                                                          ) ??
                                                          0
                                                    : 0),
                                          ) -
                                          _reportData.fold<double>(
                                            0.0,
                                            (sum, row) =>
                                                sum +
                                                (row['credit'] != null
                                                    ? double.tryParse(
                                                            row['credit']
                                                                .toString(),
                                                          ) ??
                                                          0
                                                    : 0),
                                          ),
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color:
                                          (_reportData.fold<double>(
                                                    0.0,
                                                    (sum, row) =>
                                                        sum +
                                                        (row['debit'] != null
                                                            ? double.tryParse(
                                                                    row['debit']
                                                                        .toString(),
                                                                  ) ??
                                                                  0
                                                            : 0),
                                                  ) -
                                                  _reportData.fold<double>(
                                                    0.0,
                                                    (sum, row) =>
                                                        sum +
                                                        (row['credit'] != null
                                                            ? double.tryParse(
                                                                    row['credit']
                                                                        .toString(),
                                                                  ) ??
                                                                  0
                                                            : 0),
                                                  )) <
                                              0
                                          ? Colors.white
                                          : Colors.white,
                                    ),
                                    textAlign: TextAlign.right,
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

  String _getAccountName(String? accountCode) {
    if (accountCode == null) return '';
    final account = _glAccounts.firstWhere(
      (acc) => acc['accountcode'] == accountCode,
      orElse: () => null,
    );
    return account?['names'] ?? '';
  }

  String _getFullAccountName(String? accountCode) {
    if (accountCode == null) return '';
    final account = _glAccounts.firstWhere(
      (acc) => acc['accountcode'] == accountCode,
      orElse: () => null,
    );
    if (account != null) {
      final name = account['names'] ?? '';
      final code = account['accountcode'] ?? '';
      return '$name,$code';
    }
    return accountCode;
  }

  Future<void> _showParameterDialog(BuildContext context) async {
    String? dialogSelectedGLAccount = _selectedGLAccount;
    String? dialogSelectedGLAccountDisplay = _selectedGLAccountDisplay;
    DateTime dialogDateFrom = _dateFrom;
    DateTime dialogDateTo = _dateTo;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Align(
              alignment: Alignment.topCenter,
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                insetPadding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmallScreen = constraints.maxWidth < 400;
                    final isVerySmallScreen = constraints.maxHeight < 600;

                    return Container(
                      constraints: BoxConstraints(
                        maxHeight: isVerySmallScreen
                            ? MediaQuery.of(context).size.height * 0.9
                            : MediaQuery.of(context).size.height * 0.8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header - Fixed at top
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    "Ledger Report Parameters",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallScreen ? 14 : 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    size: isSmallScreen ? 18 : 20,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Search Box - Fixed below header
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: Autocomplete<String>(
                              initialValue: TextEditingValue(
                                text: dialogSelectedGLAccountDisplay ?? '',
                              ),
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) async {
                                    final searchText = textEditingValue.text
                                        .trim();

                                    final query = searchText.isEmpty
                                        ? "select names || ',' || accountcode as accountname from v_accountslist order by names limit 20"
                                        : "select names || ',' || accountcode as accountname from v_accountslist where lower(names) like lower('%$searchText%') order by names limit 50";

                                    try {
                                      final searchResults =
                                          await BackendService.executeRawQuery(
                                            query,
                                          );
                                      return searchResults
                                          .map(
                                            (acc) =>
                                                acc['accountname']
                                                    ?.toString() ??
                                                '',
                                          )
                                          .toList();
                                    } catch (e) {
                                      return const Iterable<String>.empty();
                                    }
                                  },
                              onSelected: (String selection) {
                                final parts = selection.split(',');
                                final accountCode = parts.length > 1
                                    ? parts[1]
                                    : selection;
                                setState(() {
                                  dialogSelectedGLAccount = accountCode;
                                  dialogSelectedGLAccountDisplay = selection;
                                });
                              },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Material(
                                        elevation: 4.0,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxHeight: isVerySmallScreen
                                                ? MediaQuery.of(
                                                        context,
                                                      ).size.height *
                                                      0.3
                                                : MediaQuery.of(
                                                        context,
                                                      ).size.height *
                                                      0.4,
                                            minWidth: constraints.maxWidth - 32,
                                          ),
                                          child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder:
                                                (
                                                  BuildContext context,
                                                  int index,
                                                ) {
                                                  final option = options
                                                      .elementAt(index);
                                                  return ListTile(
                                                    dense: true,
                                                    visualDensity:
                                                        VisualDensity(
                                                          horizontal: 0,
                                                          vertical:
                                                              isSmallScreen
                                                              ? -4
                                                              : -2,
                                                        ),
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                          horizontal:
                                                              isSmallScreen
                                                              ? 12
                                                              : 16,
                                                          vertical:
                                                              isSmallScreen
                                                              ? 6
                                                              : 8,
                                                        ),
                                                    title: Text(
                                                      option,
                                                      style: TextStyle(
                                                        fontSize: isSmallScreen
                                                            ? 12
                                                            : 14,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    onTap: () {
                                                      onSelected(option);
                                                    },
                                                  );
                                                },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                              fieldViewBuilder:
                                  (
                                    BuildContext context,
                                    TextEditingController textEditingController,
                                    FocusNode focusNode,
                                    VoidCallback onFieldSubmitted,
                                  ) {
                                    // Auto-focus when dialog opens
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (focusNode.canRequestFocus) {
                                            focusNode.requestFocus();
                                          }
                                        });

                                    return TextFormField(
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      autofocus: true,
                                      decoration: InputDecoration(
                                        labelText: "Search GL Account",
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: isSmallScreen ? 12 : 16,
                                          vertical: isSmallScreen ? 12 : 16,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            Icons.search,
                                            size: isSmallScreen ? 18 : 20,
                                          ),
                                          onPressed: () {
                                            focusNode.requestFocus();
                                          },
                                        ),
                                        labelStyle: TextStyle(
                                          fontSize: isSmallScreen ? 14 : 16,
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 14 : 16,
                                      ),
                                    );
                                  },
                            ),
                          ),

                          // Scrollable content area
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Selected Account Display
                                  if (dialogSelectedGLAccountDisplay != null &&
                                      dialogSelectedGLAccountDisplay!
                                          .isNotEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.blue.shade100,
                                        ),
                                      ),
                                      child: Text(
                                        "Selected: ${dialogSelectedGLAccountDisplay!}",
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 12 : 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blue.shade800,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                  // Date pickers section
                                  Text(
                                    "Select Date Range:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallScreen ? 13 : 14,
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 8 : 12),

                                  // Date pickers - vertical on small screens
                                  if (isSmallScreen) ...[
                                    Column(
                                      children: [
                                        TextFormField(
                                          decoration: InputDecoration(
                                            labelText: "From Date",
                                            border: const OutlineInputBorder(),
                                            labelStyle: TextStyle(
                                              fontSize: isSmallScreen ? 13 : 14,
                                            ),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: isSmallScreen
                                                      ? 12
                                                      : 14,
                                                ),
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
                                            if (picked != null)
                                              setState(
                                                () => dialogDateFrom = picked,
                                              );
                                          },
                                        ),
                                        SizedBox(height: 8),
                                        TextFormField(
                                          decoration: InputDecoration(
                                            labelText: "To Date",
                                            border: const OutlineInputBorder(),
                                            labelStyle: TextStyle(
                                              fontSize: isSmallScreen ? 13 : 14,
                                            ),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: isSmallScreen
                                                      ? 12
                                                      : 14,
                                                ),
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
                                            if (picked != null)
                                              setState(
                                                () => dialogDateTo = picked,
                                              );
                                          },
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    // Horizontal layout for larger screens
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            decoration: const InputDecoration(
                                              labelText: "From Date",
                                              border: OutlineInputBorder(),
                                              labelStyle: TextStyle(
                                                fontSize: 14,
                                              ),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 14,
                                                  ),
                                            ),
                                            readOnly: true,
                                            controller: TextEditingController(
                                              text: DateFormat(
                                                'yyyy-MM-dd',
                                              ).format(dialogDateFrom),
                                            ),
                                            onTap: () async {
                                              final picked =
                                                  await showDatePicker(
                                                    context: context,
                                                    initialDate: dialogDateFrom,
                                                    firstDate: DateTime(2000),
                                                    lastDate: DateTime(2101),
                                                  );
                                              if (picked != null)
                                                setState(
                                                  () => dialogDateFrom = picked,
                                                );
                                            },
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            decoration: const InputDecoration(
                                              labelText: "To Date",
                                              border: OutlineInputBorder(),
                                              labelStyle: TextStyle(
                                                fontSize: 14,
                                              ),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 14,
                                                  ),
                                            ),
                                            readOnly: true,
                                            controller: TextEditingController(
                                              text: DateFormat(
                                                'yyyy-MM-dd',
                                              ).format(dialogDateTo),
                                            ),
                                            onTap: () async {
                                              final picked =
                                                  await showDatePicker(
                                                    context: context,
                                                    initialDate: dialogDateTo,
                                                    firstDate: DateTime(2000),
                                                    lastDate: DateTime(2101),
                                                  );
                                              if (picked != null)
                                                setState(
                                                  () => dialogDateTo = picked,
                                                );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  SizedBox(height: isSmallScreen ? 16 : 20),

                                  // Action buttons
                                  Container(
                                    padding: EdgeInsets.only(
                                      top: 16,
                                      bottom: isSmallScreen ? 4 : 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        SizedBox(
                                          width: isSmallScreen ? 80 : 100,
                                          child: TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isSmallScreen
                                                    ? 8
                                                    : 12,
                                                vertical: isSmallScreen
                                                    ? 8
                                                    : 12,
                                              ),
                                              minimumSize: Size(0, 36),
                                            ),
                                            child: Text(
                                              "Cancel",
                                              style: TextStyle(
                                                fontSize: isSmallScreen
                                                    ? 13
                                                    : 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: isSmallScreen ? 8 : 12),
                                        SizedBox(
                                          width: isSmallScreen ? 80 : 100,
                                          child: ElevatedButton(
                                            onPressed:
                                                dialogSelectedGLAccount !=
                                                        null &&
                                                    dialogSelectedGLAccount!
                                                        .isNotEmpty
                                                ? () async {
                                                    this.setState(() {
                                                      _selectedGLAccount =
                                                          dialogSelectedGLAccount;
                                                      _selectedGLAccountDisplay =
                                                          dialogSelectedGLAccountDisplay;
                                                      _dateFrom =
                                                          dialogDateFrom;
                                                      _dateTo = dialogDateTo;
                                                    });
                                                    Navigator.pop(context);
                                                    await _loadReport();
                                                  }
                                                : null,
                                            style: ElevatedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isSmallScreen
                                                    ? 8
                                                    : 12,
                                                vertical: isSmallScreen
                                                    ? 8
                                                    : 12,
                                              ),
                                              minimumSize: Size(0, 36),
                                            ),
                                            child: Text(
                                              "Go",
                                              style: TextStyle(
                                                fontSize: isSmallScreen
                                                    ? 13
                                                    : 14,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
        ['Account Code: $_selectedGLAccount'],
        ['Account Name Subsidiary: ${_getAccountName(_selectedGLAccount)}'],
        ['Opening Balance: Rs 0.00'],
        [
          'Transactions From ${DateFormat('yyyy-MM-dd').format(_dateFrom)} Through ${DateFormat('yyyy-MM-dd').format(_dateTo)}',
        ],
        [''], // Empty row
        [
          'Date',
          'Voucher No',
          'Narration',
          'Debit',
          'Credit',
          'Running Balance',
        ],
        ..._reportData.map(
          (row) => [
            _formatCellValue(row['transdate']),
            row['vouchernumber']?.toString() ?? '',
            row['narrationsgl']?.toString() ??
                row['narration']?.toString() ??
                '',
            () {
              final debit = row['debit'] != null
                  ? double.tryParse(row['debit'].toString()) ?? 0
                  : 0;
              return debit > 0
                  ? 'Rs ${NumberFormat('#,##0.00').format(debit)}'
                  : '';
            }(),
            () {
              final credit = row['credit'] != null
                  ? double.tryParse(row['credit'].toString()) ?? 0
                  : 0;
              return credit > 0
                  ? 'Rs ${NumberFormat('#,##0.00').format(credit)}'
                  : '';
            }(),
            () {
              final balance = row['runningbalance'] != null
                  ? double.tryParse(row['runningbalance'].toString()) ?? 0
                  : 0;
              if (balance == 0) return '';
              return balance >= 0
                  ? 'Rs ${NumberFormat('#,##0.00').format(balance)} cr'
                  : 'Rs ${NumberFormat('#,##0.00').format(balance.abs())} dr';
            }(),
          ],
        ),
        // Totals row
        [
          'Total',
          '',
          '',
          'Rs ${NumberFormat('#,##0.00').format(_reportData.fold<double>(0.0, (sum, row) => sum + (row['debit'] != null ? double.tryParse(row['debit'].toString()) ?? 0 : 0)))}',
          'Rs ${NumberFormat('#,##0.00').format(_reportData.fold<double>(0.0, (sum, row) => sum + (row['credit'] != null ? double.tryParse(row['credit'].toString()) ?? 0 : 0)))}',
          '',
        ],
      ];

      String csv = const ListToCsvConverter().convert(csvData);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'ledger_report_$timestamp.csv';

      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        // For desktop platforms, save to Downloads directory
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          final file = File('${directory.path}/$fileName');
          await file.writeAsString(csv);

          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('CSV saved to: ${file.path}')));
        } else {
          // Fallback to documents directory
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$fileName');
          await file.writeAsString(csv);

          if (!context.mounted) return;
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting CSV: $e')));
    }
  }

  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();
      // final currency = NumberFormat('#,##0', 'en_US');
      final dateFormat = DateFormat('dd MMM yy');

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
                    'Opening Balance: Rs 0.00',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Account Statement',
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

            // Account Information
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
                    'Account Code: $_selectedGLAccount',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Account Name: ${_getAccountName(_selectedGLAccount)}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'From: ${DateFormat('dd-MMM-yyyy').format(_dateFrom)} Through ${DateFormat('dd-MMM-yyyy').format(_dateTo)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 15),

            // Data Table
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5), // #
                1: const pw.FlexColumnWidth(1.0), // Date
                2: const pw.FlexColumnWidth(0.8), // Voucher
                3: const pw.FlexColumnWidth(3.0), // Narration
                4: const pw.FlexColumnWidth(1.0), // Debit
                5: const pw.FlexColumnWidth(1.0), // Credit
                6: const pw.FlexColumnWidth(1.5), // Balance
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        '#',
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
                        'Date',
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
                        'Voucher',
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
                        'Details',
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
                        'Debit',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green50,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Credit',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red50,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Balance',
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
                ..._reportData.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final row = entry.value;

                  final debit = (row['debit'] is num)
                      ? row['debit']
                      : double.tryParse(row['debit']?.toString() ?? '0') ?? 0.0;
                  final credit = (row['credit'] is num)
                      ? row['credit']
                      : double.tryParse(row['credit']?.toString() ?? '0') ??
                            0.0;
                  final balance = (row['runningbalance'] is num)
                      ? row['runningbalance']
                      : double.tryParse(
                              row['runningbalance']?.toString() ?? '0',
                            ) ??
                            0.0;

                  return pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          index.toString(),
                          style: const pw.TextStyle(fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          dateFormat.format(
                            DateTime.tryParse(
                                  row['transdate']?.toString() ?? '',
                                ) ??
                                DateTime.now(),
                          ),
                          style: const pw.TextStyle(fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          row['vouchernumber']?.toString() ?? '',
                          style: const pw.TextStyle(fontSize: 8),
                          textAlign: pw.TextAlign.left,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          row['narrationsgl']?.toString() ??
                              row['narration']?.toString() ??
                              '',
                          style: const pw.TextStyle(fontSize: 8),
                          textAlign: pw.TextAlign.left,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        color: PdfColors
                            .green100, //debit > 0 ? PdfColors.lightGreen : PdfColors.green50,
                        child: pw.Text(
                          debit > 0
                              ? 'Rs ${NumberFormat('#,##0.00').format(debit)}'
                              : '',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.black,
                            fontWeight: debit > 0 ? pw.FontWeight.normal : null,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        color: PdfColors
                            .red100, //credit > 0 ? PdfColors.green : PdfColors.green50,
                        child: pw.Text(
                          credit > 0
                              ? 'Rs ${NumberFormat('#,##0.00').format(credit)}'
                              : '',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color:
                                PdfColors.black, //credit > 0 ? PdfColors.red :
                            fontWeight: credit > 0
                                ? pw.FontWeight.normal
                                : null,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          balance != 0
                              ? (balance >= 0
                                    ? 'Rs ${NumberFormat('#,##0.00').format(balance)} cr'
                                    : 'Rs ${NumberFormat('#,##0.00').format(balance.abs())} dr')
                              : '',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: balance < 0
                                ? PdfColors.red
                                : (balance > 0 ? PdfColors.green900 : null),
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }),
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
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        '',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        '',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.left,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        '',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.left,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      color: PdfColors.green100,
                      child: pw.Text(
                        'Rs ${NumberFormat('#,##0.00').format(_reportData.fold<double>(0.0, (sum, row) => sum + ((row['debit'] is num) ? row['debit'] : double.tryParse(row['debit']?.toString() ?? '0') ?? 0.0)))}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.black,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      color: PdfColors.red100,
                      child: pw.Text(
                        'Rs ${NumberFormat('#,##0.00').format(_reportData.fold<double>(0.0, (sum, row) => sum + ((row['credit'] is num) ? row['credit'] : double.tryParse(row['credit']?.toString() ?? '0') ?? 0.0)))}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.black,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        '',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: (() {
                            final totalDebit = _reportData.fold<double>(
                              0.0,
                              (sum, row) =>
                                  sum +
                                  ((row['debit'] is num)
                                      ? row['debit']
                                      : double.tryParse(
                                              row['debit']?.toString() ?? '0',
                                            ) ??
                                            0.0),
                            );
                            final totalCredit = _reportData.fold<double>(
                              0.0,
                              (sum, row) =>
                                  sum +
                                  ((row['credit'] is num)
                                      ? row['credit']
                                      : double.tryParse(
                                              row['credit']?.toString() ?? '0',
                                            ) ??
                                            0.0),
                            );
                            final balance = totalDebit - totalCredit;
                            return balance < 0
                                ? PdfColors.white
                                : (balance > 0 ? PdfColors.white : null);
                          })(),
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Footer
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Generated by Magical Digits Ledger Report - ${DateTime.now()}',
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
      final fileName = 'ledger_report_$timestamp.pdf';

      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        // For desktop platforms, save to Downloads directory
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(await pdf.save());

          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('PDF saved to: ${file.path}')));
        } else {
          // Fallback to documents directory
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(await pdf.save());

          if (!context.mounted) return;
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _suggestionScrollController.dispose();
    super.dispose();
  }
}
