// ignore_for_file: unnecessary_null_comparison, unused_local_variable

import 'dart:convert';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jiffy/jiffy.dart';
import 'package:nanoid/nanoid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_balancer/helpingMethods/methods.dart';
import 'package:the_balancer/models/activity_model.dart';
import 'package:the_balancer/models/user_model.dart';

class ActivityProvider extends ChangeNotifier {
  //Initializing and declaring variables for the class Activity Provider

  final dio = Dio();

  List<ActivityModel> activitiesList = [];

  var mapOfActualPercentages = {};

  int count = 0;
  var mapOfCounts = {};
  bool val = false;
  var listOfReports = [];

  DateTime startingWeekDate = DateTime.now();
  DateTime endingWeekDate = DateTime.now();
  DateTime startingYearDate = DateTime.now();
  DateTime endingYearDate = DateTime.now();
  bool isFromLineChart = false;
  double month = DateTime.now().month.toDouble() - 1;

  void setmonth(double month) {
    this.month = month;
    isFromLineChart = true;
    notifyListeners();
  }

  setisLineChartFalse() {
    isFromLineChart = false;
    notifyListeners();
  }

  get getmonth => month.toInt();
  get getisfromlinechart => isFromLineChart;

  //Getter for activities list
  List<ActivityModel> get getActivitiesList {
    return activitiesList;
  }

  //Getter for actual percentages
  get getActualPercentages {
    final Map<String, double> data =
        Map.castFrom<dynamic, dynamic, String, double>(mapOfActualPercentages);
    return data;
  }

  //This function will format the time
  String timeFormater(int hour, int min) {
    final meridiamForStartTime = hour < 12
        ? 'AM'
        : hour == 24
            ? 'AM'
            : 'PM';
    final sHour = hour.toString();
    final sMin = min.toString();

    String startTime = '';

    if (sHour.length == 1 && sMin.length == 1) {
      startTime = '0$sHour:0$sMin $meridiamForStartTime';
    } else if (sHour.length == 1 && sMin.length == 2) {
      startTime = '0$sHour:$sMin $meridiamForStartTime';
    } else if (sHour.length == 2 && sMin.length == 1) {
      startTime = '$sHour:0$sMin $meridiamForStartTime';
    } else {
      startTime = '$sHour:$sMin $meridiamForStartTime';
    }

    return startTime;
  }

  //This function will filter the activities for selected date while adding a new activity
  List<ActivityModel> filterActivitiesWhenAdding(String selectedDate) {
    final filteredActivities = activitiesList.where((activity) {
      String selected =
          Jiffy.parse(activity.activitySelectedDate, pattern: 'y-MM-dd')
              .format(pattern: 'y-MM-dd');
      return selected == selectedDate;
    }).toList();

    return filteredActivities.isEmpty ? [] : filteredActivities;
  }

  //The function will check if an activity is already present at the time stamp
  bool checkIfActIsAlreadyPresentAtTheStartTime(
      List<ActivityModel> listOfActivities, String startTime) {
    final filteredAct = listOfActivities.firstWhere(
      (act) => act.activityStartTime == startTime,
      orElse: () => ActivityModel.emptyActivity(),
    );

    if (filteredAct.activityName != '') {
      return true;
    } else {
      return false;
    }
  }

  String checkIfActIsAlreadyPresentActid(
      List<ActivityModel> listOfActivities, String startTime) {
    final filteredAct = listOfActivities.firstWhere(
      (act) => act.activityStartTime == startTime,
      orElse: () => ActivityModel.emptyActivity(),
    );

    if (filteredAct.activityName != '') {
      return filteredAct.activityId;
    } else {
      return '';
    }
  }

