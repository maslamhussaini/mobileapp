import 'package:flutter/material.dart';
import 'package:app/services/backend_service.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/screens/forgot_password_screen.dart';

// Global user session management
class UserSession {
  static Map<String, dynamic>? currentUser;

  static void setUser(Map<String, dynamic> user) {
    currentUser = user;
  }

  static void clearUser() {
    currentUser = null;
  }

  static String? getUsername() {
    return currentUser?['username'];
  }

  static int? getUserId() {
    return currentUser?['userid_pk'];
  }

  static String? getHintKey() {
    return currentUser?['hintkey'];
  }

  static int? getLogonCount() {
    return currentUser?['logoncount'];
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Query tblusers table for authentication with active = -1 filter
      final query =
          "SELECT userid_pk, username, password, logoncount, hintkey FROM tblusers WHERE username = '${_usernameController.text.trim()}' AND password = '${_passwordController.text.trim()}' AND active = -1";
      final users = await BackendService.executeRawQuery(query);

      if (users.isNotEmpty) {
        final user = users.first;
        final currentLogonCount = user['logoncount'] ?? 0;

        // Update logoncount using the new update_qry function
        // Fire-and-forget update: don't block login if update RPC is slow or hangs.
        BackendService.supabase
            .rpc(
              'update_qry',
              params: {
                'p_table': 'tblusers',
                'p_set': 'logoncount = ${currentLogonCount + 1}',
                'p_where': 'userid_pk = ${user['userid_pk']}',
              },
            )
            .timeout(const Duration(seconds: 10)) // short timeout for non-blocking update
            .then((updateResult) {
              debugPrint('Update result: $updateResult');
            }).catchError((e) {
              debugPrint('Login update error: $e');
            });

        // Store user session
        UserSession.setUser({
          'userid_pk': user['userid_pk'],
          'username': user['username'],
          'hintkey': user['hintkey'],
          'logoncount': currentLogonCount + 1,
        });

        if (!mounted) return;

        // Show hintkey message if this is the first login (logoncount was 0, now 1)
        if (currentLogonCount == 0 &&
            user['hintkey'] != null &&
            user['hintkey'].toString().isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Remember your hint key: ${user['hintkey']} - it will be used to reveal your password',
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        // Login failed
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid username or password')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _forgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
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
                  // Logo/Title
                  const Icon(Icons.business, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to continue',
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

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
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
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Forgot password
                  TextButton(
                    onPressed: _forgotPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
