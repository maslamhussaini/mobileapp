import 'package:flutter/material.dart';
import 'package:app/services/prisma_service.dart';
import 'package:app/widgets/navigation_drawer.dart';
import 'package:app/screens/dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      print('Initializing app...');
      // Prisma has been removed, only start server
      await PrismaService.startServer();
      print('App initialization completed');
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing app: $e');
      // Show error dialog or snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize app: $e'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
      // Still set initialized to true to show the UI, but with error indication
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('MD-Accounting System')),
      drawer: const AppNavigationDrawer(),
      body: const DashboardScreen(),
    );
  }
}
