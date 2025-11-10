import 'package:flutter/material.dart';
import 'package:app/screens/splash_screen.dart';
import 'package:app/services/backend_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // BackendService.initialize() is now called in SplashScreen
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MD Accounting System',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // 👈 Start from Splash Screen
    );
  }
}
