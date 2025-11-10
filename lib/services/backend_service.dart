import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackendService {
  static late SupabaseClient supabase;

  static Future<void> initialize() async {
    final client = http.Client();
    // Note: http.Client doesn't have connectionTimeout, but we can create a custom client

    await Supabase.initialize(
      url: 'https://unannygymdwpuadscqjl.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVuYW5ueWd5bWR3cHVhZHNjcWpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNzQyNDAsImV4cCI6MjA3Njg1MDI0MH0.6oGARbFfxPRLEeMhcAu8d1Q1GlJcue2BXXQE704uqGg',
      httpClient: client,
    );
    supabase = Supabase.instance.client;
  }

  // Removed baseUrl as we're now using Supabase directly

  static Future<List<dynamic>> getAll(
    String table, {
    int page = 1,
    int limit = 10,
    String? filter,
  }) async {
    try {
      var query = supabase.from(table).select('*');

      if (filter != null && filter.isNotEmpty) {
        // Assuming filter is a simple equality filter, adjust as needed
        query = query.eq('name', filter); // Example: filter by name
      }

      final start = (page - 1) * limit;
      final end = start + limit - 1;

      final response = await query.range(start, end);

      return response as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to load data from Supabase: $e');
    }
  }

  static Future<Map<String, dynamic>> getById(String table, int id) async {
    try {
      final response = await supabase
          .from(table)
          .select('*')
          .eq('id', id)
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to load data from Supabase: $e');
    }
  }

  static Future<Map<String, dynamic>> create(
    String table,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await supabase
          .from(table)
          .insert(data)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to create data in Supabase: $e');
    }
  }

  static Future<Map<String, dynamic>> update(
    String table,
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await supabase
          .from(table)
          .update(data)
          .eq('id', id)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to update data in Supabase: $e');
    }
  }

  static Future<void> delete(String table, int id) async {
    try {
      await supabase.from(table).delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete data from Supabase: $e');
    }
  }

  static Future<List<dynamic>> getStoredProcedures() async {
    // Supabase doesn't have traditional stored procedures like SQL Server
    // This would need to be implemented using Supabase functions or RPC calls
    return [];
  }

  static Future<List<dynamic>> getStoredProcedureParams(String name) async {
    // Supabase doesn't have traditional stored procedures like SQL Server
    return [];
  }

  static Future<List<dynamic>> getGLAccounts() async {
    try {
      final response = await supabase.from('glaccounts').select('*');
      return response as List<dynamic>;
    } catch (e) {
    debugPrint('Error in getGLAccounts: $e');
      throw Exception('Failed to load GL accounts: $e');
    }
  }

  static Future<List<dynamic>> executeStoredProcedure(
    String name,
    Map<String, dynamic> params,
  ) async {
    try {
      // Use Supabase RPC for stored procedure-like functionality
      final response = await supabase.rpc(name, params: params);
      return response as List<dynamic>;
    } catch (e) {
  debugPrint('Error executing stored procedure $name: $e');
      throw Exception('Failed to execute stored procedure: $e');
    }
  }

  static Future<List<dynamic>> executeRawQuery(
    String query, {
    int maxRetries = 10,
    Duration? timeout,
  }) async {
    int attempt = 0;
    final Duration effectiveTimeout = timeout ?? const Duration(seconds: 300);

    debugPrint('Flutter sending query to Supabase: $query');

    while (attempt < maxRetries) {
      try {
        debugPrint('Attempt ${attempt + 1}/$maxRetries - Executing query...');
        final response = await supabase
            .rpc('exec_sql', params: {'query': query})
            .timeout(effectiveTimeout);
        debugPrint('Query executed successfully on attempt ${attempt + 1}');
        return response as List<dynamic>;
      } catch (e) {
        attempt++;
        debugPrint('Error executing raw query (attempt $attempt/$maxRetries): $e');
        debugPrint('Query was: $query');

        if (attempt >= maxRetries) {
          debugPrint('Max retries reached. Giving up.');
          throw Exception(
            'Failed to execute query after $maxRetries attempts: $e',
          );
        }

        // Wait before retrying (exponential backoff with longer delays)
        final waitTime = Duration(seconds: attempt * 5); // 5,10,15...
        debugPrint('Waiting ${waitTime.inSeconds} seconds before retry...');
        await Future.delayed(waitTime);
      }
    }

    throw Exception('Failed to execute query after all retries');
  }

  /// Refresh a materialized view used by the dashboard.
  ///
  /// This runs a REFRESH MATERIALIZED VIEW CONCURRENTLY statement via the
  /// exec_sql RPC and logs the outcome. It uses a short timeout and only a
  /// single attempt by default because the server may be under load.
  static Future<void> refreshMaterializedView({
    String viewName = 'mv_generalledger',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final query = 'REFRESH MATERIALIZED VIEW CONCURRENTLY $viewName;';
    try {
      debugPrint('Refreshing materialized view: $viewName');
      await executeRawQuery(query, maxRetries: 1, timeout: timeout);
      debugPrint('Materialized view refreshed successfully: $viewName');
    } catch (e) {
      debugPrint('Error refreshing materialized view $viewName: $e');
      // Don't rethrow: refreshing the view is a best-effort pre-step for
      // manual refreshes — dashboard refresh should still proceed.
    }
  }
}


