/// Example demonstrating the getLogsByTag functionality
import 'package:astute_logger/astute_logger.dart';

Future<void> demoGetLogsByTag() async {
  // Create a logger instance
  final logger = AstuteLogger('DemoLogger');

  // Log some messages with different tags
  logger.info('This is an informational message', tag: 'NETWORK');
  logger.debug('Debugging network connection', tag: 'NETWORK');
  logger.warning('Slow network response', tag: 'NETWORK');

  logger.info('User logged in successfully', tag: 'AUTH');
  logger.error('Failed login attempt', tag: 'AUTH');

  logger.info('Database query executed', tag: 'DATABASE');
  logger.debug('Query took 120ms', tag: 'DATABASE');

  // Wait a moment for logs to be written
  await Future.delayed(Duration(milliseconds: 100));

  // Retrieve logs by tag
  final networkLogs = await AstuteLogger.getLogsByTag('network');
  final authLogs = await AstuteLogger.getLogsByTag('AUTH');
  final databaseLogs = await AstuteLogger.getLogsByTag('database');
  final nonExistentLogs = await AstuteLogger.getLogsByTag('NONEXISTENT');

  print('=== NETWORK Logs ===');
  for (final log in networkLogs) {
    print(log);
  }

  print('\n=== AUTH Logs ===');
  for (final log in authLogs) {
    print(log);
  }

  print('\n=== DATABASE Logs ===');
  for (final log in databaseLogs) {
    print(log);
  }

  print('\n=== Non-existent Logs ===');
  print('Found ${nonExistentLogs.length} logs with non-existent tag');
}

void main() async {
  await demoGetLogsByTag();
}