  //This function will add a new activity
  Future<void> addNewActivity(BuildContext context, Map<String, dynamic> map,
      DateTime currentDate, user) async {
    final methods = HelpingMethods();

    // var activityId = map['activityId'];

    final filteredActList = filterActivitiesWhenAdding(map['selectedDate']);

    log('Filtered Act List $filteredActList');

    final activityCreationDate = currentDate;
    int counter = 0;

    int startTimeHour = int.parse(map['startTime'].split(':')[0]);
    int startTimeMin = int.parse(map['startTime'].split(':')[1]);
    int endTimeHour = int.parse(map['endTime'].split(':')[0]);
    int endTimeMin = int.parse(map['endTime'].split(':')[1]);

    final meridiamForEndTime = endTimeHour < 12
        ? 'AM'
        : endTimeHour == 24
            ? 'AM'
            : 'PM';

    // log('Meridiam For End Time: $meridiamForEndTime');

    final temp =
        methods.converTimeTo12('${map['endTime']} $meridiamForEndTime');
    map['endTime'] = '${temp[0]} ${temp[1]}';

    // log('End Time in 12 hours: $temp');

    int differenceInMins = endTimeMin - startTimeMin;
    var hour = startTimeHour;
    var min = startTimeMin;

    if (startTimeMin == 30 && endTimeMin == 30) {
      for (var i = startTimeHour; i <= endTimeHour; i++) {
        if (i == startTimeHour) {
          for (var j = 0; j < 1; j++) {
            log('FOR 1');
            log('$hour:$min');
            final temp = methods.converTimeTo12(timeFormater(hour, min));
            final startTime = '${temp[0]} ${temp[1]}';
            log('Start Time : $startTime , End Time: ${map['endTime']}');

            final check = checkIfActIsAlreadyPresentAtTheStartTime(
                filteredActList, startTime);
            log('Check : $check');

            if (!check) {
              if (startTime != map['endTime']) {
                var activityId = nanoid();
                final activity = ActivityModel(
                  activityId: activityId,
                  activityName: map['taskName'],
                  activityCategoryName: map['categoryName'],
                  activityStartTime: startTime,
                  activityEndTime: map['endTime'],
                  activitySelectedDate: map['selectedDate'],
                  activityCreationDate: activityCreationDate,
                );
                activitiesList.add(activity);
                notifyListeners();
                map['startTime'] = startTime;
                map['activityId'] = activityId;
                map['activityCreationDate'] =
                    activityCreationDate.toIso8601String();
                counter++;
                await addActivityToDB(map, activityCreationDate);
                min -= 30;
              } else {
                break;
              }
            } else {
              count++;
              if (count == 1) {
                if (Platform.isIOS) {
                  val = await methods.showIosWarning(context);
                } else {
                  val = await methods.showAndroidWarning(context);
                }
              }
              if (val) {
                var id =
                    checkIfActIsAlreadyPresentActid(filteredActList, startTime);
                if (id != '') {
                  await deleteActivity(id, user);

                  if (startTime != map['endTime']) {
                    var activityId = nanoid();
                    final activity = ActivityModel(
                      activityId: activityId,
                      activityName: map['taskName'],
                      activityCategoryName: map['categoryName'],
                      activityStartTime: startTime,
                      activityEndTime: map['endTime'],
                      activitySelectedDate: map['selectedDate'],
                      activityCreationDate: activityCreationDate,
                    );
                    activitiesList.add(activity);
                    notifyListeners();
                    map['startTime'] = startTime;
                    map['activityId'] = activityId;
                    map['activityCreationDate'] =
                        activityCreationDate.toIso8601String();
                    counter++;
                    await addActivityToDB(map, activityCreationDate);
                    min -= 30;
                  } else {
                    break;
                  }
                }
              } else {
                log("no");
                min -= 30;
              }
            }
          }
        } else {
          for (var j = 0; j < 2; j++) {
            log('FOR 2');
            log('$hour:$min');
            final temp = methods.converTimeTo12(timeFormater(hour, min));
            final startTime = '${temp[0]} ${temp[1]}';
            log('Start Time : $startTime , End Time: ${map['endTime']}');

            final check = checkIfActIsAlreadyPresentAtTheStartTime(
                filteredActList, startTime);
            log('Check : $check');

            if (!check) {
              if (startTime != map['endTime']) {
                var activityId = nanoid();
                final activity = ActivityModel(
                  activityId: activityId,
                  activityName: map['taskName'],
                  activityCategoryName: map['categoryName'],
                  activityStartTime: startTime,
                  activityEndTime: map['endTime'],
                  activitySelectedDate: map['selectedDate'],
                  activityCreationDate: activityCreationDate,
                );

                activitiesList.add(activity);
                notifyListeners();
                map['startTime'] = startTime;
                map['activityId'] = activityId;
                map['activityCreationDate'] =
                    activityCreationDate.toIso8601String();
                counter++;
                await addActivityToDB(map, activityCreationDate);

                min += 30;
              } else {
                break;
              }
            } else {
              count++;
              if (count == 1) {
                if (Platform.isIOS) {
                  val = await methods.showIosWarning(context);
                } else {
                  val = await methods.showAndroidWarning(context);
                }
              }

              if (val) {
                var id =
                    checkIfActIsAlreadyPresentActid(filteredActList, startTime);
                if (id != '') {
                  await deleteActivity(id, user);

                  if (startTime != map['endTime']) {
                    var activityId = nanoid();
                    final activity = ActivityModel(
                      activityId: activityId,
                      activityName: map['taskName'],
                      activityCategoryName: map['categoryName'],
                      activityStartTime: startTime,
                      activityEndTime: map['endTime'],
                      activitySelectedDate: map['selectedDate'],
                      activityCreationDate: activityCreationDate,
                    );

                    activitiesList.add(activity);
                    notifyListeners();
                    map['startTime'] = startTime;
                    map['activityId'] = activityId;
                    map['activityCreationDate'] =
                        activityCreationDate.toIso8601String();
                    counter++;
                    await addActivityToDB(map, activityCreationDate);

                    min += 30;
                  } else {
                    break;
                  }
                }
              } else {
                log("no");
                min += 30;
              }
            }
          }
        }

        hour += 1;
        min = 0;
      }
    } else {
      for (var i = startTimeHour; i <= endTimeHour; i++) {
        if (i == endTimeHour) {
          if (differenceInMins == 30) {
            for (var j = 0; j < 2; j++) {
              log('FOR 3');
              log('$hour:$min');
              final temp = methods.converTimeTo12(timeFormater(hour, min));
              final startTime = '${temp[0]} ${temp[1]}';
              log('Start Time : $startTime , End Time: ${map['endTime']}');

              final check = checkIfActIsAlreadyPresentAtTheStartTime(
                  filteredActList, startTime);
              log('Check : $check');

              if (!check) {
                if (startTime != map['endTime']) {
                  var activityId = nanoid();
                  final activity = ActivityModel(
                    activityId: activityId,
                    activityName: map['taskName'],
                    activityCategoryName: map['categoryName'],
                    activityStartTime: startTime,
                    activityEndTime: map['endTime'],
                    activitySelectedDate: map['selectedDate'],
                    activityCreationDate: activityCreationDate,
                  );

                  activitiesList.add(activity);
                  notifyListeners();
                  map['startTime'] = startTime;
                  map['activityId'] = activityId;
                  map['activityCreationDate'] =
                      activityCreationDate.toIso8601String();
                  counter++;
                  await addActivityToDB(map, activityCreationDate);
                  min += 30;
                } else {
                  break;
                }
              } else {
                count++;
                if (count == 1) {
                  if (Platform.isIOS) {
                    val = await methods.showIosWarning(context);
                  } else {
                    val = await methods.showAndroidWarning(context);
                  }
                }
                if (val) {
                  var id = checkIfActIsAlreadyPresentActid(
                      filteredActList, startTime);
                  if (id != '') {
                    await deleteActivity(id, user);
                    var activityId = nanoid();
                    final activity = ActivityModel(
                      activityId: activityId,
                      activityName: map['taskName'],
                      activityCategoryName: map['categoryName'],
                      activityStartTime: startTime,
                      activityEndTime: map['endTime'],
                      activitySelectedDate: map['selectedDate'],
                      activityCreationDate: activityCreationDate,
                    );

                    activitiesList.add(activity);
                    notifyListeners();
                    map['startTime'] = startTime;
                    map['activityId'] = activityId;
                    map['activityCreationDate'] =
                        activityCreationDate.toIso8601String();
                    counter++;
                    await addActivityToDB(map, activityCreationDate);
                    min += 30;
                  } else {
                    break;
                  }
                } else {
                  log("no");
                  min += 30;
                }
              }
            }
          } else {
            for (var j = 0; j < 1; j++) {
              log('FOR 4');
              log('$hour:$min');
              final temp = methods.converTimeTo12(timeFormater(hour, min));
              final startTime = '${temp[0]} ${temp[1]}';
              log('Start Time : $startTime , End Time: ${map['endTime']}');

              final check = checkIfActIsAlreadyPresentAtTheStartTime(
                  filteredActList, startTime);
              log('Check : $check');

              if (!check) {
                if (startTime != map['endTime']) {
                  var activityId = nanoid();
                  final activity = ActivityModel(
                    activityId: activityId,
                    activityName: map['taskName'],
                    activityCategoryName: map['categoryName'],
                    activityStartTime: startTime,
                    activityEndTime: map['endTime'],
                    activitySelectedDate: map['selectedDate'],
                    activityCreationDate: activityCreationDate,
                  );

                  activitiesList.add(activity);
                  notifyListeners();
                  map['startTime'] = startTime;
                  map['activityId'] = activityId;
                  map['activityCreationDate'] =
                      activityCreationDate.toIso8601String();
                  counter++;
                  await addActivityToDB(map, activityCreationDate);
                  min += 30;
                } else {
                  break;
                }
              } else {
                count++;
                if (count == 1) {
                  if (Platform.isIOS) {
                    val = await methods.showIosWarning(context);
                  } else {
                    val = await methods.showAndroidWarning(context);
                  }
                }

                if (val) {
                  var id = checkIfActIsAlreadyPresentActid(
                      filteredActList, startTime);
                  if (id != '') {
                    await deleteActivity(id, user);
                    if (startTime != map['endTime']) {
                      var activityId = nanoid();
                      final activity = ActivityModel(
                        activityId: activityId,
                        activityName: map['taskName'],
                        activityCategoryName: map['categoryName'],
                        activityStartTime: startTime,
                        activityEndTime: map['endTime'],
                        activitySelectedDate: map['selectedDate'],
                        activityCreationDate: activityCreationDate,
                      );

                      activitiesList.add(activity);
                      notifyListeners();
                      map['startTime'] = startTime;
                      map['activityId'] = activityId;
                      map['activityCreationDate'] =
                          activityCreationDate.toIso8601String();
                      counter++;
                      await addActivityToDB(map, activityCreationDate);
                      min += 30;
                    } else {
                      break;
                    }
                  }
                } else {
                  log("no");
                  min += 30;
                }
              }
            }
          }
        } else {
          for (var j = 0; j < 2; j++) {
            if (min == 60) {
              min -= 30;
            } else {
              log('FOR 5');
              log('$hour:$min');
              final temp = methods.converTimeTo12(timeFormater(hour, min));
              final startTime = '${temp[0]} ${temp[1]}';
              log('Start Time : $startTime , End Time: ${map['endTime']}');

              final check = checkIfActIsAlreadyPresentAtTheStartTime(
                  filteredActList, startTime);
              log('Check : $check');

              if (!check) {
                if (startTime != map['endTime']) {
                  var activityId = nanoid();
                  final activity = ActivityModel(
                    activityId: activityId,
                    activityName: map['taskName'],
                    activityCategoryName: map['categoryName'],
                    activityStartTime: startTime,
                    activityEndTime: map['endTime'],
                    activitySelectedDate: map['selectedDate'],
                    activityCreationDate: activityCreationDate,
                  );

                  activitiesList.add(activity);
                  notifyListeners();
                  map['startTime'] = startTime;
                  map['activityId'] = activityId;
                  map['activityCreationDate'] =
                      activityCreationDate.toIso8601String();
                  counter++;
                  await addActivityToDB(map, activityCreationDate);
                  min += 30;
                } else {
                  break;
                }
              } else {
                count++;
                if (count == 1) {
                  if (Platform.isIOS) {
                    val = await methods.showIosWarning(context);
                  } else {
                    val = await methods.showAndroidWarning(context);
                  }
                }

                if (val) {
                  var id = checkIfActIsAlreadyPresentActid(
                      filteredActList, startTime);

                  if (id != '') {
                    await deleteActivity(id, user);
                    if (startTime != map['endTime']) {
                      var activityId = nanoid();
                      final activity = ActivityModel(
                        activityId: activityId,
                        activityName: map['taskName'],
                        activityCategoryName: map['categoryName'],
                        activityStartTime: startTime,
                        activityEndTime: map['endTime'],
                        activitySelectedDate: map['selectedDate'],
                        activityCreationDate: activityCreationDate,
                      );

                      activitiesList.add(activity);
                      notifyListeners();
                      map['startTime'] = startTime;
                      map['activityId'] = activityId;
                      map['activityCreationDate'] =
                          activityCreationDate.toIso8601String();
                      counter++;
                      await addActivityToDB(map, activityCreationDate);
                      min += 30;
                    } else {
                      break;
                    }
                  }
                } else {
                  min += 30;
                }
              }
            }
          }
        }

        hour += 1;
        min = 0;
      }
    }
    count = 0;
    log('The Counter is : $counter');
  }

