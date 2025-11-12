import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/services/backend_service.dart';
import 'package:app/widgets/navigation_drawer.dart';
import 'package:app/screens/login_screen.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalCustomers = 0;
  int _totalVendors = 0;
  int _totalGLAccounts = 0;
  List<dynamic> _topCustomerBalances = [];
  List<dynamic> _totalItemStocks = [];
  double _totalStockSum = 0.0;
  Map<String, List<Map<String, dynamic>>> _purchaseSummary = {};
  Map<String, List<Map<String, dynamic>>> _salesSummary = {};
  bool _isLoading = true;
  Timer? _refreshTimer;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  bool _showRetryButton = false;
  bool _isRefreshing = false;
  // Load-state flags to detect when each piece finished (success or empty)
  bool _loadedAccountC = false;
  bool _loadedAccountV = false;
  bool _loadedAccountGL = false;
  bool _loadedTopCustomer = false;
  bool _loadedTopStock = false;
  bool _loadedPurchase = false;
  bool _loadedSales = false;
  static const double _bottomRefreshHeight = 80.0;
  String _lastSync = '';

  @override
  void initState() {
    super.initState();
    // Start loading data as soon as the screen appears. Use a post-frame callback
    // to avoid calling async operations synchronously during widget construction.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPeriodicRefresh();
    });
  }

  bool _isDataComplete() {
    return _loadedAccountC &&
        _loadedAccountV &&
        _loadedAccountGL &&
        _loadedTopCustomer &&
        _loadedTopStock &&
        _loadedPurchase &&
        _loadedSales;
  }

  Future<void> _startPeriodicRefresh() async {
    // Reset loader flags
    _loadedAccountC = false;
    _loadedAccountV = false;
    _loadedAccountGL = false;
    _loadedTopCustomer = false;
    _loadedTopStock = false;
    _loadedPurchase = false;
    _loadedSales = false;

    _refreshTimer?.cancel();
    _retryCount = 0;
    _showRetryButton = false;
    _isLoading = true;

    // Run an immediate load first so the UI can stop loading as soon as possible
    await _loadDashboardData();

    if (_isDataComplete()) {
      setState(() {
        _isLoading = false;
        _showRetryButton = false;
      });
      return;
    }

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      await _loadDashboardData();

      if (_isDataComplete()) {
        timer.cancel();
        setState(() {
          _isLoading = false;
          _showRetryButton = false;
        });
      } else {
        _retryCount++;
        if (_retryCount >= _maxRetries) {
          timer.cancel();
          setState(() {
            _isLoading = false;
            _showRetryButton = true;
          });
        }
      }
    });
  }

  Future<void> _loadLastSync() async {
    try {
      // Attempt to read the most recent last_sync from tblsynclogs
      final result = await BackendService.executeRawQuery(
        'SELECT last_sync FROM tblsynclogs ORDER BY id DESC LIMIT 1',
        maxRetries: 2,
        timeout: const Duration(seconds: 10),
      );

      if (result.isNotEmpty) {
        final row = result[0] as Map<String, dynamic>;
        final raw = row['last_sync'] ?? row['lastsync'] ?? row['lastSync'] ?? row.values.firstWhere((v) => v != null, orElse: () => null);

        String formatted;
        if (raw == null) {
          formatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        } else if (raw is DateTime) {
          formatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(raw);
        } else {
          // Try to parse string representation
          try {
            final parsed = DateTime.parse(raw.toString());
            formatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(parsed);
          } catch (_) {
            // Fallback: show raw value as string
            formatted = raw.toString();
          }
        }

        setState(() {
          _lastSync = formatted;
        });
      } else {
        // No rows, fall back to now
        setState(() {
          _lastSync = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        });
      }
    } catch (e) {
      debugPrint('Error loading last sync: $e');
      setState(() {
        _lastSync = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      });
    }
  }

  Future<void> _handleBottomLongPress(LongPressStartDetails details) async {
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refreshing...'), duration: Duration(milliseconds: 500)),
      );
    }
    setState(() {
      _retryCount = 0;
      _showRetryButton = false;
      _isLoading = true;
    });

    // Try to refresh materialized view first (best-effort), then start data load
    await BackendService.refreshMaterializedView();
    _startPeriodicRefresh();
  }

  Future<void> _loadDashboardData() async {
    if (_isRefreshing) return; // Prevent double refreshes
    setState(() => _isRefreshing = true);

    try {
      // Load account counts using direct SQL queries
      await Future.wait([
        _loadAccountCount('C'),
        _loadAccountCount('V'),
        _loadAccountCount('GL'),
      ]);

      // Load top balances
      await Future.wait([
        _loadTopBalances('C'),
        _loadTopBalances('V'), // Load stock in hand so _isDataComplete can succeed
        // _loadTopBalances('GL'), // GL balances intentionally omitted
        _loadPurchaseSummary(),
        _loadSalesSummary(),
      ]);

      // Load last sync time
      await _loadLastSync();

  // Debug output
  debugPrint('=== DASHBOARD DATA LOADED ===');
  debugPrint('Total Customers: $_totalCustomers');
  debugPrint('Total Vendors: $_totalVendors');
  debugPrint('Total GL Accounts: $_totalGLAccounts');
  debugPrint('Top Customer Balances: $_topCustomerBalances');
  // debugPrint('Stock in Hand: $_topVendorBalances');
  // debugPrint('Top GL Balances: removed');
  debugPrint('Last Sync: $_lastSync');
  debugPrint('=============================');
    } catch (e) {
  debugPrint('Error loading dashboard data: $e');
      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dashboard data: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadAccountCount(String accountCategory) async {
    try {
      // Use Supabase RPC function call instead of raw query
      final result = await BackendService.supabase
          .rpc(
            'get_account_count',
            params: {'p_accountcategory': accountCategory},
          )
          .timeout(
            const Duration(seconds: 300), // Increased timeout to 300 seconds
            onTimeout: () {
              throw Exception('Query timed out. Please try again later.');
            },
          );
  debugPrint('Count result for $accountCategory: $result');

      // Handle different possible result formats
      int count = 0;
      if (result is List && result.isNotEmpty) {
        final firstResult = result[0];
        if (firstResult is Map) {
          count = firstResult['count'] ?? firstResult['get_account_count'] ?? 0;
        } else if (firstResult is int) {
          count = firstResult;
        }
      } else if (result is Map) {
        count = result['count'] ?? result['get_account_count'] ?? 0;
      } else if (result is int) {
        count = result;
      }

      setState(() {
        if (accountCategory == 'C') {
          _totalCustomers = count;
          _loadedAccountC = true;
        } else if (accountCategory == 'V') {
          _totalVendors = count;
          _loadedAccountV = true;
        } else if (accountCategory == 'GL') {
          _totalGLAccounts = count;
          _loadedAccountGL = true;
        }
      });
    } catch (e) {
  debugPrint('Error loading count for $accountCategory: $e');
      // Set default values on error
      setState(() {
        if (accountCategory == 'C') {
          _totalCustomers = 0;
          _loadedAccountC = true;
        } else if (accountCategory == 'V') {
          _totalVendors = 0;
          _loadedAccountV = true;
        } else if (accountCategory == 'GL') {
          _totalGLAccounts = 0;
          _loadedAccountGL = true;
        }
      });
    }
  }

  Future<void> _loadPurchaseSummary() async {
    try {
  debugPrint('Loading purchase summary data');

      final result = await BackendService.executeRawQuery(
        'SELECT itemname,suppliername,yearsales,monthsales FROM fn_get_purchase_summary(1)',
      );

      if (result.isNotEmpty) {
        // Group by itemname
        Map<String, List<Map<String, dynamic>>> groupedData = {};
        for (var row in result) {
          String itemName = row['itemname'] ?? 'Unknown Item';
          if (!groupedData.containsKey(itemName)) {
            groupedData[itemName] = [];
          }
          groupedData[itemName]!.add({
            'suppliername': row['suppliername'] ?? 'Unknown Supplier',
            'yearsales': (row['yearsales'] as num?)?.toDouble() ?? 0.0,
            'monthsales': (row['monthsales'] as num?)?.toDouble() ?? 0.0,
          });
        }

        setState(() {
          _purchaseSummary = groupedData;
          _loadedPurchase = true;
        });

  debugPrint('Loaded purchase summary for ${groupedData.length} items');
      } else {
        setState(() {
          _purchaseSummary = {};
          _loadedPurchase = true;
        });
      }
    } catch (e) {
  debugPrint('Error loading purchase summary: $e');
  debugPrint('Stack trace: ${StackTrace.current}');
      setState(() {
        _purchaseSummary = {};
        _loadedPurchase = true;
      });
    }
  }

  Future<void> _loadSalesSummary() async {
    try {
  debugPrint('Loading sales summary data');

      final result = await BackendService.executeRawQuery(
        'SELECT itemname,billprefix,yearsales,monthsales FROM fn_get_sales_summary(1)',
      );

      if (result.isNotEmpty) {
        // Group by itemname
        Map<String, List<Map<String, dynamic>>> groupedData = {};
        for (var row in result) {
          String itemName = row['itemname'] ?? 'Unknown Item';
          if (!groupedData.containsKey(itemName)) {
            groupedData[itemName] = [];
          }
          groupedData[itemName]!.add({
            'billprefix': row['billprefix'] ?? 'Unknown Bill',
            'yearsales': (row['yearsales'] as num?)?.toDouble() ?? 0.0,
            'monthsales': (row['monthsales'] as num?)?.toDouble() ?? 0.0,
          });
        }

        setState(() {
          _salesSummary = groupedData;
          _loadedSales = true;
        });

  debugPrint('Loaded sales summary for ${groupedData.length} items');
      } else {
        setState(() {
          _salesSummary = {};
          _loadedSales = true;
        });
      }
    } catch (e) {
  debugPrint('Error loading sales summary: $e');
  debugPrint('Stack trace: ${StackTrace.current}');
      setState(() {
        _salesSummary = {};
        _loadedSales = true;
      });
    }
  }

  Future<void> _loadTopBalances(
    String p_accountcode, [
    String? p_accounttype,
  ]) async {
  // Map category codes to actual database codes
  String actualAccountCode;

    if (p_accountcode == 'C') {
      actualAccountCode = '2';
    } else if (p_accountcode == 'V') {
      // For stock in hand, use raw SQL queries instead of RPC
      try {
  debugPrint('Loading stock in hand data');

        // Load data for store 1
        final result1 = await BackendService.executeRawQuery(
          'SELECT Storename, address, totalstock FROM fn_displaystock_storewise(1)',
        );

        // Load data for store 2
        final result2 = await BackendService.executeRawQuery(
          'SELECT Storename, address, totalstock FROM fn_displaystock_storewise(20)',
        );

        // Combine results
        List<dynamic> combinedResults = [];
        if (result1.isNotEmpty) {
          combinedResults.addAll(result1);
        }
        if (result2.isNotEmpty) {
          combinedResults.addAll(result2);
        }

        // Map to a consistent format: use 'name' and 'stock' keys
        List<dynamic> mappedData = combinedResults.map((item) {
          final storeName = (item['storename'] ?? item['Storename'] ?? item['store'] ?? 'Unknown Store').toString();
          final stockValue = (item['totalstock'] ?? item['total_stock'] ?? item['stock'] ?? 0) as dynamic;
          final stockDouble = (stockValue is num) ? stockValue.toDouble() : double.tryParse(stockValue.toString()) ?? 0.0;

          return {
            'name': storeName,
            'stock': stockDouble,
          };
        }).toList();

        // Calculate total stock in hand using the standardized 'stock' key
        double totalStock = mappedData.fold(
          0.0,
          (sum, item) => sum + ((item['stock'] as num?)?.toDouble() ?? 0.0),
        );
  debugPrint('Total stock in hand: $totalStock');

        setState(() {
          _totalItemStocks = mappedData.take(5).toList();
          _totalStockSum = totalStock;
          _loadedTopStock = true;
        });

  debugPrint('Set ${mappedData.take(5).length} stock items');

        // Force UI update
        setState(() {});
      } catch (e) {
        print('Error loading stock in hand: $e');
        print('Stack trace: ${StackTrace.current}');
        setState(() {
          _totalItemStocks = [];
          _loadedTopStock = true;
        });
      }
      return;
    } else if (p_accountcode == 'GL') {
      actualAccountCode = '19';
    } else {
      throw ArgumentError('Invalid account code: $p_accountcode');
    }

    try {
      print('Loading top balances for category: $p_accountcode (mapped to $actualAccountCode)');

      // Build the stored-proc call: sp_gettop5balances(accountcode, accounttype)
  // Call the stored-proc with only the account code (single argument)
  final query = "select * from sp_gettop5balances('${actualAccountCode}')";
      print('Executing query for top balances: $query');

      // Use a short timeout and fewer retries for this heavy stored-proc to avoid
      // long blocking retries when the server cancels the statement.
      final result = await BackendService.executeRawQuery(
        query,
        maxRetries: 2,
        timeout: const Duration(seconds: 10),
      );

      if (result.isNotEmpty) {
        final dataList = result.map((row) {
      // Normalize possible column names returned by the stored-proc. Some DB
      // versions return 'names' (plural) instead of 'name' or 'accountname'.
      final accountName = row['accountname'] ??
        row['AccountName'] ??
        row['name'] ??
        row['names'] ??
        row['Names'] ??
        'Unknown';
      final subsidiary = row['accountnamesubsidiary'] ??
        row['AccountNameSubsidairy'] ??
        row['subsidiary'] ??
        row['accountnamesubsidiary'] ??
        null;
          final name = (subsidiary != null && subsidiary.toString().isNotEmpty) ? '${accountName} (${subsidiary})' : accountName.toString();

          final balRaw = row['balance'] ?? row['Balance'] ?? row['bal'] ?? row['closingbalance'] ?? row['closing_balance'] ?? 0;
          final balanceValue = (balRaw is num) ? balRaw.toDouble() : double.tryParse(balRaw.toString()) ?? 0.0;

          return {
            'name': name,
            'balance': balanceValue,
            'accountname': row['accountname'] ?? row['names'] ?? row['Name'] ?? null,
            'accountnamesubsidiary': row['accountnamesubsidiary'] ?? subsidiary,
          };
        }).toList();

        setState(() {
          if (p_accountcode == 'C') {
            _topCustomerBalances = dataList.take(5).toList();
            _loadedTopCustomer = true;
          }
        });

  debugPrint('Set ${dataList.take(5).length} items for $p_accountcode');
        setState(() {});
      } else {
        // If the RPC returned empty, set an empty list but mark loader finished
        setState(() {
          if (p_accountcode == 'C') {
            _topCustomerBalances = [];
            _loadedTopCustomer = true;
          }
        });
      }
    } catch (e) {
      print('Error loading top balances for $p_accountcode: $e');
      print('Stack trace: ${StackTrace.current}');
      // On error, set empty data and mark loader finished so refresh loop can stop
      setState(() {
        if (p_accountcode == 'C') {
          _topCustomerBalances = [];
          _loadedTopCustomer = true;
        }
      });
    }
  }

  void _logout() {
    // Clear user session
    UserSession.clearUser();

    // Navigate back to login screen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false, // Remove all previous routes
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh dashboard data',
            onPressed: () async {
              setState(() {
                _retryCount = 0;
                _showRetryButton = false;
                _isLoading = true;
              });

              // First run refreshMaterializedView, then refresh until all data is loaded
              await BackendService.refreshMaterializedView(viewName: 'mv_generalledger');
              await _startPeriodicRefresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip:
                'User ${UserSession.getUsername() ?? 'Unknown'} exit from app',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: const AppNavigationDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _retryCount = 0;
            _showRetryButton = false;
            _isLoading = true;
          });

          // Best-effort: refresh the materialized view first
          await BackendService.refreshMaterializedView();

          await _loadDashboardData();

          if (_isDataComplete()) {
            setState(() {
              _isLoading = false;
              _showRetryButton = false;
            });
          } else {
            // Start periodic retrying if data is not complete yet
            await _startPeriodicRefresh();
          }
        },
        color: Colors.blueAccent,
        child: Stack(
          children: [
            Stack(
              children: [
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _showRetryButton
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Unable to load dashboard data after multiple attempts.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  _retryCount = 0;
                                  _showRetryButton = false;
                                  _isLoading = true;
                                });

                                await BackendService.refreshMaterializedView();
                                _startPeriodicRefresh();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // First Row - Summary Cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryCard(
                                    'Total Customers',
                                    _totalCustomers.toString(),
                                    Icons.people,
                                    Colors.blue,
                                  ),
                                ),
                                SizedBox(
                                  width: isSmallScreen
                                      ? 8
                                      : (isMediumScreen ? 12 : 16),
                                ),
                                Expanded(
                                  child: _buildSummaryCard(
                                    'Total Vendors',
                                    _totalVendors.toString(),
                                    Icons.business,
                                    Colors.green,
                                  ),
                                ),
                                SizedBox(
                                  width: isSmallScreen
                                      ? 8
                                      : (isMediumScreen ? 12 : 16),
                                ),
                                Expanded(
                                  child: _buildSummaryCard(
                                    'Total GL Accounts',
                                    _totalGLAccounts.toString(),
                                    Icons.account_balance,
                                    Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 16 : 24),

                            // Second Row - Top Balances
                            if (isSmallScreen)
                              Column(
                                children: [
                                  _buildTopBalancesCard(
                                    'Top Customer Balances',
                                    _topCustomerBalances,
                                    Colors.blue,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTopBalancesCard(
                                    'Stock in Hand',
                                    _totalItemStocks,
                                    Colors.green,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPurchaseSummaryCard(),
                                  const SizedBox(height: 16),
                                  _buildSalesSummaryCard(),
                                  const SizedBox(height: 16),
                                  // Removed GL Account Balances card
                                ],
                              )
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildTopBalancesCard(
                                      'Top Customer Balances',
                                      _topCustomerBalances,
                                      Colors.blue,
                                    ),
                                  ),
                                  SizedBox(width: isMediumScreen ? 12 : 16),
                                  Expanded(
                                    child: _buildTopBalancesCard(
                                      'Stock in Hand',
                                      _totalItemStocks,
                                      Colors.green,
                                      totalStockSum: _totalStockSum,
                                    ),
                                  ),
                                  SizedBox(width: isMediumScreen ? 12 : 16),
                                  Expanded(child: _buildPurchaseSummaryCard()),
                                  SizedBox(width: isMediumScreen ? 12 : 16),
                                  Expanded(child: _buildSalesSummaryCard()),
                                ],
                              ),
                          ],
                        ),
                      ),
                // Invisible overlay for bottom long-press detection
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: _bottomRefreshHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onLongPressStart: _handleBottomLongPress,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
            ),
            // Bottom refresh area
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: _bottomRefreshHeight,
              child: GestureDetector(
                onLongPressStart: (details) async {
                  final screenHeight = MediaQuery.of(context).size.height;
                  final touchY = details.globalPosition.dy;
                  final bottomThreshold = screenHeight - _bottomRefreshHeight;

                  if (touchY >= bottomThreshold) {
                    // Haptic feedback
                    HapticFeedback.mediumImpact();

                    // Visual feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Refreshing...'),
                        duration: Duration(milliseconds: 500),
                      ),
                    );

                    // Trigger refresh
                    setState(() {
                      _retryCount = 0;
                      _showRetryButton = false;
                      _isLoading = true;
                    });

                    // Best-effort refresh of materialized view first
                    await BackendService.refreshMaterializedView();
                    _startPeriodicRefresh();
                  }
                },
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: _isRefreshing
                        ? const CircularProgressIndicator()
                        : Icon(
                            Icons.refresh,
                            color: Colors.grey.withOpacity(0.5),
                            size: 24,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
          color: Colors.grey.shade100,
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (UserSession.getUsername() != null) ...[
                Text(
                  'User: ${UserSession.getUsername()}',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'Last Sync: ${_lastSync.isNotEmpty ? _lastSync : DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = MediaQuery.of(context).size.width < 600;
        final iconSize = isSmallScreen ? 28.0 : 32.0;
        final titleFontSize = isSmallScreen ? 11.0 : 12.0;
        final valueFontSize = isSmallScreen ? 18.0 : 20.0;
        final padding = isSmallScreen ? 12.0 : 16.0;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              children: [
                Icon(icon, size: iconSize, color: color),
                SizedBox(height: isSmallScreen ? 6 : 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isSmallScreen ? 3 : 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSalesSummaryCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 600;
        final titleFontSize = isSmallScreen ? 13.0 : 14.0;
        final headerFontSize = isSmallScreen ? 10.0 : 11.0;
        final itemFontSize = isSmallScreen ? 10.0 : 11.0;
        final padding = isSmallScreen ? 12.0 : 16.0;
        final spacing = isSmallScreen ? 8.0 : 12.0;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_salesSummary.isEmpty)
                  Text(
                    'No sales summary data available',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: Colors.grey,
                    ),
                  )
                else
                  ..._salesSummary.entries.map((entry) {
                    String itemName = entry.key;
                    List<Map<String, dynamic>> bills = entry.value;

                    // Calculate totals for this item
                    double totalYearSales = bills.fold(
                      0.0,
                      (sum, bill) => sum + (bill['yearsales'] ?? 0.0),
                    );
                    double totalMonthSales = bills.fold(
                      0.0,
                      (sum, bill) => sum + (bill['monthsales'] ?? 0.0),
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item heading
                        Text(
                          'Total Sales ($itemName)',
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: spacing),
                        // Header row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Bill Prefix',
                                style: TextStyle(
                                  fontSize: headerFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Current Year ',
                                style: TextStyle(
                                  fontSize: headerFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Current Month',
                                style: TextStyle(
                                  fontSize: headerFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        // Bill rows
                        ...bills.map((bill) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: isSmallScreen ? 6.0 : 8.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    bill['billprefix'] ?? 'Unknown',
                                    style: TextStyle(fontSize: itemFontSize),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    NumberFormat(
                                      '#,##0',
                                    ).format(bill['yearsales'] ?? 0),
                                    style: TextStyle(
                                      fontSize: itemFontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    NumberFormat(
                                      '#,##0',
                                    ).format(bill['monthsales'] ?? 0),
                                    style: TextStyle(
                                      fontSize: itemFontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        // Total row
                        const Divider(),
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: isSmallScreen ? 6.0 : 8.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: itemFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  NumberFormat('#,##0').format(totalYearSales),
                                  style: TextStyle(
                                    fontSize: itemFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  NumberFormat('#,##0').format(totalMonthSales),
                                  style: TextStyle(
                                    fontSize: itemFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Add spacing between items
                        if (_salesSummary.entries.last.key != itemName)
                          SizedBox(height: spacing * 2),
                      ],
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPurchaseSummaryCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 600;
        final titleFontSize = isSmallScreen ? 13.0 : 14.0;
        final headerFontSize = isSmallScreen ? 10.0 : 11.0;
        final itemFontSize = isSmallScreen ? 10.0 : 11.0;
        final padding = isSmallScreen ? 12.0 : 16.0;
        final spacing = isSmallScreen ? 8.0 : 12.0;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_purchaseSummary.isEmpty)
                  Text(
                    'No purchase summary data available',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: Colors.grey,
                    ),
                  )
                else
                  ..._purchaseSummary.entries.map((entry) {
                    String itemName = entry.key;
                    List<Map<String, dynamic>> suppliers = entry.value;

                    // Calculate totals for this item
                    double totalYearSales = suppliers.fold(
                      0.0,
                      (sum, supplier) => sum + (supplier['yearsales'] ?? 0.0),
                    );
                    double totalMonthSales = suppliers.fold(
                      0.0,
                      (sum, supplier) => sum + (supplier['monthsales'] ?? 0.0),
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item heading
                        Text(
                          'Total Purchase ($itemName)',
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        SizedBox(height: spacing),
                        // Header row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Supplier Name',
                                style: TextStyle(
                                  fontSize: headerFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Current Year ',
                                style: TextStyle(
                                  fontSize: headerFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Current Month ',
                                style: TextStyle(
                                  fontSize: headerFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        // Supplier rows
                        ...suppliers.map((supplier) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: isSmallScreen ? 6.0 : 8.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    supplier['suppliername'] ?? 'Unknown',
                                    style: TextStyle(fontSize: itemFontSize),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    NumberFormat(
                                      '#,##0',
                                    ).format(supplier['yearsales'] ?? 0),
                                    style: TextStyle(
                                      fontSize: itemFontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    NumberFormat(
                                      '#,##0',
                                    ).format(supplier['monthsales'] ?? 0),
                                    style: TextStyle(
                                      fontSize: itemFontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        // Total row
                        const Divider(),
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: isSmallScreen ? 6.0 : 8.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: itemFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  NumberFormat('#,##0').format(totalYearSales),
                                  style: TextStyle(
                                    fontSize: itemFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  NumberFormat('#,##0').format(totalMonthSales),
                                  style: TextStyle(
                                    fontSize: itemFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Add spacing between items
                        if (_purchaseSummary.entries.last.key != itemName)
                          SizedBox(height: spacing * 2),
                      ],
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBalancesCard(
    String title,
    List<dynamic> balances,
    Color color, {
    double? totalStockSum,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 600;
        final titleFontSize = isSmallScreen ? 13.0 : 14.0;
        final headerFontSize = isSmallScreen ? 10.0 : 11.0;
        final itemFontSize = isSmallScreen ? 10.0 : 11.0;
        final padding = isSmallScreen ? 12.0 : 16.0;
        final spacing = isSmallScreen ? 8.0 : 12.0;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                SizedBox(height: spacing),
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Name',
                      style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      'Balance',
                      style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                if (balances.isEmpty)
                  Text(
                    'No data available',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: Colors.grey,
                    ),
                  )
                else
                  ...balances.map((balance) {
                    // Prefer canonical keys inserted by loader: 'name' and 'balance' or 'stock'
                    final name = (balance['name'] ?? balance['accountname'] ?? balance['accountnamesubsidiary'] ?? balance['Store '] ?? balance['names'] ?? 'Unknown').toString();

                    double balanceValue = 0.0;
                    if (title == 'Stock in Hand') {
                      // Try canonical 'stock' first, fall back to other keys
                      final v = balance['stock'] ?? balance['Stock'] ?? balance['totalstock'] ?? balance['total_stock'] ?? 0;
                      if (v is num) {
                        balanceValue = v.toDouble();
                      } else {
                        balanceValue = double.tryParse(v.toString()) ?? 0.0;
                      }
                    } else {
                      final v = balance['balance'] ?? balance['Balance'] ?? balance['bal'] ?? 0;
                      if (v is num) {
                        balanceValue = v.toDouble();
                      } else {
                        balanceValue = double.tryParse(v.toString()) ?? 0.0;
                      }
                    }

                    final formattedBalance = title == 'Stock in Hand'
                        ? NumberFormat('#,##0').format(balanceValue)
                        : NumberFormat('#,##0.00').format(balanceValue);
                    final displayBalance = title == 'Stock in Hand' ? formattedBalance : 'Rs $formattedBalance';

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: isSmallScreen ? 6.0 : 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name.toString(),
                              style: TextStyle(fontSize: itemFontSize),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Text(
                            displayBalance,
                            style: TextStyle(
                              fontSize: itemFontSize,
                              fontWeight: FontWeight.w500,
                              color: balanceValue < 0
                                  ? Colors.red
                                  : Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                // Add total row for Stock in Hand
                if (title == 'Stock in Hand' && totalStockSum != null)
                  Column(
                    children: [
                      const Divider(),
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: isSmallScreen ? 6.0 : 8.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(
                                fontSize: itemFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              NumberFormat('#,##0').format(totalStockSum),
                              style: TextStyle(
                                fontSize: itemFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
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
        );
      },
    );
  }
}
