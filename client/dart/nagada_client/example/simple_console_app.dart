import 'package:nagada_client/nagada.dart';
import 'package:logging/logging.dart';

void main() async {
  // Configure logging to print all levels
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
  });

  final log = Logger('SimpleConsoleApp');

  log.info('Creating NagadaClient...');
  final client = NagadaClient.create(
    deviceId: 'my-device-1',
    serverUrl: 'http://localhost:8080/sync',
  );

  log.info('Inserting a record...');
  await client.insert('greetings', {'message': 'Hello from Dart!'}, ['message']);

  log.info('Triggering initial sync...');
  await client.sync();

  // The sync engine will continue to run in the background.
  // In a real app, you would let it run. For this example, we'll stop it.
  log.info('Waiting for 10 seconds before shutting down...');
  await Future.delayed(const Duration(seconds: 10));

  log.info('Disposing client...');
  client.dispose();
  log.info('Client disposed. Application finished.');
}