  //This function will add the newly added activity into DB
  Future<void> addActivityToDB(
      Map<String, dynamic> map, DateTime activityCreationDate) async {
    final headers = await createHeader();
    try {
      await dio.post(
          '${HelpingMethods.baseURL}/activity/addActivity',
          options: Options(
            contentType: 'application/json',
            headers: headers,
          ),
          data: json.encode(map));
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }
  }

  //This function will fetch all of the user activities from DB
  Future<void> fetchUserActivities() async {
    final headers = await createHeader();
    List<ActivityModel> listOfActivities = [];

    try {
      final response = await dio.get(
        '${HelpingMethods.baseURL}/activity/fetchUserActivities',
        options: Options(
          contentType: 'application/json',
          headers: headers,
        ),
      );

      final List<dynamic> jsonData = response.data['json'];

      listOfActivities = jsonData.map((activityMap) {
        return ActivityModel(
          activityId: activityMap['activity_id'],
          userId: activityMap['user_id'],
          activityName: activityMap['activity_name'],
          activityStartTime: activityMap['activity_start_time'].toString(),
          activityEndTime: activityMap['activity_end_time'].toString(),
          activityCategoryName: activityMap['activity_category_name'],
          activityCreationDate:
              DateTime.parse(activityMap['activity_creation_date']),
          activitySelectedDate: activityMap['activity_selected_date'],
        );
      }).toList();

      activitiesList = listOfActivities;

      notifyListeners();
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }
  }

