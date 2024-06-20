import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_balancer/helpingMethods/methods.dart';
import 'package:the_balancer/models/notificaiton_settings_model.dart';

class NotificationSettingsProvider extends ChangeNotifier {

  //Initializing the notification settings with the empty notification settings constructor
  NotificationSettingsModel notificationSettings = NotificationSettingsModel.emptySettings();

  //Initializing the dio instance for the network calls
  final dio =Dio();

  //Getter for the User Notification Settings
  NotificationSettingsModel get getUserNotificationSettings {
    return notificationSettings;
  }

  //This function will fetch the User notification settings
  Future<void> fetchUserNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final headers = await createHeader();

    try {

      final response = await dio.get('${HelpingMethods.baseURL}/settings/getSettings', options: Options(
        contentType: 'application/json',
        headers: headers
      ));

      
      if (response.statusCode == 200) {
        final settingsData = response.data['settings'];
        final settings = NotificationSettingsModel.fromJson(settingsData[0]);

        notificationSettings = settings;

        final dateTime = DateTime.now();
        String blockNotificationTillDateAndTime = prefs.getString('BlockNotificationTillDateAndTime') ?? '';

        if (blockNotificationTillDateAndTime.isNotEmpty) {
          final blockNotiDateTime = DateTime.parse(blockNotificationTillDateAndTime.toString());
          final comparison = dateTime.compareTo(blockNotiDateTime);
          log("Comparison $comparison");
          if (comparison == 1) {
            notificationSettings.blockNotificationCheck = false;
          }
        }

        notifyListeners();
      } 
      
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }

  }

  //This function will update the user's notification settings on the application and as well as on DB
  Future<dynamic> updateUserNotificationSettings(Map<String, dynamic> map, String userId) async {

    final headers = await createHeader();

    //  NotificationSettingsModel previousSettings = NotificationSettingsModel(
    //       notificationSettingsId: notificationSettings.notificationSettingsId, 
    //       userId: userId, 
    //       allNotifications: notificationSettings.allNotifications, 
    //       deficiencyReminders: notificationSettings.deficiencyReminders, 
    //       surplusReminders: notificationSettings.surplusReminders, 
    //       badges: notificationSettings.badges, 
    //       notificationFrequency:  notificationSettings.notificationFrequency, 
    //       blockNotificationCheck: notificationSettings.blockNotificationCheck, 
    //       blockNotificationPeriod: notificationSettings.blockNotificationPeriod, 
    //       blockNotificationFrequency: notificationSettings.blockNotificationFrequency
    //   );
     
     notificationSettings.allNotifications = map['isAllNotificationsOn'];
     notificationSettings.deficiencyReminders = map['isDeficiencyRemindersOn'];
     notificationSettings.surplusReminders = map['isSurplusRemindersOn'];
     notificationSettings.badges = map['isBadgesOn'];
     notificationSettings.notificationFrequency = map['notificationFrequency'];
     notificationSettings.blockNotificationCheck = map['isBlockNotificaitonsIsOpen'];
     notificationSettings.blockNotificationPeriod = map['blockNotificationPeriod'];
     notificationSettings.blockNotificationFrequency = map['blockNotificationFrequency'];

     notifyListeners();

    try {

      final response = await dio.post('${HelpingMethods.baseURL}/settings/updateSettings', options: Options(
        contentType: 'application/json',
        headers: headers
      ), data: json.encode({'settings': map, 'user_id': userId}));

      if (response.statusCode == 200){

        final isBlockNotificationOpen = map['isBlockNotificaitonsIsOpen'];
        final period =  map['blockNotificationPeriod'];
        final frequency = map['blockNotificationFrequency'];

        setNewBlockNotificationPeriod(period, frequency, isBlockNotificationOpen);

        return true;
      } 
      
    } on DioError catch (e) {
       return e.response!;
    }

  }

  //This function will set the new block notification period
  void setNewBlockNotificationPeriod(int period, int frequency, bool isBlockNoti) async {

    final prefs = await SharedPreferences.getInstance();

    if (isBlockNoti) {
        log("Block Noti $isBlockNoti");
        DateTime newDate = DateTime.now();
        
        if (frequency == 0) {
          log("in Hour $period");
          final date = newDate.add(Duration(hours: period));
          await prefs.setString('BlockNotificationTillDateAndTime', date.toString());

        } else if (frequency == 1) {
          log("in days $period");
          final date = newDate.add(Duration(days: period));
          await prefs.setString('BlockNotificationTillDateAndTime', date.toString());

        } else if (frequency == 2) {
          log("in week $period");
          const oneWeek = 7;
          final weeks = oneWeek * period;
          final date = newDate.add(Duration(days: weeks));
          await prefs.setString('BlockNotificationTillDateAndTime', date.toString());

        } else if (frequency == 3) {
          log("in months $period");
          const oneMonth = 30;
          final days = oneMonth * period;
          final date = newDate.add(Duration(days: days));
          await prefs.setString('BlockNotificationTillDateAndTime', date.toString());

        }

    } else {
      log("Block Noti else");
      await prefs.setString('BlockNotificationTillDateAndTime', '');
    }

    final date = prefs.getString('BlockNotificationTillDateAndTime');
    log("Till Date Time: $date");

  }

  //This function will create header for the network api call
  Future<Map<String, String>> createHeader() async {

    final prefs = await SharedPreferences.getInstance();

    Map<String, String> header = {};


    final token = prefs.getString('loginTimeToken')!;

      header = {
        "Access-Control-Allow-Origin": "*",
        "authorization_token" : token,
      };

    return header;

  }

}