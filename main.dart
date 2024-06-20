// ignore_for_file: unused_import

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:testfairy_flutter/testfairy_flutter.dart';
import 'package:the_balancer/providers/activityProvider.dart';
import 'package:the_balancer/providers/notificationSettingsProvider.dart';
import 'package:the_balancer/providers/notificationsProvider.dart';
import 'package:the_balancer/providers/userProvider.dart';
import 'package:the_balancer/screens/gateway_screen.dart';
import 'package:the_balancer/screens/onboarding_screen.dart';
import 'package:the_balancer/screens/subscriptionScreens/subscriptionPlan.dart';
import 'package:the_balancer/theme/appTheme.dart';
import 'package:timezone/data/latest_10y.dart';

//Initialization of Flutter Local Notification Plugin. It is kept global so, it can be accessd anywhere in the app.
final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  initializeTimeZones();

  AndroidInitializationSettings androidSettings =
      const AndroidInitializationSettings("@mipmap/ic_launcher");

  DarwinInitializationSettings iosSettings = const DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestCriticalPermission: true,
    requestSoundPermission: true,
  );

  InitializationSettings initializationSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  bool? initialized = await notificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (response) {
      log("${response.payload}");
    },
  );

  log('Initialized: $initialized');

  final prefs = await SharedPreferences.getInstance();

  await prefs.setString('currentDate', DateTime.now().toString());

  runApp(const TheBalancer());
}

class TheBalancer extends StatelessWidget {
  const TheBalancer({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => ActivityProvider()),
        ChangeNotifierProvider(
            create: (context) => NotificationSettingsProvider()),
        ChangeNotifierProvider(create: (context) => NotificationProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Balancer',
        themeMode: ThemeMode.light,
        theme: AppTheme.appTheme,
        home: const GatewayScreen(),
      ),
    );
  }
}
