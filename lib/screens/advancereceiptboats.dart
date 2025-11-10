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
  List<dynamic> _boats = [];
  String? _selectedBoat;

  @override
  void initState() {
    super.initState();
    _loadBoats();
  }


    

  Future<void> _loadBoats() async {
    try {
      // Load boats from V_boats view - select all columns
      // await _refreshCustomerBalanceSummaryBoats();
      final boats = await BackendService.executeRawQuery(
        'Select * from V_boats',
      );
      print('Loaded ${boats.length} boats');
      if (boats.isNotEmpty) {
        print('First boat: ${boats[0]}');
      }
      setState(() {
        _boats = [
          {'boatname': 'All'},
          ...boats.where(
            (boat) => boat['boatname'] != 'All',
          ), // Remove any duplicate 'All' entries
        ]; // Add "All" option at the beginning
        _selectedBoat = 'All'; // Default to "All"
      });
      // Show parameter dialog instead of loading report automatically
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showParameterDialog(context);
      });
    } catch (e) {
      print('Error loading boats: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading boats: $e')));
    }
  }

  // Test search functionality
  // Future<void> _refreshCustomerBalanceSummaryBoats() async {
  //   try {
  //     final response = await BackendService.supabase
  //         .rpc('fn_refresh_mv_customer_balance_summary_boats');

  //     print('Materialized view refreshed successfully: $response');
  //   } catch (e) {
  //     print('Error refreshing customer balance summary boats: $e');
  //   }
  // }
  void _testSearch(String query) {
    final results = _boats.where((boat) {
      final boatName = boat['boatname']?.toString() ?? '';
      final searchText = query.toLowerCase();
      return boatName.toLowerCase().contains(searchText);
    }).toList();

    print('Search query: "$query"');
    print('Results found: ${results.length}');
    if (results.isNotEmpty) {
      print('First result: ${results[0]['boatname']}');
    }
  }

  Future<void> _loadReport() async {
    if (_selectedBoat == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_selectedBoat == 'All') {
        // For "All" boats, use the original query
        final query =
            "Select customername, bill_amount_balance, advance, cheque_bounced, pdc, total from public.mv_customer_balance_summary_boats Where 1 = 1 Order by customername";

        print('Loading report with query: $query');

        final data = await BackendService.executeRawQuery(query);

        print('Received data length: ${data.length}');
        if (data.isNotEmpty) {
          print('First record: ${data[0]}');
        }

        setState(() {
          _reportData = data;
        });
      } else {
        // Extract customer ID from boat selection (after comma)
        final parts = _selectedBoat!.split(',');
        final customerId = parts.length > 1 ? parts[1] : _selectedBoat;

        print('Extracted customer ID: $customerId');

        // Query tblcustomers to get customer name using customerID_PK
        final customerQuery =
            "SELECT customername FROM tblcustomers WHERE customerid_pk = '$customerId'";
        final customerData = await BackendService.executeRawQuery(
          customerQuery,
        );

        if (customerData.isNotEmpty) {
          final customerName = customerData.first['customername'];
          print('Found customer name: $customerName');

          // Query mv_customer_balance_summary_boats materialized view directly
          int retryCount = 0;
          const int maxRetries = 10;
          dynamic data;

          while (retryCount < maxRetries) {
            try {
              print('Querying mv_customer_balance_summary_boats for customer: $customerName (attempt ${retryCount + 1}/$maxRetries)');
              final query = "SELECT * FROM mv_customer_balance_summary_boats WHERE customername = '$customerName'";
              data = await BackendService.executeRawQuery(query)
                  .timeout(
                    const Duration(
                      seconds: 600,
                    ), // Increased timeout to 600 seconds
                    onTimeout: () {
                      throw Exception(
                        'Query timed out. Please try selecting a different boat or contact support.',
                      );
                    },
                  );
              print('mv_customer_balance_summary_boats query executed successfully on attempt ${retryCount + 1}');
              break; // Success, exit retry loop
            } catch (e) {
              retryCount++;
              if (retryCount >= maxRetries) {
                throw Exception('Failed after $maxRetries attempts: $e');
              }
              // Wait before retrying with longer delays
              final waitTime = Duration(seconds: retryCount * 5); // 5, 10, 15, 20... seconds
              print('Retrying mv_customer_balance_summary_boats query (attempt $retryCount/$maxRetries) after ${waitTime.inSeconds} seconds...');
              await Future.delayed(waitTime);
            }
          }

          print('Received data from get_customer_balance by boats: $data');

          setState(() {
            _reportData = data is List ? data : [data];
          });
        } else {
          print('Customer not found for ID: $customerId');
          setState(() {
            _reportData = [];
          });
        }
      }
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
        title: const Text('NOC Report - Boats'),
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
                  "Boat: ${_selectedBoat == 'All' ? 'All Boats' : _selectedBoat}",
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
                        columnSpacing: 16.0, // Increased from 6.0 to 16.0
                        horizontalMargin: 12.0, // Added horizontal margin
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
                            label: SizedBox(
                              width: 120, // Fixed width for customer name
                              child: Text(
                                'Customer Name',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 80, // Fixed width for bill amount
                              child: Text(
                                'Bill Amount',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 70, // Fixed width for advance
                              child: Text(
                                'Advance',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 80, // Fixed width for cheque bounced
                              child: Text(
                                'Chq Bounced',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 60, // Fixed width for PDC
                              child: Text(
                                'PDC',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 80, // Fixed width for total
                              child: Text(
                                'Total',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                        rows: [
                          ..._reportData.map((row) {
                            final billAmountBalance =
                                row['bill_amount_balance'] != null
                                ? double.tryParse(
                                        row['bill_amount_balance'].toString(),
                                      ) ??
                                      0
                                : 0;
                            final advance = row['advance'] != null
                                ? double.tryParse(row['advance'].toString()) ??
                                      0
                                : 0;
                            final chequeBounced = row['cheque_bounced'] != null
                                ? double.tryParse(
                                        row['cheque_bounced'].toString(),
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
                                  SizedBox(
                                    width: 120, // Match column width
                                    child: Text(
                                      row['customername']?.toString() ?? '',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 80, // Match column width
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
                                                  : Colors.grey),
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 70, // Match column width
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
                                                  : Colors.grey),
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 80, // Match column width
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
                                                  : Colors.grey),
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 70, // Match column width
                                    child: Text(
                                      pdc != 0
                                          ? NumberFormat('#,##0.00').format(pdc)
                                          : '',
                                      style: TextStyle(
                                        color: pdc < 0
                                            ? Colors.red
                                            : (pdc > 0
                                                  ? Colors.black
                                                  : Colors.grey),
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 90, // Match column width
                                    child: Text(
                                      total != 0
                                          ? NumberFormat(
                                              '#,##0.00',
                                            ).format(total)
                                          : '',
                                      style: TextStyle(
                                        color: total < 0
                                            ? Colors.red
                                            : (total > 0
                                                  ? Colors.black
                                                  : Colors.grey),
                                      ),
                                      textAlign: TextAlign.right,
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
                                SizedBox(
                                  width: 120,
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
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    NumberFormat('#,##0.00').format(
                                      _reportData.fold<double>(
                                        0.0,
                                        (sum, row) =>
                                            sum +
                                            (row['bill_amount_balance'] != null
                                                ? double.tryParse(
                                                        row['bill_amount_balance']
                                                            .toString(),
                                                      ) ??
                                                      0
                                                : 0),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10.5,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 70,
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
                                      fontSize: 10.5,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    NumberFormat('#,##0.00').format(
                                      _reportData.fold<double>(
                                        0.0,
                                        (sum, row) =>
                                            sum +
                                            (row['cheque_bounced'] != null
                                                ? double.tryParse(
                                                        row['cheque_bounced']
                                                            .toString(),
                                                      ) ??
                                                      0
                                                : 0),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10.5,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 75,
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
                                      fontSize: 10.5,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 85,
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
                                      fontSize: 10.5,
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

  String _getBoatName(String? boatName) {
    if (boatName == null) return '';
    final boat = _boats.firstWhere(
      (b) => b['boatname'] == boatName,
      orElse: () => null,
    );
    return boat?['boatname'] ?? '';
  }

  // Remove unused variables and methods
  void _removeUnusedVariables() {
    // This method is just to satisfy the compiler
  }

  Future<void> _showParameterDialog(BuildContext context) async {
    String? dialogSelectedBoat = _selectedBoat;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Align(
              alignment: Alignment.topCenter,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 400;
                  final isVerySmallScreen = constraints.maxHeight < 600;

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isSmallScreen ? double.infinity : 500,
                      maxHeight: isVerySmallScreen
                          ? MediaQuery.of(context).size.height * 0.9
                          : MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      insetPadding: const EdgeInsets.all(16),
                      child: Container(
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
                                  bottom: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      "NOC Report (Boats) Parameters",
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
                                  bottom: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                              child: Autocomplete<String>(
                                initialValue: TextEditingValue(
                                  text: dialogSelectedBoat ?? '',
                                ),
                                optionsBuilder:
                                    (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return _boats
                                            .map(
                                              (boat) =>
                                                  boat['boatname']
                                                      ?.toString() ??
                                                  '',
                                            )
                                            .toList();
                                      }
                                      return _boats
                                          .map(
                                            (boat) =>
                                                boat['boatname']?.toString() ??
                                                '',
                                          )
                                          .where(
                                            (boatName) =>
                                                boatName.toLowerCase().contains(
                                                  textEditingValue.text
                                                      .toLowerCase(),
                                                ),
                                          )
                                          .toList();
                                    },
                                onSelected: (String selection) {
                                  setState(() {
                                    dialogSelectedBoat = selection;
                                  });
                                },
                                optionsViewBuilder:
                                    (context, onSelected, options) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Material(
                                          elevation: 4.0,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                              minWidth:
                                                  constraints.maxWidth - 32,
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
                                                          fontSize:
                                                              isSmallScreen
                                                              ? 12
                                                              : 14,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                                      TextEditingController
                                      textEditingController,
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
                                          labelText: "Search Boat",
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
                                padding: EdgeInsets.all(
                                  isSmallScreen ? 12 : 16,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Selected Boat Display
                                    if (dialogSelectedBoat != null &&
                                        dialogSelectedBoat!.isNotEmpty &&
                                        dialogSelectedBoat != 'All')
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.blue.shade100,
                                          ),
                                        ),
                                        child: Text(
                                          "Selected: $dialogSelectedBoat",
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 12 : 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.blue.shade800,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),

                                    SizedBox(height: isSmallScreen ? 8 : 16),

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
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
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
                                          SizedBox(
                                            width: isSmallScreen ? 8 : 12,
                                          ),
                                          SizedBox(
                                            width: isSmallScreen ? 80 : 100,
                                            child: ElevatedButton(
                                              onPressed:
                                                  dialogSelectedBoat != null &&
                                                      dialogSelectedBoat!
                                                          .isNotEmpty
                                                  ? () async {
                                                      this.setState(() {
                                                        _selectedBoat =
                                                            dialogSelectedBoat;
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
                      ),
                    ),
                  );
                },
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
        ['Boat: ${_selectedBoat == 'All' ? 'All Boats' : _selectedBoat}'],
        ['NOC Report'],
        [''], // Empty row
        [
          'Customer Name',
          'Bill Amount',
          'Advance',
          'Cheque Bounced',
          'PDC',
          'Total',
        ],
        ..._reportData.map(
          (row) => [
            row['customername']?.toString() ?? '',
            () {
              final billAmountBalance = row['bill_amount_balance'] != null
                  ? double.tryParse(row['bill_amount_balance'].toString()) ?? 0
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
              final chequeBounced = row['cheque_bounced'] != null
                  ? double.tryParse(row['cheque_bounced'].toString()) ?? 0
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
                  (row['bill_amount_balance'] != null
                      ? double.tryParse(
                              row['bill_amount_balance'].toString(),
                            ) ??
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
                  (row['cheque_bounced'] != null
                      ? double.tryParse(row['cheque_bounced'].toString()) ?? 0
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
                    'NOC Report (Boats)',
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
                    'NOC Report (Boats)',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Boat: ${_selectedBoat == 'All' ? 'All Boats' : _selectedBoat}',
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
                        'Bill Amount',
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
                  final billAmountBalance = (row['bill_amount_balance'] is num)
                      ? row['bill_amount_balance']
                      : double.tryParse(
                              row['bill_amount_balance']?.toString() ?? '0',
                            ) ??
                            0.0;
                  final advance = (row['advance'] is num)
                      ? row['advance']
                      : double.tryParse(row['advance']?.toString() ?? '0') ??
                            0.0;
                  final chequeBounced = (row['cheque_bounced'] is num)
                      ? row['cheque_bounced']
                      : double.tryParse(
                              row['cheque_bounced']?.toString() ?? '0',
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
                                ((row['bill_amount_balance'] is num)
                                    ? row['bill_amount_balance']
                                    : double.tryParse(
                                            row['bill_amount_balance']
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
                                ((row['cheque_bounced'] is num)
                                    ? row['cheque_bounced']
                                    : double.tryParse(
                                            row['cheque_bounced']?.toString() ??
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
      final fileName = 'NOC_boats_${timestamp}.pdf';

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
