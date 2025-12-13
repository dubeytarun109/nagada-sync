 

import 'package:nagada_client/nagada.dart';

abstract class LocalProjectionStore {
  Future applyClientEvent(ClientEvent event);
  Future applyServerEvent(ServerEvent event);
}