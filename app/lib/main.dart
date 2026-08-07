import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/account_store.dart';
import 'services/notifier.dart';
import 'services/poll_worker.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = await ThemeController.load();
  await Notifier.init();
  await AccountStore.instance.load();
  await registerPolling();
  runApp(RanseApp(themeController: themeController));
}

class RanseApp extends StatelessWidget {
  const RanseApp({super.key, required this.themeController});

  final ThemeController themeController;

  static ThemeController themeOf(BuildContext context) {
    final app = context.findAncestorWidgetOfExactType<RanseApp>();
    assert(app != null, 'RanseApp not found in the widget tree');
    return app!.themeController;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'Ranse',
        debugShowCheckedModeBanner: false,
        theme: ranseLightTheme(),
        darkTheme: ranseDarkTheme(),
        themeMode: themeController.mode,
        home: const HomeScreen(),
      ),
    );
  }
}
