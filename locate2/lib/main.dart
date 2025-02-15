import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final status = await Permission.camera.request();
  runApp(MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text("카메라 권한 테스트")),
      body: Center(child: Text("카메라 권한 상태: ${status.toString()}")),
    ),
  ));
}
