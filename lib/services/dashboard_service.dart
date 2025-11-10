import 'dart:async';

class DashboardService {
  Future<void> loadDashboardData() async {
    // 👇 Replace with your real Supabase/MySQL call
    await Future.delayed(const Duration(seconds: 2)); // Simulated delay
    print('✅ Dashboard data loaded successfully');
  }
}
