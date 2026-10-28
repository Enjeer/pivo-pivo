import 'package:flutter/material.dart';

import 'app.dart';
import 'catalog.dart';
import 'local_store.dart';
import 'routing.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    PivoPivoApp(
      controller: AppController(
        store: SecureLocalUserStore(),
        catalogRepository: OverpassPlaceCatalogRepository(),
        routingProvider: FossgisOsrmRoutingProvider(),
      ),
    ),
  );
}
