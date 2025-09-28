import 'package:flutter/material.dart';
import 'package:lakii/login.dart';
import 'package:permission_handler/permission_handler.dart';
import 'splash.dart'; // new file
import 'remote.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.camera.request();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(), // Show splash first
    );
  }
}