  //This function will fetch user's percentages data from DB
  Future<Map<String, double>> fetchUserPercentagesData() async {
    final headers = await createHeader();
    Map<String, double> newMap = {};

    try {
      final response = await dio.get(
          '${HelpingMethods.baseURL}/activity/fetchUserActualPercentages',
          options: Options(contentType: 'application/json', headers: headers));

      if (response.statusCode == 200) {
        final responseData = response.data['data'][0] as Map<String, dynamic>;
        final actualPercentages =
            jsonDecode(responseData['actual_percentages']);
        if (actualPercentages.length == 0) {
          newMap = {
            'nutrition': 0.0,
            'exercise': 0.0,
            'occupation': 0.0,
            'wealth': 0.0,
            'creation': 0.0,
            'recreation': 0.0,
            'kids': 0.0,
            'family': 0.0,
            'romance': 0.0,
            'friends': 0.0,
            'spirituality': 0.0,
            'self_love': 0.0,
          };
        } else {
          newMap = {
            'nutrition': actualPercentages['nutrition'],
            'exercise': actualPercentages['exercise'],
            'occupation': actualPercentages['occupation'],
            'wealth': actualPercentages['wealth'],
            'creation': actualPercentages['creation'],
            'recreation': actualPercentages['recreation'],
            'kids': actualPercentages['kids'],
            'family': actualPercentages['family'],
            'romance': actualPercentages['romance'],
            'friends': actualPercentages['friends'],
            'spirituality': actualPercentages['spirituality'],
            'self_love': actualPercentages['self_love'],
          };
        }
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }

    return newMap;
  }

  //This function will fetch the user's actual percentages data from DB for Pie chart
  Map<String, double> actualPercentagesForPieChart() {
    final newMap = {
      'nutrition':
          double.tryParse(mapOfActualPercentages['nutrition'].toString()) ??
              0.0,
      'space1': mapOfActualPercentages['nutrition'] == 0.0 ? 0.0 : 0.4,
      'exercise':
          double.tryParse(mapOfActualPercentages['exercise'].toString()) ?? 0.0,
      'space2': mapOfActualPercentages['exercise'] == 0.0 ? 0.0 : 0.4,
      'occupation':
          double.tryParse(mapOfActualPercentages['occupation'].toString()) ??
              0.0,
      'space3': mapOfActualPercentages['occupation'] == 0.0 ? 0.0 : 0.4,
      'wealth':
          double.tryParse(mapOfActualPercentages['wealth'].toString()) ?? 0.0,
      'space4': mapOfActualPercentages['wealth'] == 0.0 ? 0.0 : 0.4,
      'creation':
          double.tryParse(mapOfActualPercentages['creation'].toString()) ?? 0.0,
      'space5': mapOfActualPercentages['creation'] == 0.0 ? 0.0 : 0.4,
      'recreation':
          double.tryParse(mapOfActualPercentages['recreation'].toString()) ??
              0.0,
      'space6': mapOfActualPercentages['recreation'] == 0.0 ? 0.0 : 0.4,
      'kids': double.tryParse(mapOfActualPercentages['kids'].toString()) ?? 0.0,
      'space7': mapOfActualPercentages['kids'] == 0.0 ? 0.0 : 0.4,
      'family':
          double.tryParse(mapOfActualPercentages['family'].toString()) ?? 0.0,
      'space8': mapOfActualPercentages['family'] == 0.0 ? 0.0 : 0.4,
      'romance':
          double.tryParse(mapOfActualPercentages['romance'].toString()) ?? 0.0,
      'space9': mapOfActualPercentages['romance'] == 0.0 ? 0.0 : 0.4,
      'friends':
          double.tryParse(mapOfActualPercentages['friends'].toString()) ?? 0.0,
      'space10': mapOfActualPercentages['friends'] == 0.0 ? 0.0 : 0.4,
      'spirituality':
          double.tryParse(mapOfActualPercentages['spirituality'].toString()) ??
              0.0,
      'space11': mapOfActualPercentages['spirituality'] == 0.0 ? 0.0 : 0.4,
      'self_love':
          double.tryParse(mapOfActualPercentages['self_love'].toString()) ??
              0.0,
      'space12': mapOfActualPercentages['self_love'] == 0.0 ? 0.0 : 0.4,
    };

    return newMap;
  }

  //This function will fetch the user's actual percentages from DB
  Future<void> fetchUserActualPercentages() async {
    final headers = await createHeader();

    try {
      final response = await dio.get(
          '${HelpingMethods.baseURL}/activity/fetchUserActualPercentages',
          options: Options(contentType: 'application/json', headers: headers));

      if (response.statusCode == 200) {
        final reportsResponse = await dio.get(
            '${HelpingMethods.baseURL}/reports/getReports',
            options: Options(
              contentType: 'application/json',
              headers: headers,
            ));

        final responseData = response.data['data'][0] as Map<String, dynamic>;
        final reportsData = json.decode(reportsResponse.data['reports']) ?? [];
        final halfHours = jsonDecode(responseData['counts']);
        final actualPercentages =
            jsonDecode(responseData['actual_percentages']);
        final startWeekDate =
            DateTime.parse(responseData['starting_week_date']);
        final endWeekDate = DateTime.parse(responseData['ending_week_date']);
        final startYearDate =
            DateTime.parse(responseData['starting_year_date']);
        final endYearDate = DateTime.parse(responseData['ending_year_date']);

        mapOfCounts = halfHours;
        mapOfActualPercentages = actualPercentages;
        startingWeekDate = startWeekDate;
        endingWeekDate = endWeekDate;
        startingYearDate = startYearDate;
        endingYearDate = endYearDate;
        listOfReports = reportsData;

        notifyListeners();
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }
  }

  //This function will filter out the activities for the selected date
  List<ActivityModel> filterActivities(String selectedDate) {
    String date = Jiffy.parse(selectedDate, pattern: 'MMMM EEEE d y')
        .format(pattern: 'y-MM-dd');

    // final dateInRequiredFormat = selectedDate.split(' ').join('-');
    final filteredActivities = activitiesList.where((activity) {
      String selected =
          Jiffy.parse(activity.activitySelectedDate, pattern: 'y-MM-dd')
              .format(pattern: 'y-MM-dd');
      return selected == date;
    }).toList();

    return filteredActivities.isEmpty ? [] : filteredActivities;
  }

  //This function will delete an activity from DB
  Future<void> deleteActivity(String activityId, UserModel user) async {
    final filteredActivities = activitiesList.where((activity) {
      return activity.activityId != activityId;
    }).toList();

    activitiesList = filteredActivities;

    notifyListeners();

    final headers = await createHeader();

    final map = {"activityID": activityId};

    try {
      final response = await dio.delete(
          '${HelpingMethods.baseURL}/activity/deleteActivity',
          options: Options(
            contentType: 'application/json',
            headers: headers,
          ),
          data: json.encode(map));

      if (response.statusCode == 200) {
        await syncActualPercentages(user);
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.message!;
      }
    } catch (e) {
      throw e.toString();
    }

    notifyListeners();
  }

  //This function will update an activity in DB
  Future<void> updateActivity(
      String activityId, Map<String, dynamic> map, UserModel user) async {
    log("BEFORE UPDATING : ${activitiesList.length}");

    final findActivities = activitiesList
        .where((activity) => activity.activityId == activityId)
        .toList();
    final indexesListOfActivities = [];

    for (var activity in findActivities) {
      final index = activitiesList.indexOf(activity);
      indexesListOfActivities.add(index);
    }

    final newActivitiesList = [];

    for (var i = 0; i < findActivities.length; i++) {
      final newActivity = ActivityModel(
        activityId: activityId,
        activityName: map['taskName'],
        activityStartTime: findActivities[i].activityStartTime,
        activityEndTime: findActivities[i].activityEndTime,
        activityCategoryName: map['categoryName'],
        activityCreationDate: findActivities[i].activityCreationDate,
        activitySelectedDate: findActivities[i].activitySelectedDate,
      );

      activitiesList.removeAt(indexesListOfActivities[i]);

      activitiesList.insert(indexesListOfActivities[i], newActivity);
    }

    log("AFTER UPDATING : ${activitiesList.length}");

    notifyListeners();

    final headers = await createHeader();

    map['activityID'] = activityId;

    try {
      await dio.patch(
          '${HelpingMethods.baseURL}/activity/updateActivity',
          options: Options(
            contentType: 'application/json',
            headers: headers,
          ),
          data: json.encode(map));

      await syncActualPercentages(user);
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  //This function will search all of the activities from DB through Category
  Future<List<ActivityModel>> searchByCategory(
      String categoryName, String rangeDate) async {
    //'November-Wednesday-2-2022'
    // 'MMMM EEEE d y'

    // String date = Jiffy(newDate).format('MMMM EEEE d y');

    final splittedDate = rangeDate.split(' ');
    final fromDate = Jiffy.parse(splittedDate[0], pattern: "yyyy-MM-dd")
        .format(pattern: 'yyyy-MM-dd');
    final fromDateInDateTime =
        DateTime.parse(splittedDate[2].trimLeft()).add(const Duration(days: 1));
    // final toDate = Jiffy.parseFromDateTime(fromDateInDateTime, "yyyy-MM-dd").format(pattern: 'yyyy-MM-dd');
    final toDate = Jiffy.parseFromDateTime(fromDateInDateTime)
        .format(pattern: 'yyyy-MM-dd');

    log('From Date: $fromDate');
    log('To Date: $toDate');
    List<ActivityModel> listOfActivities = [];

    try {
      final headers = await createHeader();

      final response = await dio.get(
          '${HelpingMethods.baseURL}/activity/searchUserActivities',
          options: Options(
            contentType: 'application/json',
            headers: headers,
          ),
          queryParameters: {"fromDate": fromDate, "toDate": toDate});

      final List<dynamic> jsonData = response.data['json'];

      listOfActivities = jsonData.map((activityMap) {
        return ActivityModel(
          activityId: activityMap['activity_id'],
          userId: activityMap['user_id'],
          activityName: activityMap['activity_name'],
          activityStartTime: activityMap['activity_start_time'].toString(),
          activityEndTime: activityMap['start_end_time'].toString(),
          activityCategoryName: activityMap['activity_category_name'],
          activityCreationDate:
              DateTime.parse(activityMap['activity_creation_date']),
          activitySelectedDate: activityMap['activity_selected_date'],
        );
      }).toList();

      final filteredActivityList = listOfActivities
          .where((activity) => activity.activityCategoryName == categoryName)
          .toList();
      filteredActivityList.retainWhere((activity) {
        final activityDate =
            Jiffy.parse(activity.activitySelectedDate, pattern: 'y-MM-dd');
        // final activityDate = Jiffy(activity.activitySelectedDate, "MMMM-EEEE-d-y");
        return (activityDate.isSameOrAfter(Jiffy.parse(fromDate)) &&
            activityDate.isSameOrBefore(Jiffy.parse(toDate)));
      });

      return filteredActivityList;
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }

    return [];
  }

  //This function will search all of the activities from DB through Activity Name
  Future<List<ActivityModel>> searchByActivityName(
      String activityName, String rangeDate) async {
    final splittedDate = rangeDate.split(' ');
    final fromDate = Jiffy.parse(splittedDate[0], pattern: "yyyy-MM-dd")
        .format(pattern: 'yyyy-MM-dd');
    final fromDateInDateTime =
        DateTime.parse(splittedDate[2].trimLeft()).add(const Duration(days: 1));
    // final toDate = Jiffy(fromDateInDateTime, "yyyy-MM-dd").format('yyyy-MM-dd');
    final toDate = Jiffy.parseFromDateTime(fromDateInDateTime)
        .format(pattern: 'yyyy-MM-dd');
    List<ActivityModel> listOfActivities = [];

    try {
      final headers = await createHeader();

      final response = await dio.get(
          '${HelpingMethods.baseURL}/activity/searchUserActivities',
          options: Options(
            contentType: 'application/json',
            headers: headers,
          ),
          queryParameters: {"fromDate": fromDate, "toDate": toDate});

      final List<dynamic> jsonData = response.data['json'];

      listOfActivities = jsonData.map((activityMap) {
        return ActivityModel(
          activityId: activityMap['activity_id'],
          userId: activityMap['user_id'],
          activityName: activityMap['activity_name'],
          activityStartTime: activityMap['activity_start_time'].toString(),
          activityEndTime: activityMap['start_end_time'].toString(),
          activityCategoryName: activityMap['activity_category_name'],
          activityCreationDate:
              DateTime.parse(activityMap['activity_creation_date']),
          activitySelectedDate: activityMap['activity_selected_date'],
        );
      }).toList();

      final filteredActivityList = listOfActivities.where((activity) {
        return activity.activityName.toLowerCase() == activityName;
      }).toList();
      filteredActivityList.retainWhere((activity) {
        // final activityDate = Jiffy(activity.activitySelectedDate, "MMMM-EEEE-d-y");
        final activityDate =
            Jiffy.parse(activity.activitySelectedDate, pattern: 'y-MM-dd');
        // final activityDate = DateTime.parse(temp[0]);
        return (activityDate.isSameOrAfter(Jiffy.parse(fromDate)) &&
            activityDate.isSameOrBefore(Jiffy.parse(toDate)));
      });

      return filteredActivityList;
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }

    return [];
  }

  //This function will sync the actual percentages every time we perform adding, deleting the activity in the application
  Future<void> syncActualPercentages(UserModel user) async {
    var temp = {
      'nutrition': 0.0,
      'exercise': 0.0,
      'occupation': 0.0,
      'wealth': 0.0,
      'creation': 0.0,
      'recreation': 0.0,
      'kids': 0.0,
      'family': 0.0,
      'romance': 0.0,
      'friends': 0.0,
      'spirituality': 0.0,
      'self_love': 0.0
    };

    //First we iterate through the activities list and check calculates each category reoccuring value
    for (var activity in activitiesList) {
      if (activity.activityCategoryName != 'Spiritual - Self-Love') {
        final splittedCategoryName = activity.activityCategoryName.split('-');
        final categoryName = splittedCategoryName[1].trimLeft().toLowerCase();
        var value = temp[categoryName]!; //Point to be noted
        value++;
        temp[categoryName] = value;
      } else {
        const categoryName = "self_love";
        var value = temp[categoryName]!;
        value++;
        temp[categoryName] = value;
      }
    }

    mapOfCounts = temp;

    //Second Creating a copy of mapOfCounts and storing it to the variable halfHours
    var halfHours = Map.fromEntries(mapOfCounts.entries);

    // //Third we are iterating through the halfHours map to get the half hour values by dividing each value by 2
    for (var values in halfHours.entries) {
      var catValues = values.value;
      if (catValues != 0.0) {
        catValues = catValues / 2;
        halfHours[values.key] = catValues;
      }
    }

    // //Fourth calculating a sum of values in halfHours map
    final totalHalfHours =
        halfHours.values.fold<double>(0, (previous, next) => previous + next);

    const fixedPercent = 100.0;
    for (var acVal in mapOfActualPercentages.entries) {
      double acValue = acVal.value;
      double hoursValue = halfHours[acVal.key]!;
      if (hoursValue != 0.0) {
        acValue = ((hoursValue / totalHalfHours) * fixedPercent);
        final temp = acValue.toString();
        mapOfActualPercentages[acVal.key] = double.tryParse(temp)!;
      } else {
        mapOfActualPercentages[acVal.key] = 0.0;
      }
    }

    try {
      await syncActualPercentagesInDB();
      await syncActualPercentagesInReports(user);
    } catch (e) {
      throw e.toString();
    }
  }

  //This function will sync the actual percentages data in DB
  Future<void> syncActualPercentagesInDB() async {
    final headers = await createHeader();

    try {
      await dio.patch(
          '${HelpingMethods.baseURL}/activity/updateActualPercentages',
          options: Options(
            contentType: 'application/json',
            headers: headers,
          ),
          data: json.encode({
            'counts': json.encode(mapOfCounts),
            'actualPercentages': json.encode(mapOfActualPercentages)
          }));
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }
  }

  //This function will sync the actual percentages data in reports
  Future<void> syncActualPercentagesInReports(UserModel user) async {
    try {
      final currentYear = DateTime.now().year;
      final currentDate = DateTime.now();
      // log(currentDate != endingYearDate);
      // log(currentDate);
      // log(endingYearDate);

      if (!currentDate.isAfter(endingYearDate)) {
        Map<String, dynamic> currentYearReport = listOfReports.firstWhere(
          (report) => report['Year'] == currentYear,
          orElse: () {
            log('/////////////////////////////');
          },
        );

        log(currentYearReport.toString());
        final indexOfCurrentYearReport =
            listOfReports.indexOf(currentYearReport);
        currentYearReport['actualPercentages'] = mapOfActualPercentages;
        listOfReports.removeAt(indexOfCurrentYearReport);
        listOfReports.insert(indexOfCurrentYearReport, currentYearReport);
        final headers = await createHeader();

        try {
          await dio.patch(
              '${HelpingMethods.baseURL}/reports/updateReports',
              options: Options(
                contentType: 'application/json',
                headers: headers,
              ),
              data: json.encode({
                'userId': user.userId,
                'reports': json.encode(listOfReports)
              }));
        } on DioError catch (e) {
          if (e.response != null) {
            throw e.response!;
          }
        }
      }
      // else {

      //   final currentYearStartingDate = DateTime(currentYear, 1, 1, 0, 0, 0);
      //   final currentYearEndingDate = DateTime(currentYear, 12, 31, 23, 59, 59);

      //   final yearlyReportDetails = [{
      //     'Year': currentYear,
      //     'YearStartingDate': currentYearStartingDate.toString(),
      //     'YearEndingDate': currentYearEndingDate.toString(),
      //     'desiredPercentages': user.mapOfDesiredPercentages,
      //     'actualPercentages': mapOfActualPercentages
      //   }];

      //   listOfReports.add(yearlyReportDetails);

      //   final headers = await createHeader();

      //   try {

      //     await dio.patch('${HelpingMethods.baseURL}/reports/updateReports', options: Options(
      //       contentType: 'application/json',
      //       headers: headers,
      //     ), data: json.encode({'userId': user.userId, 'reports': json.encode(listOfReports)}));

      //   }on DioError catch (e) {
      //     if (e.response != null) {
      //       throw e.response!;
      //     }
      //   }

      // }
    } catch (e) {
      log(e.toString());
    }
  }

  //This function will update the start and end week dates in DB
  Future<void> updateStartEndWeek() async {
    final headers = await createHeader();

    final prefs = await SharedPreferences.getInstance();

    final currentDate = DateTime.parse(prefs.getString('currentDate')!);

    try {
      final response = await dio.get(
          '${HelpingMethods.baseURL}/activity/fetchUserActualPercentages',
          options: Options(contentType: 'application/json', headers: headers));

      if (response.statusCode == 200) {
        final responseData = response.data['data'][0] as Map<String, dynamic>;
        final endWeekDate = DateTime.parse(responseData['ending_week_date']);
        final result = currentDate.compareTo(endWeekDate);
        log('Checking week');
        log(result.toString());
        if (result == 1) {
          final newStartingDate = DateTime.now();

          final datesMap = {
            'startingDate': DateTime.now().toString(),
            'endingDate':
                newStartingDate.add(const Duration(days: 6)).toString(),
          };

          final response = await dio.patch(
              '${HelpingMethods.baseURL}/activity/updateStartEndWeekDates',
              options:
                  Options(contentType: 'application/json', headers: headers),
              data: json.encode(datesMap));

          await prefs.setBool('NewWeek', true);

          // try {
          //   final mapOfActualPercentages = {'nutrition': 0.0,'exercise': 0.0,'occupation': 0.0,'wealth': 0.0,'creation': 0.0,'recreation': 0.0,'kids': 0.0,'family': 0.0,'romance': 0.0,'friends': 0.0,'spirituality': 0.0,'self_love': 0.0};
          //   final mapOfCounts = mapOfActualPercentages;
          //   await dio.patch('${HelpingMethods.baseURL}/activity/updateActualPercentages', options: Options(
          //     contentType: 'application/json',
          //     headers: headers,
          //   ), data: json.encode({'counts': json.encode(mapOfCounts), 'actualPercentages': json.encode(mapOfActualPercentages)}));

          //   await prefs.setBool('NewWeek', true);

          // } on DioError catch (e) {
          //   throw e.response!;
          // }
        }
      }

      final currentYearDate = DateTime.now();

      // final getCurrentYearEndDate = DateTime.parse(prefs.getString('currentYearEndDate')!);
      final getCurrentYearEndDate = endingYearDate;

      log('Checking Current Year Dates');
      log(currentYearDate.isAfter(getCurrentYearEndDate).toString());

      if (currentYearDate.isAfter(getCurrentYearEndDate)) {
        try {
          var year = DateTime.now().year;
          String startingNewYearDate = DateTime(year, 1, 1, 0, 0).toString();
          String endingNewYearDate = DateTime(year, 12, 31, 23, 59).toString();

          final datesMap = {
            'startingNewYearDate': startingNewYearDate,
            'endingNewYearDate': endingNewYearDate,
          };

          final response = await dio.patch(
              '${HelpingMethods.baseURL}/activity/updateStartEndYearDates',
              options:
                  Options(contentType: 'application/json', headers: headers),
              data: json.encode(datesMap));

          log(json.encode(datesMap));
        } on DioError catch (e) {
          log(e.toString());
          if (e.response != null) {
            throw e.response!;
          }
        }

        final currentYear = DateTime.now().year;

        final currentYearStartingDate = DateTime(currentYear, 1, 1, 0, 0, 0);
        final currentYearEndingDate = DateTime(currentYear, 12, 31, 23, 59, 59);

        final mapOfActualPercentages = {
          'nutrition': 0.0,
          'exercise': 0.0,
          'occupation': 0.0,
          'wealth': 0.0,
          'creation': 0.0,
          'recreation': 0.0,
          'kids': 0.0,
          'family': 0.0,
          'romance': 0.0,
          'friends': 0.0,
          'spirituality': 0.0,
          'self_love': 0.0
        };
        final mapOfDesiredPercentages = {
          'nutrition': 0.0,
          'exercise': 0.0,
          'occupation': 0.0,
          'wealth': 0.0,
          'creation': 0.0,
          'recreation': 0.0,
          'kids': 0.0,
          'family': 0.0,
          'romance': 0.0,
          'friends': 0.0,
          'spirituality': 0.0,
          'self_love': 0.0
        };

        final yearlyReportDetails = {
          'Year': currentYear,
          'YearStartingDate': currentYearStartingDate.toString(),
          'YearEndingDate': currentYearEndingDate.toString(),
          'desiredPercentages': mapOfDesiredPercentages,
          'actualPercentages': mapOfActualPercentages
        };

        listOfReports.add(yearlyReportDetails);

        try {
          await dio.patch(
              '${HelpingMethods.baseURL}/reports/updateReports',
              options: Options(
                contentType: 'application/json',
                headers: headers,
              ),
              data: json.encode({'reports': json.encode(listOfReports)}));
        } on DioError catch (e) {
          if (e.response != null) {
            throw e.response!;
          }
        }

        endingYearDate = currentYearEndingDate;
        startingYearDate = currentYearStartingDate;

        notifyListeners();
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }
  }

  //This function will get only the years of the available reports in the application
  Future<List<String>> getYearlyReportsYearsOnly() async {
    List<String> years = [];

    if (listOfReports.isNotEmpty) {
      for (var singleReport in listOfReports) {
        var year = singleReport['Year'].toString();
        years.add(year);
      }
    } else {
      final year = DateTime.now().year.toString();
      years.add(year);
    }

    return years;
  }

  //This function will fetch the selected Year activities
  Future<dynamic> fetchSelectedYearActivities(String year) async {
    final yearInt = int.tryParse(year);
    final currentYearReport =
        listOfReports.firstWhere((report) => report['Year'] == yearInt);

    if (currentYearReport != '') {
      final headers = await createHeader();

      final yearStartingDate = DateTime(int.tryParse(year)!, 1, 1, 0, 0, 0);
      final yearEndingDate = DateTime(int.tryParse(year)!, 12, 31, 23, 59, 59);

      final response = await dio.get(
          '${HelpingMethods.baseURL}/activity/getYearActivities',
          options: Options(
            contentType: 'applicaiton/json',
            headers: headers,
          ),
          queryParameters: {
            'startingDate': yearStartingDate,
            'endingDate': yearEndingDate
          });

      if (response.statusCode == 200) {
        List<dynamic> activities = response.data['activities'];

        final list = activities.map((activity) {
          return ActivityModel(
              activityId: activity['activity_id'],
              userId: activity['user_id'],
              activityName: activity['activity_name'],
              activityStartTime: activity['activity_start_time'],
              activityEndTime: activity['activity_end_time'],
              activityCategoryName: activity['activity_category_name'],
              activityCreationDate:
                  DateTime.parse(activity['activity_creation_date']),
              activitySelectedDate: activity['activity_selected_date']);
        });

        Map<int, List<ActivityModel>> map = {};

        for (var activity in list) {
          final actSelectedDate = activity.activitySelectedDate;
          final date = DateTime.parse(actSelectedDate);
          final month = (date.month) - 1;
          if (!map.containsKey(month)) {
            var list = map[month] ?? [];
            list.add(activity);
            map[month] = list;
          } else {
            map[month]!.add(activity);
          }
        }

        Map<int, Map<String, dynamic>> map2 = {};
        List<int> listOfMonthsNums = [];
        for (var currentMap in map.entries) {
          final monthMap = calculateActualPercentages(currentMap.value);
          map2[currentMap.key] = monthMap;
          listOfMonthsNums.add(currentMap.key);
        }
        final newMap = {
          'actualPercentages': [map2],
          'desiredPercentages': currentYearReport['desiredPercentages'],
          'months': listOfMonthsNums
        };
        return newMap;
      }
    }
  }

  //This function will reset the year's activities data from DB
  Future<void> resetYearlyReportDate(
      String year, String userId, String category) async {
    //Parsing the string year into int year value
    var yearInt = int.tryParse(year);
    //Filtereing the coming year report from the list of reports
    final currentYearReport =
        listOfReports.firstWhere((report) => report['Year'] == yearInt);
    //Getting the index of the filtered report
    final indexOfCurrentYearReport = listOfReports.indexOf(currentYearReport);

    //Making two maps for the actual and desired percentages
    final mapOfActualPercentages = {
      'nutrition': 0.0,
      'exercise': 0.0,
      'occupation': 0.0,
      'wealth': 0.0,
      'creation': 0.0,
      'recreation': 0.0,
      'kids': 0.0,
      'family': 0.0,
      'romance': 0.0,
      'friends': 0.0,
      'spirituality': 0.0,
      'self_love': 0.0
    };
    final mapOfDesiredPercentages = {
      'nutrition': 0.0,
      'exercise': 0.0,
      'occupation': 0.0,
      'wealth': 0.0,
      'creation': 0.0,
      'recreation': 0.0,
      'kids': 0.0,
      'family': 0.0,
      'romance': 0.0,
      'friends': 0.0,
      'spirituality': 0.0,
      'self_love': 0.0
    };

    //Assigning the new maps to filtered year report's maps
    currentYearReport['actualPercentages'] = mapOfActualPercentages;
    currentYearReport['desiredPercentages'] = mapOfDesiredPercentages;

    //Removing the old report from the list of reports
    listOfReports.removeAt(indexOfCurrentYearReport);
    //Inserting the newly modified filtered year report with new maps details back into list of reports on the same index
    listOfReports.insert(indexOfCurrentYearReport, currentYearReport);

    //Creating the header for network api call
    final headers = await createHeader();

    try {
      //Making PATCH API call
      final response = await dio.patch(
          '${HelpingMethods.baseURL}/reports/updateReports',
          options: Options(
            contentType: 'application/json',
            headers: headers,
          ),
          data: json.encode(
              {'userId': userId, 'reports': json.encode(listOfReports)}));

      //On error we will catch the error and throw it
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }
  }

  //This function will Selected Year activities only for the Line Chart
  Future<dynamic> fetchSelectedYearActivitiesForLineChart(
      String year, String userId, bool refresh) async {
    final headers = await createHeader();
    Map<String, List<FlSpot>> monthsMap = {};
    // final yearInt = int.tryParse(year);
    // final currentYearReport = listOfReports.firstWhere((report) => report['Year'] == yearInt);

    try {
      final yearStartingDate = DateTime(int.tryParse(year)!, 1, 1, 0, 0, 0);
      final yearEndingDate = DateTime(int.tryParse(year)!, 12, 31, 23, 59, 59);

      final response = await dio.get(
          '${HelpingMethods.baseURL}/activity/getYearActivities',
          options: Options(
            contentType: 'applicaiton/json',
            headers: headers,
          ),
          queryParameters: {
            'startingDate': yearStartingDate,
            'endingDate': yearEndingDate
          });

      if (response.statusCode == 200) {
        List<dynamic> activities = response.data['activities'];

        final list = activities.map((activity) {
          return ActivityModel(
              activityId: activity['activity_id'],
              userId: activity['user_id'],
              activityName: activity['activity_name'],
              activityStartTime: activity['activity_start_time'],
              activityEndTime: activity['activity_end_time'],
              activityCategoryName: activity['activity_category_name'],
              activityCreationDate:
                  DateTime.parse(activity['activity_creation_date']),
              activitySelectedDate: activity['activity_selected_date']);
        });

        Map<int, List<ActivityModel>> map = {};

        for (var activity in list) {
          final actSelectedDate = activity.activitySelectedDate;
          final date = DateTime.parse(actSelectedDate);
          final month = (date.month) - 1;
          if (!map.containsKey(month)) {
            var list = map[month] ?? [];
            list.add(activity);
            map[month] = list;
          } else {
            map[month]!.add(activity);
          }
        }

        Map<int, Map<String, dynamic>> map2 = {};

        for (var currentMap in map.entries) {
          final monthMap = calculateActualPercentages(currentMap.value);
          map2[currentMap.key] = monthMap;
        }

        const listOfCategories = [
          'Nutrition',
          'Exercise',
          'Occupation',
          'Wealth',
          'Creation',
          'Recreation',
          'Kids',
          'Family',
          'Romance',
          'Friends',
          'Spirituality',
          'Self-Love'
        ];
        Map<String, List<FlSpot>> listOfFlSpots = {};

        for (var currentCategory in listOfCategories) {
          listOfFlSpots[currentCategory] = [];
          var value = 0.0;
          for (var index in listOfCategories) {
            final xValue = value;
            final temp = map2[listOfCategories.indexOf(index)] ?? {};
            double yValue = temp[currentCategory.toLowerCase() == 'self-love'
                    ? 'self_love'
                    : currentCategory.toLowerCase()] ??
                0.0;
            final flSpot = FlSpot(xValue, yValue.floor().toDouble());
            listOfFlSpots[currentCategory]!.add(flSpot);
            value++;
          }
        }

        // for (var map in listOfFlSpots.entries) {

        //   final list = map.value;

        //   list.removeWhere((fl) => fl.y == 0.0);
        // }

        monthsMap = {
          'Nutrition': listOfFlSpots['Nutrition']!,
          'Exercise': listOfFlSpots['Exercise']!,
          'Occupation': listOfFlSpots['Occupation']!,
          'Wealth': listOfFlSpots['Wealth']!,
          'Creation': listOfFlSpots['Creation']!,
          'Recreation': listOfFlSpots['Recreation']!,
          'Kids': listOfFlSpots['Kids']!,
          'Family': listOfFlSpots['Family']!,
          'Romance': listOfFlSpots['Romance']!,
          'Friends': listOfFlSpots['Friends']!,
          'Spirituality': listOfFlSpots['Spirituality']!,
          'Self-Love': listOfFlSpots['Self-Love']!
        };

        // final ran = Random();

        // monthsMap = {
        //   'Nutrition' :  [FlSpot(0.0, ran.nextDouble() * 100), FlSpot(1.0, ran.nextDouble() * 100), FlSpot(2.0, ran.nextDouble() * 100), FlSpot(3.0, ran.nextDouble() * 100), FlSpot(4.0, ran.nextDouble() * 100), FlSpot(5.0, ran.nextDouble() * 100), FlSpot(6.0, ran.nextDouble() * 100), FlSpot(7.0, ran.nextDouble() * 100), FlSpot(8.0, ran.nextDouble() * 100), FlSpot(9.0, ran.nextDouble() * 100), FlSpot(10.0, ran.nextDouble() * 100), FlSpot(11.0, ran.nextDouble() * 100), FlSpot(12.0, ran.nextDouble() * 100)],
        //   'Exercise' :   [FlSpot(0.0, ran.nextDouble() * 100), FlSpot(1.0, ran.nextDouble() * 100), FlSpot(2.0, ran.nextDouble() * 100), FlSpot(3.0, ran.nextDouble() * 100), FlSpot(4.0, ran.nextDouble() * 100), FlSpot(5.0, ran.nextDouble() * 100), FlSpot(6.0, ran.nextDouble() * 100), FlSpot(7.0, ran.nextDouble() * 100), FlSpot(8.0, ran.nextDouble() * 100), FlSpot(9.0, ran.nextDouble() * 100), FlSpot(10.0, ran.nextDouble() * 100), FlSpot(11.0, ran.nextDouble() * 100), FlSpot(12.0, ran.nextDouble() * 100)],
        //   'Occupation' : [FlSpot(0.0, ran.nextDouble() * 100), FlSpot(1.0, ran.nextDouble() * 100), FlSpot(2.0, ran.nextDouble() * 100), FlSpot(3.0, ran.nextDouble() * 100), FlSpot(4.0, ran.nextDouble() * 100), FlSpot(5.0, ran.nextDouble() * 100), FlSpot(6.0, ran.nextDouble() * 100), FlSpot(7.0, ran.nextDouble() * 100), FlSpot(8.0, ran.nextDouble() * 100), FlSpot(9.0, ran.nextDouble() * 100), FlSpot(10.0, ran.nextDouble() * 100), FlSpot(11.0, ran.nextDouble() * 100), FlSpot(12.0, ran.nextDouble() * 100)],
        //   'Wealth' :     [FlSpot(0.0, ran.nextDouble() * 100), FlSpot(1.0, ran.nextDouble() * 100), FlSpot(2.0, ran.nextDouble() * 100), FlSpot(3.0, ran.nextDouble() * 100), FlSpot(4.0, ran.nextDouble() * 100), FlSpot(5.0, ran.nextDouble() * 100), FlSpot(6.0, ran.nextDouble() * 100), FlSpot(7.0, ran.nextDouble() * 100), FlSpot(8.0, ran.nextDouble() * 100), FlSpot(9.0, ran.nextDouble() * 100), FlSpot(10.0, ran.nextDouble() * 100), FlSpot(11.0, ran.nextDouble() * 100), FlSpot(12.0, ran.nextDouble() * 100)],
        //   'Creation' :   [FlSpot(0.0, ran.nextDouble() * 100), FlSpot(1.0, ran.nextDouble() * 100), FlSpot(2.0, ran.nextDouble() * 100), FlSpot(3.0, ran.nextDouble() * 100), FlSpot(4.0, ran.nextDouble() * 100), FlSpot(5.0, ran.nextDouble() * 100), FlSpot(6.0, ran.nextDouble() * 100), FlSpot(7.0, ran.nextDouble() * 100), FlSpot(8.0, ran.nextDouble() * 100), FlSpot(9.0, ran.nextDouble() * 100), FlSpot(10.0, ran.nextDouble() * 100), FlSpot(11.0, ran.nextDouble() * 100), FlSpot(12.0, ran.nextDouble() * 100)],
        //   'Recreation' : [FlSpot(0.0, ran.nextDouble() * 100), FlSpot(1.0, ran.nextDouble() * 100), FlSpot(2.0, ran.nextDouble() * 100), FlSpot(3.0, ran.nextDouble() * 100), FlSpot(4.0, ran.nextDouble() * 100), FlSpot(5.0, ran.nextDouble() * 100), FlSpot(6.0, ran.nextDouble() * 100), FlSpot(7.0, ran.nextDouble() * 100), FlSpot(8.0, ran.nextDouble() * 100), FlSpot(9.0, ran.nextDouble() * 100), FlSpot(10.0, ran.nextDouble() * 100), FlSpot(11.0, ran.nextDouble() * 100), FlSpot(12.0, ran.nextDouble() * 100)],
        //   'Kids' :       [FlSpot(0.0, ran.nextDouble() * 100), FlSpot(1.0, ran.nextDouble() * 100), FlSpot(2.0, ran.nextDouble() * 100), FlSpot(3.0, ran.nextDouble() * 100), FlSpot(4.0, ran.nextDouble() * 100), FlSpot(5.0, ran.nextDouble() * 100), FlSpot(6.0, ran.nextDouble() * 100), FlSpot(7.0, ran.nextDouble() * 100), FlSpot(8.0, ran.nextDouble() * 100), FlSpot(9.0, ran.nextDouble() * 100), FlSpot(10.0, ran.nextDouble() * 100), FlSpot(11.0, ran.nextDouble() * 100), FlSpot(12.0, ran.nextDouble() * 100)],
        //   'Family' :     [FlSpot(0.0, ran.nextDouble() * 100), FlSpot(1.0, ran.nextDouble() * 100), FlSpot(2.0, ran.nextDouble() * 100), FlSpot(3.0, ran.nextDouble() * 100), FlSpot(4.0, ran.nextDouble() * 100), FlSpot(5.0, ran.nextDouble() * 100), FlSpot(6.0, ran.nextDouble() * 100), FlSpot(7.0, ran.nextDouble() * 100), FlSpot(8.0, ran.nextDouble() * 100), FlSpot(9.0, ran.nextDouble() * 100), FlSpot(10.0, ran.nextDouble() * 100), FlSpot(11.0, ran.nextDouble() * 100), FlSpot(12.0, ran.nextDouble() * 100)],
        //   'Romance' :    [FlSpot(0.0, ran.nextDouble() * 100), FlSpot(1.0, ran.nextDouble() * 100), FlSpot(2.0, ran.nextDouble() * 100), FlSpot(3.0, ran.nextDouble() * 100), FlSpot(4.0, ran.nextDouble() * 100), FlSpot(5.0, ran.nextDouble() * 100), FlSpot(6.0, ran.nextDouble() * 100), FlSpot(7.0, ran.nextDouble() * 100), FlSpot(8.0, ran.nextDouble() * 100), FlSpot(9.0, ran.nextDouble() * 100), FlSpot(10.0, ran.nextDouble() * 100), FlSpot(11.0, ran.nextDouble() * 100), FlSpot(12.0, ran.nextDouble() * 100)],
        //   'Friends' :    [FlSpot(0.0, ran.nextDouble() * 100), FlSpot(1.0, ran.nextDouble() * 100), FlSpot(2.0, ran.nextDouble() * 100), FlSpot(3.0, ran.nextDouble() * 100), FlSpot(4.0, ran.nextDouble() * 100), FlSpot(5.0, ran.nextDouble() * 100), FlSpot(6.0, ran.nextDouble() * 100), FlSpot(7.0, ran.nextDouble() * 100), FlSpot(8.0, ran.nextDouble() * 100), FlSpot(9.0, ran.nextDouble() * 100), FlSpot(10.0, ran.nextDouble() * 100), FlSpot(11.0, ran.nextDouble() * 100), FlSpot(12.0, ran.nextDouble() * 100)],
        //  'Spirituality': [FlSpot(0.0, ran.nextDouble() * 100), FlSpot(1.0, ran.nextDouble() * 100), FlSpot(2.0, ran.nextDouble() * 100), FlSpot(3.0, ran.nextDouble() * 100), FlSpot(4.0, ran.nextDouble() * 100), FlSpot(5.0, ran.nextDouble() * 100), FlSpot(6.0, ran.nextDouble() * 100), FlSpot(7.0, ran.nextDouble() * 100), FlSpot(8.0, ran.nextDouble() * 100), FlSpot(9.0, ran.nextDouble() * 100), FlSpot(10.0, ran.nextDouble() * 100), FlSpot(11.0, ran.nextDouble() * 100), FlSpot(12.0, ran.nextDouble() * 100)],
        //   'Self-Love' :  [FlSpot(0.0, ran.nextDouble() * 100), FlSpot(1.0, ran.nextDouble() * 100), FlSpot(2.0, ran.nextDouble() * 100), FlSpot(3.0, ran.nextDouble() * 100), FlSpot(4.0, ran.nextDouble() * 100), FlSpot(5.0, ran.nextDouble() * 100), FlSpot(6.0, ran.nextDouble() * 100), FlSpot(7.0, ran.nextDouble() * 100), FlSpot(8.0, ran.nextDouble() * 100), FlSpot(9.0, ran.nextDouble() * 100), FlSpot(10.0, ran.nextDouble() * 100), FlSpot(11.0, ran.nextDouble() * 100), FlSpot(12.0, ran.nextDouble() * 100)],
        // };

        return monthsMap;
      }
    } on DioError catch (e) {
      throw e.response!;
    }
  }

  //The function will create header for the network api call
  Future<Map<String, String>> createHeader() async {
    //Creating sharedpreferences instance
    final prefs = await SharedPreferences.getInstance();

    //Creating an empty header map
    Map<String, String> header = {};

    //Checking if the token is present in the application's local storage
    final token = prefs.getString('loginTimeToken')!;

    //Creating header with appropriate information
    header = {
      "Access-Control-Allow-Origin": "*",
      "authorization_token": token,
    };

    //Returning the header
    return header;
  }

  //This function will calculate the actual percentages for each of the category
  Map<String, dynamic> calculateActualPercentages(
    dynamic listOfActivities,
  ) {
    Map<String, double> mapOfCounts = {
      'nutrition': 0.0,
      'exercise': 0.0,
      'occupation': 0.0,
      'wealth': 0.0,
      'creation': 0.0,
      'recreation': 0.0,
      'kids': 0.0,
      'family': 0.0,
      'romance': 0.0,
      'friends': 0.0,
      'spirituality': 0.0,
      'self_love': 0.0
    };

    Map<String, double> mapOfActualPercentages = {
      'nutrition': 0.0,
      'exercise': 0.0,
      'occupation': 0.0,
      'wealth': 0.0,
      'creation': 0.0,
      'recreation': 0.0,
      'kids': 0.0,
      'family': 0.0,
      'romance': 0.0,
      'friends': 0.0,
      'spirituality': 0.0,
      'self_love': 0.0
    };

    for (var activity in listOfActivities) {
      if (activity.activityCategoryName != 'Spiritual - Self-Love') {
        final splittedCategoryName = activity.activityCategoryName.split('-');
        final categoryName = splittedCategoryName[1].trimLeft().toLowerCase();
        var value = mapOfCounts[categoryName]!; //Point to be noted
        value++;
        mapOfCounts[categoryName] = value;
      } else {
        const categoryName = "self_love";
        var value = mapOfCounts[categoryName]!;
        value++;
        mapOfCounts[categoryName] = value;
      }
    }

    var halfHours = Map.fromEntries(mapOfCounts.entries);

    for (var values in halfHours.entries) {
      var catValues = values.value;
      if (catValues != 0.0) {
        catValues = catValues / 2;
        halfHours[values.key] = catValues;
      }
    }

    final totalHalfHours =
        halfHours.values.fold<double>(0, (previous, next) => previous + next);

    const fixedPercent = 100.0;
    for (var acVal in mapOfActualPercentages.entries) {
      double acValue = acVal.value;
      double hoursValue = halfHours[acVal.key]!;
      if (hoursValue != 0.0) {
        acValue = ((hoursValue / totalHalfHours) * fixedPercent);
        final temp = acValue.toString();
        mapOfActualPercentages[acVal.key] = double.tryParse(temp)!;
      }
    }

    return mapOfActualPercentages;
  }

  //This function will only reset the activities list from the memory
  void resetActivitiesList() {
    //Assigning an empty list to the activities list
    activitiesList = [];
  }
}

//Saving the FlSpots in Yearly Reports
// final newMap = {
//   'Nutrition' : nutrition.toString(),
//   'Exercise' : exercise.toString(),
//   'Occupation' : occupation,
//   'Wealth' : wealth,
//   'Creation' : creation,
//   'Recreation' : recreation,
//   'Kids' : kids,
//   'Family' : family,
//   'Romance' : romance,
//   'Firends' : friends,
//   'Spirituality' : spirituality,
//   'Self_Love' : selflove
// };

// final currentYearReport = listOfReports.firstWhere((report) => report['Year'] == yearInt);
// final indexOfCurrentYearReport = listOfReports.indexOf(currentYearReport);

// currentYearReport['FlSpots'] = json.encode(newMap);

// listOfReports.removeAt(indexOfCurrentYearReport);
// listOfReports.insert(indexOfCurrentYearReport, currentYearReport);

// try {

//   final headers = await createHeader();

//   await dio.patch('${HelpingMethods.baseURL}/reports/updateReports', options: Options(
//     contentType: 'application/json',
//     headers: headers,
//   ), data: json.encode({'userId': userId, 'reports': json.encode(listOfReports)}));

// } on DioError catch (e) {
//   if (e.response != null) {
//     throw e.response!;
//   }
// }
