import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/system_ui.dart';

import 'app/app.dart';
import 'core/config/supabase_bootstrap.dart';
export 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(eHealthSystemUi);
  runApp(EHealthApp(authRepositoryLoader: SupabaseBootstrap.initialize));
}
