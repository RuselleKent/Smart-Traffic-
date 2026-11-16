import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'state.dart';
import 'theme.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.init();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  app.start();
  runApp(const SmartTrafficApp());
}

class SmartTrafficApp extends StatelessWidget {
  const SmartTrafficApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Traffic',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scaffoldMessengerKey: app.messengerKey,
      // Only limits text scaling; it does not touch the layout/size.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler
                .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.15),
          ),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}
