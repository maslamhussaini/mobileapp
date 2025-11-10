import 'package:process_run/shell.dart';
import 'dart:io';

class PrismaService {
  static Future<void> startPrisma() async {
    // Prisma has been removed from the project
    print('Prisma has been removed from the project - skipping Prisma setup');
    return;
  }

  static Future<void> startServer() async {
    final shell = Shell();

    try {
      print('Starting Node.js server...');
      // For mobile platforms, don't start the server - it should run separately
      if (Platform.isAndroid || Platform.isIOS) {
        print('Running on mobile - server should be started separately');
        return;
      }

      shell
          .run(
            'powershell -Command "\$env:Path = [System.Environment]::GetEnvironmentVariable(\'Path\',\'Machine\') + \';\' + [System.Environment]::GetEnvironmentVariable(\'Path\',\'User\'); node server.js"',
          )
          .then((_) => print('Backend server started'));
    } catch (e) {
      print('Error starting server: $e');
      rethrow; // Re-throw to let the caller handle it
    }
  }
}
