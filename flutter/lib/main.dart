import 'package:flutter/material.dart';
import 'package:project/login.dart';
import 'package:project/app_theme.dart';
import 'package:project/app_nav_bar.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.themeData,
      navigatorObservers: [routeObserver],
      home: Login(),
    );
  }
}
