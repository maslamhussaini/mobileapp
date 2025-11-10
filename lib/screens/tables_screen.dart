import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:app/services/backend_service.dart';
import 'package:app/widgets/export_buttons.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  List<String> _tables = [];
  String? _selectedTable;
  List<dynamic> _data = [];
  List<String> _columns = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    try {
      // Test connection - Prisma has been removed
      final response = await BackendService.getAll(
        'tblUsers',
        page: 1,
        limit: 1,
      ); // Test connection
      // For now, hardcode the main tables - in production, you could introspect schema
      setState(() {
        _tables = [
          'tblUsers',
          'tblCustomers',
          'tblSuppliers',
          'tblItems',
          'tblSales',
          'tblPurchases',
          'tblBanks',
          'tblBoats',
          'tblGeneralLedger',
          'tblCheques',
          'tblStores',
          'tblChartOfAccounts1',
          'tblChartOfAccounts2',
        ];
      });
    } catch (e) {
      // Fallback to basic tables if connection fails
      setState(() {
        _tables = ['tblUsers', 'tblCustomers', 'tblItems'];
      });
    }
  }

  Future<void> _loadTableData(String table) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await BackendService.getAll(table, page: _currentPage);
      setState(() {
        _data = data;
        if (data.isNotEmpty) {
          _columns = data[0].keys.toList();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onTableSelected(String? table) {
    setState(() {
      _selectedTable = table;
      _currentPage = 1;
    });
    if (table != null) {
      _loadTableData(table);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tables')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: _selectedTable,
              hint: const Text('Select a table'),
              items: _tables.map((table) {
                return DropdownMenuItem(value: table, child: Text(table));
              }).toList(),
              onChanged: _onTableSelected,
            ),
          ),
          if (_selectedTable != null) ...[
            ExportButtons(
              data: _data,
              columns: _columns,
              filename: _selectedTable!,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : DataTable2(
                      columns: _columns
                          .map((col) => DataColumn(label: Text(col)))
                          .toList(),
                      rows: _data.map((row) {
                        return DataRow(
                          cells: _columns
                              .map(
                                (col) =>
                                    DataCell(Text(row[col]?.toString() ?? '')),
                              )
                              .toList(),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new record
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
