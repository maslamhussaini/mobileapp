import 'package:flutter/material.dart';
import 'package:app/services/backend_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _hintkeyController = TextEditingController();
  bool _isLoading = false;
  String? _recoveredPassword;

  @override
  void dispose() {
    _usernameController.dispose();
    _hintkeyController.dispose();
    super.dispose();
  }

  Future<void> _recoverPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Query tblusers table for password recovery
      final query =
          "SELECT password FROM tblusers WHERE username = '${_usernameController.text.trim()}' AND hintkey = '${_hintkeyController.text.trim()}' AND active = -1";
      final users = await BackendService.executeRawQuery(query);

      if (users.isNotEmpty) {
        // Password recovery successful
        setState(() {
          _recoveredPassword = users.first['password'];
        });
      } else {
        // Recovery failed
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid username or hint key')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Recovery error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  const Icon(Icons.lock_reset, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),
                  const Text(
                    'Recover Password',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your username and hint key to recover your password',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Username field
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your username';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Hint key field
                  TextFormField(
                    controller: _hintkeyController,
                    decoration: const InputDecoration(
                      labelText: 'Hint Key',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key),
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Enter your hint key',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your hint key';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _recoverPassword(),
                  ),
                  const SizedBox(height: 24),

                  // Recover password button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _recoverPassword,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Recover Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Password display
                  if (_recoveredPassword != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Your Password:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _recoveredPassword!,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: 2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // Go back to login
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Back to Login'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
