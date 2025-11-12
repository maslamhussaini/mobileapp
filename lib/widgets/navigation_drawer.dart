import 'package:flutter/material.dart';
import 'package:app/services/backend_service.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/screens/reportout.dart';
import 'package:app/screens/advancereceipts.dart' as receipts;
import 'package:app/screens/advancereceiptboats.dart';
import 'package:app/screens/reportout.dart';
import 'package:app/screens/login_screen.dart';
import 'package:intl/intl.dart';
import 'package:app/build_info.dart';

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({super.key});

  @override

  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // 🧭 Responsive Drawer Width
    // - Mobile: 80% of screen
    // - Tablet/Desktop: 320px fixed
    final drawerWidth = screenWidth < 500 ? screenWidth * 0.8 : 320.0;

    return SafeArea(
      child: SizedBox(
        width: drawerWidth,
        child: Drawer(
          elevation: 8,
          child: Column(
            children: [
              // 🔹 Compact Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.lightBlueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MD Accounting System',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (UserSession.getUsername() != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'User: ${UserSession.getUsername()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 🔹 Navigation Items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.dashboard_outlined,
                        color: Colors.blue,
                      ),
                      title: const Text('Dashboard'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DashboardScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.receipt_long_outlined,
                        color: Colors.orange,
                      ),
                      title: const Text('Ledger'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportOutScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.receipt_long_outlined,
                        color: Colors.orange,
                      ),
                      title: const Text('NOC Reports'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const receipts.AdvanceReceipts(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.directions_boat_outlined,
                        color: Colors.teal,
                      ),
                      title: const Text('NOC Report (Boats)'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdvanceReceipts(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.help_outline,
                        color: Colors.purple,
                      ),
                      title: const Text('Hint Key'),
                      onTap: () async {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        final userId = UserSession.getUserId();
                        if (userId != null) {
                          try {
                            final query =
                                "Select hintkey from tblusers where userid_pk = $userId";
                            final result = await BackendService.executeRawQuery(
                              query,
                            );
                            if (result.isNotEmpty) {
                              final hintKey = result.first['hintkey'];
                              if (hintKey != null &&
                                  hintKey.toString().isNotEmpty) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Remember your hint key: $hintKey - it will be used to reveal your password',
                                    ),
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              } else {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('No hint key available'),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            } else {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('User not found'),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          } catch (e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Error retrieving hint key: $e'),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        } else {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('User not logged in'),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  color: Colors.grey.shade100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Designed by Magical Digits Teams',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version 2.6 • Build $buildTime',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
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
  }
}
