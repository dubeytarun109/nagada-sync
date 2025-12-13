import 'package:nagada_client/nagada.dart';

abstract class FailedEventStore {
  Future addFailedEvent(ClientEvent event, String reason);
  Future findByClientEventId(String clientEventId);
  Future deleteByClientEventId(String clientEventId);
  Future clear();
}
