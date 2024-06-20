// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:jiffy/jiffy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_balancer/helpingMethods/methods.dart';
import 'package:the_balancer/main.dart';
import 'package:the_balancer/models/notificaiton_settings_model.dart';
import 'package:the_balancer/models/notification_model.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationProvider extends ChangeNotifier {
  //Creating Dio instance to make http requests
  final dio = Dio();

  //Android Notification Details
  static AndroidNotificationDetails androidDetails =
      const AndroidNotificationDetails(
    "balancer-notification-channel-id-#123",
    "Balancer-Notification-Channel-Name-Stable",
    priority: Priority.max,
    importance: Importance.max,
    category: AndroidNotificationCategory.reminder,
  );

  //iOS Notification Details
  static DarwinNotificationDetails iosSettings =
      const DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  //A complete Notification Details, combined with (Android and iOS) defined above
  NotificationDetails notiDetails =
      NotificationDetails(android: androidDetails, iOS: iosSettings);

  //Function to send notification when the All Notifications are turned ON by the user
  Future<void> addScheduledActivityNotification(
      NotificationSettingsModel settings,
      Map<String, String> activityDetails,
      String selectedDate) async {
    final methods = HelpingMethods();

    //Checking All Notifications from the user Notification Settings before triggering Notification
    if (settings.allNotifications) {
      //Checking if in case the block notifications are On or OFF
      if (!settings.blockNotificationCheck) {
        final convertedTime =
            methods.converTimeTo24(activityDetails['startTime']!, 'start')[0];

        final date = Jiffy.parse(selectedDate, pattern: 'MMMM EEEE d y')
            .format(pattern: 'y-MM-dd');
        final splittedTime = convertedTime.split(':');
        final hour = int.tryParse(splittedTime[0]);
        final min = int.tryParse(splittedTime[1]);
        final hourPeriod = TimeOfDay(hour: hour!, minute: min!).hourOfPeriod;
        DayPeriod isAmPm = TimeOfDay(hour: hour, minute: min).period;

        // print('TIME');
        // print(activityDetails['startTime']);
        // final time = activityDetails['startTime'];
        final notificationCreationDateTime =
            Jiffy.parseFromDateTime(DateTime.now())
                .format(pattern: 'do MMM y h:mm a');

        //Created a string with date and time to pass it inside the DateTime.parse() constructor to get the required DateTime object
        final finalDateTime = "$date ${splittedTime[0]}:${splittedTime[1]}:00";

        //We have created a unique ID for the notification by taking a hashcode<int> of the activityID which is String.
        final notificationId = activityDetails['activityId'].hashCode;

        DateTime scheduleNotificationTime;
        TimeOfDay currentTimeMin = TimeOfDay.now();
        final mins = currentTimeMin.minute;
        //For Testing
        // DateTime scheduleNotificationTime = DateTime.now().add(const Duration(minutes: 1));

        if ((mins >= 25 && mins <= 30) || (mins >= 55 && mins <= 59)) {
          scheduleNotificationTime = DateTime.parse(finalDateTime);
        } else {
          scheduleNotificationTime = DateTime.parse(finalDateTime).subtract(
              const Duration(
                  minutes:
                      5)); // We have subtracted 5 mins from the actual time of notification to make user reminded for that specific task
        }

        final splitCategory = activityDetails['categoryName']!.split('-');
        final categoryName = splitCategory[1].trimLeft();
        // TimeOfDay(hour: int.tryParse(splittedTime[0])!, minute: int.tryParse(splittedTime[1])!);

        //Creating a custome message for the notification
        final message =
            "Your time for ${activityDetails['taskName']} is going to be started. Kindly be ready at $hourPeriod:$min ${isAmPm.name.toUpperCase()}. You added this activity on - $notificationCreationDateTime";

        final crtDateTime = DateTime.now();

        if (scheduleNotificationTime.isAfter(crtDateTime)) {
          //Triggering the notification
          await notificationsPlugin.zonedSchedule(
            notificationId,
            categoryName,
            message,
            tz.TZDateTime.from(scheduleNotificationTime, tz.local),
            notiDetails,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.wallClockTime,
            androidAllowWhileIdle: true,
            payload:
                date, //It is helpful when the user taps the notification while the app is closed or running in background and to navigate to the desired screen
          );

          await insertNotificationInDB(settings.userId, notificationId,
              categoryName, message, notificationCreationDateTime);
        }
      }
    }
  }

  //Function to send Deficiency reminders notifications when turned ON
  Future<void> deficiencyReminderNotification(
      NotificationSettingsModel settings, String categoryName) async {
    //Creating an instance of Shared Prefrences
    final prefs = await SharedPreferences.getInstance();

    //Creating a random number for the notification id
    Random random = Random();
    final randomId = random.nextInt(1000);

    //Creating a DateTime object to create notification creation date
    final date = DateTime.now().toString();
    final notificationCreationDateTime = Jiffy.parseFromDateTime(DateTime.now())
        .format(pattern: 'do MMM y h:mm a');

    //First, checking is deficiency reminders are ON
    if (settings.deficiencyReminders) {
      //Secondly, checking is block notifications are also ON. In case ON then we will not send any deficiency reminders
      if (!settings.blockNotificationCheck) {
        //Checking the previous last most deficient category. And just for the first time we are setting the variable to empty string ''.
        String lastMostDeficient = prefs.getString('lastMostDeficient') ?? '';

        //This if block will run only if the last most deficient is empty (first time case) or when the last most deficient category is not same with the new deficient category
        if (lastMostDeficient == '' || lastMostDeficient != categoryName) {
          dev.log('In Deficient Reminders');

          //Third, checking the notification frequency set by the user
          // 0 Means Hourly
          if (settings.notificationFrequency == 0) {
            await notificationsPlugin.periodicallyShow(
              randomId,
              'Deficiency Reminder',
              'Your ${categoryName == 'self_love' ? 'Self-Love' : categoryName} is most deficient. Please take care of it. Created on - $notificationCreationDateTime',
              RepeatInterval.hourly,
              notiDetails,
              androidAllowWhileIdle: true,
              payload: date,
            );

            // 1 Means Daily
          } else if (settings.notificationFrequency == 1) {
            await notificationsPlugin.periodicallyShow(
              randomId,
              'Deficiency Reminder',
              'Your ${categoryName == 'self_love' ? 'Self-Love' : categoryName} is most deficient. Please take care of it. Created on - $notificationCreationDateTime',
              RepeatInterval.daily,
              notiDetails,
              androidAllowWhileIdle: true,
              payload: date,
            );

            // and in else part the frequency will be 2 Means Weekly
          } else {
            await notificationsPlugin.periodicallyShow(
              randomId,
              'Deficiency Reminder',
              'Your ${categoryName == 'self_love' ? 'Self-Love' : categoryName} is most deficient. Please take care of it. Created on - $notificationCreationDateTime',
              RepeatInterval.weekly,
              notiDetails,
              androidAllowWhileIdle: true,
              payload: date,
            );
          }

          await prefs.setString('lastMostDeficient', categoryName);
        }
      }
    }
  }

  //Function to send Surplus reminders notifications when turned ON
  Future<void> surplusReminderNotification(
      NotificationSettingsModel settings, String categoryName) async {
    //Creating an instance of Shared Prefrences
    final prefs = await SharedPreferences.getInstance();

    //Creating a random number for the notification id
    Random random = Random();
    final randomId = random.nextInt(1000);

    //Creating a DateTime object to create notification creation date
    final date = DateTime.now().toString();
    final notificationCreationDateTime = Jiffy.parseFromDateTime(DateTime.now())
        .format(pattern: 'do MMM y h:mm a');

    //First, checking is deficiency reminders are ON
    if (settings.deficiencyReminders) {
      //Secondly, checking is block notifications are also ON. In case ON then we will not send any surplus reminders
      if (!settings.blockNotificationCheck) {
        //Checking the previous last most deficient category. And just for the first time we are setting the variable to empty string ''.
        String lastBiggestSurplus = prefs.getString('lastBiggestSurplus') ?? '';

        //This if block will run only if the last biggest surplus is empty (first time case) or when the last biggest surplus category is not same with the new surplus category
        if (lastBiggestSurplus == '' || lastBiggestSurplus != categoryName) {
          dev.log('In Surplus Reminders');

          //Third, checking the notification frequency set by the user
          // 0 Means Hourly
          if (settings.notificationFrequency == 0) {
            await notificationsPlugin.periodicallyShow(
              randomId,
              'Surplus Reminder',
              'Your ${categoryName == 'self_love' ? 'Self-Love' : categoryName} is biggest surplus. Please take care of it. Created on - $notificationCreationDateTime',
              RepeatInterval.hourly,
              notiDetails,
              androidAllowWhileIdle: true,
              payload: date,
            );

            // 1 Means Daily
          } else if (settings.notificationFrequency == 1) {
            await notificationsPlugin.periodicallyShow(
              randomId,
              'Surplus Reminder',
              'Your ${categoryName == 'self_love' ? 'Self-Love' : categoryName} is biggest surplus. Please take care of it. Created on - $notificationCreationDateTime',
              RepeatInterval.daily,
              notiDetails,
              androidAllowWhileIdle: true,
              payload: date,
            );

            // and in else part the frequency will be 2 Means Weekly
          } else {
            await notificationsPlugin.periodicallyShow(
              randomId,
              'Surplus Reminder',
              'Your ${categoryName == 'self_love' ? 'Self-Love' : categoryName} is biggest surplus. Please take care of it. Created on - $notificationCreationDateTime',
              RepeatInterval.weekly,
              notiDetails,
              androidAllowWhileIdle: true,
              payload: date,
            );
          }

          await prefs.setString('lastBiggestSurplus', categoryName);
        }
      }
    }
  }

  //This function will create header for the network api calls
  Future<Map<String, String>> createHeader() async {
    final prefs = await SharedPreferences.getInstance();

    Map<String, String> header = {};

    final token = prefs.getString('loginTimeToken')!;

    header = {
      "Access-Control-Allow-Origin": "*",
      "authorization_token": token,
    };

    return header;
  }

  //This function will insert notifications into DB
  Future<void> insertNotificationInDB(
      String userId,
      int notificationId,
      String categoryName,
      String notificationMessage,
      String notificationCreationDate) async {
    final headers = await createHeader();
    final date =
        Jiffy.parse(notificationCreationDate, pattern: 'do MMM y h:mm a')
            .dateTime
            .toString();

    final map = {
      'notificationId': notificationId,
      'userId': userId,
      'categoryName': categoryName,
      'message': notificationMessage,
      'creationDate': date,
    };

    try {
      await dio.post(
          '${HelpingMethods.baseURL}/notifications/addNotification',
          options: Options(
            contentType: 'application/json',
            headers: headers,
          ),
          data: json.encode(map));
    } on DioError catch (e) {
      dev.log(e.toString());
    }
  }

  //This function will fetch all the user's notifications from the DB
  Future<List<NotificationModel>> fetchAllUserNotificaitons(
      String userId) async {
    final headers = await createHeader();
    List<NotificationModel> listOfNotifications = [];

    try {
      final response = await dio.get(
          '${HelpingMethods.baseURL}/notifications/getAllNotifications',
          options: Options(
            contentType: 'application/json',
            headers: headers,
          ),
          queryParameters: {'id': userId});

      if (response.statusCode == 200) {
        final notifications = response.data['notifications'] as List<dynamic>;
        if (notifications.isNotEmpty) {
          for (var noti in notifications) {
            final newNotification = NotificationModel.fromJson(noti);
            listOfNotifications.add(newNotification);
          }
        }
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }

    return listOfNotifications;
  }

  //This function will get yesterday's done notifications
  Future<List<NotificationModel>> getYesterdayDoneNotifications(
      String userId) async {
    final headers = await createHeader();
    List<NotificationModel> listOfNotifications = [];
    DateTime previousDate = DateTime.now().subtract(const Duration(days: 1));

    DateTime startDate =
        DateTime(previousDate.year, previousDate.month, previousDate.day, 0, 0);
    DateTime endDate = DateTime(
        previousDate.year, previousDate.month, previousDate.day, 23, 59);

    try {
      final response = await dio.get(
          '${HelpingMethods.baseURL}/notifications/getYesterdayDoneNotifications',
          options: Options(
            contentType: 'application/json',
            headers: headers,
          ),
          queryParameters: {
            'id': userId,
            'startDate': startDate.toString(),
            'endDate': endDate.toString()
          });

      if (response.statusCode == 200) {
        final notifications = response.data['notifications'] as List<dynamic>;
        if (notifications.isNotEmpty) {
          for (var noti in notifications) {
            final newNotification = NotificationModel.fromJson(noti);
            listOfNotifications.add(newNotification);
          }
        }
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }

    return listOfNotifications;
  }

  //This function will get the current week done notifications
  Future<List<NotificationModel>> getCurrentWeekDoneNotifications(
      String userId, DateTime startDate, DateTime endDate) async {
    final headers = await createHeader();
    List<NotificationModel> listOfNotifications = [];

    try {
      final response = await dio.get(
          '${HelpingMethods.baseURL}/notifications/getCurrentWeekNotifications',
          options: Options(
            contentType: 'application/json',
            headers: headers,
          ),
          queryParameters: {
            'id': userId,
            'startDate': startDate.toString(),
            'endDate': endDate.toString()
          });

      if (response.statusCode == 200) {
        final notifications = response.data['notifications'] as List<dynamic>;
        if (notifications.isNotEmpty) {
          for (var noti in notifications) {
            final newNotification = NotificationModel.fromJson(noti);
            listOfNotifications.add(newNotification);
          }
        }
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }

    return listOfNotifications;
  }

  //This function will cancel all of the notifications from the DB
  Future<void> cancelAllNotifications(String userId) async {
    final headers = await createHeader();

    try {
      final response = await dio.delete(
          '${HelpingMethods.baseURL}/notifications/cancelNotifications',
          options: Options(
            contentType: 'application/json',
            headers: headers,
          ),
          queryParameters: {'userId': userId});

      await notificationsPlugin.cancelAll();
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }
  }

  //Function to cancel the notification. It will be called when a specific activity will be deleted.
  Future<void> cancelSpecificNotification(String activityId) async {
    //Taking the hashcode of the activityID of the activity to get an Int and passed it inside the cancel method
    final notificationID = activityId.hashCode;

    final headers = await createHeader();

    try {
      await dio.delete(
          '${HelpingMethods.baseURL}/notifications/cancelNotifications',
          options: Options(
            contentType: 'application/json',
            headers: headers,
          ),
          queryParameters: {'notificationId': notificationID});

      await notificationsPlugin.cancel(notificationID);
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }
  }
}
