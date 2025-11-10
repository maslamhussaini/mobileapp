import 'package:flutter/material.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/services/backend_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize backend service
      await BackendService.initialize();

      // Navigate to login screen after initialization
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint('❌ Error initializing app: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error initializing app: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ Logo image (make sure it exists in /assets and pubspec.yaml)
            Image.asset(
              'assets/logo.png',
              height: 100,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.image_not_supported, size: 80),
            ),
            const SizedBox(height: 25),
            const Text(
              'MD-Accounting System',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.blueAccent),
            const SizedBox(height: 15),
            const Text(
              'Initializing app...',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
