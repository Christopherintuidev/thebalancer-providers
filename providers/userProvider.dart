// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nanoid/nanoid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_balancer/helpingMethods/methods.dart';
import 'package:the_balancer/models/user_model.dart';
import 'package:the_balancer/providers/activityProvider.dart';

class UserProvider extends ChangeNotifier {
  //Decalring and intializing the variables for the class User Provider

  final dio = Dio();

  String currentUserToken = '';

  UserModel currentUser = UserModel.emptyUser();

  String get getCurrentUserToken => currentUserToken;

  UserModel get getCurrentUser => currentUser;

  Map<String, double> get getUserDesiredPercentages =>
      currentUser.mapOfDesiredPercentages;

  Map<String, double> desiredPercentagesForProgressbar = {};

  var facebookObj;

  //This function will verify the user's email address
  Future<bool> verifyUserEmail(Map<String, dynamic> map, bool isFromForgotPass,
      [String forgotPassEmail = '']) async {
    Map<String, dynamic> newMap = {};

    if (isFromForgotPass) {
      newMap = {'userEmail': forgotPassEmail, 'isFromForgotPass': true};
    } else {
      newMap = {
        'userName': map['userName'],
        'userEmail': map['userEmail'],
        'isFromForgotPass': false
      };
    }

    try {
      final response = await dio.post(
          '${HelpingMethods.baseURL}/verify/userEmail',
          options: Options(
            contentType: 'application/json',
            headers: {"Access-Control-Allow-Origin": "*"},
          ),
          data: json.encode(newMap));

      final responseData = response.statusCode;

      if (responseData == 200) {
        return true;
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }

    return false;
  }

  //This function will check if user's email is already exists in DB
  Future<bool> checkIfUserEmailExists(String userEmail) async {
    try {
      final response = await dio.post(
          '${HelpingMethods.baseURL}/check/checkIfUserEmailExists',
          options: Options(
            contentType: 'application/json',
            headers: {"Access-Control-Allow-Origin": "*"},
          ),
          data: json.encode({'userEmail': userEmail}));

      if (response.data == 'true') {
        return true;
      } else if (response.data == 'false') {
        return false;
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }

    return false;
  }

  //This function will get the user's token, get user's data and then map the data on current user
  Future<dynamic> getUserTokenAndMapData(
      String identifier, bool isEmail) async {
    try {
      final response = await dio.post(
          '${HelpingMethods.baseURL}/auth/getTokenOnly',
          options: Options(headers: {"Access-Control-Allow-Origin": "*"}),
          data: {"identifier": identifier, "isEmail": isEmail});

      if (response.statusCode == 200) {
        final data = response.data;
        final token = data['token'];

        final dataResponse = await fetchUserData(token);

        return dataResponse;
      }
    } on DioError catch (e) {
      print(e.toString());
      throw e.toString();
    } catch (e) {
      print(e.toString());
      throw e.toString();
    }
  }

  //This function will resend OTP to the user's email address
  Future<bool> resendOTP(String userEmail) async {
    final map = {'userEmail': userEmail};

    try {
      final response = await dio.post(
          '${HelpingMethods.baseURL}/verify/resendOTP',
          options: Options(
            contentType: 'application/json',
            headers: {"Access-Control-Allow-Origin": "*"},
          ),
          data: json.encode(map));

      final responseData = response.statusCode;

      if (responseData == 200) {
        return true;
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }

    return false;
  }

  //This function will send the OTP to the server for verification
  Future<bool> sendOTPTOServer(String otp, bool isFromResend) async {
    final intValueOTP = int.tryParse(otp);

    try {
      final response = await dio.post(
          '${HelpingMethods.baseURL}/verify/number',
          options: Options(
            contentType: 'application/json',
            headers: {"Access-Control-Allow-Origin": "*"},
          ),
          data:
              json.encode({'otp': intValueOTP, 'isFromResend': isFromResend}));

      final responseData = response.statusCode;

      if (responseData == 200) {
        return true;
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }

    return false;
  }

  //This function will send the user's new password to the server
  Future<bool> sendNewPassToServer(
      String userEmail, String newPassword, bool isFromForgotPass,
      [String oldPassword = '']) async {
    Map<String, dynamic> map = {};

    if (isFromForgotPass) {
      map = {
        'userEmail': userEmail,
        'userNewPass': newPassword,
        'isFromForgotPass': isFromForgotPass
      };
    } else {
      final prefs = await SharedPreferences.getInstance();
      final pass = prefs.getString('loginTimeToken');
      map = {
        'userEmail': userEmail,
        'userNewPass': newPassword,
        'userOldPass': oldPassword,
        'isFromForgotPass': isFromForgotPass,
        'pass': pass
      };
    }

    try {
      final response = await dio.post(
          '${HelpingMethods.baseURL}/create/changePassword',
          options: Options(
            contentType: 'application/json',
            headers: {
              "Access-Control-Allow-Origin": "*",
            },
          ),
          data: json.encode(map));

      final responseData = response.statusCode;

      if (responseData == 200) {
        return true;
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }

    return false;
  }

  //This function will create a new user account through email and password method
  Future<dynamic> createNewUserThroughEmailMethod(
      Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = nanoid();
    final notificationSettingsId = nanoid();

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

    final completeDetails = {
      'userId': userId,
      'userName': map['userName'],
      'userEmail': map['userEmail'],
      'userPassword': map['userPassword'],
      'userDesiredPercentages': json.encode(mapOfDesiredPercentages),
      'userSignInMethod': map['signInMethod'],
      'notificationSettingsId': notificationSettingsId,
      'userImage': map['userImage'],
    };

    try {
      final response = await dio.post(
          '${HelpingMethods.baseURL}/create/createUser',
          options: Options(
            contentType: 'application/json',
            headers: {"Access-Control-Allow-Origin": "*"},
          ),
          data: json.encode(completeDetails));

      final responseData = response.data;
      final token = responseData['token'];

      await prefs.setString('registeredTimeToken', token);

      if (responseData['response'] == true) {
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

        final yearlyReportDetails = [
          {
            'Year': currentYear,
            'YearStartingDate': currentYearStartingDate.toString(),
            'YearEndingDate': currentYearEndingDate.toString(),
            'desiredPercentages': mapOfDesiredPercentages,
            'actualPercentages': mapOfActualPercentages
          }
        ];

        final reportsResponse = await dio.post(
            '${HelpingMethods.baseURL}/reports/insertReport',
            options: Options(
              contentType: 'application/json',
              headers: {"Access-Control-Allow-Origin": "*"},
            ),
            data: json.encode({
              'userId': userId,
              'reports': json.encode(yearlyReportDetails)
            }));

        if (reportsResponse.statusCode == 200) {
          await prefs.setString('login-through', 'email-pass');

          await loginUserThroughUsernameAndPassword(
              map['userName'], map['userPassword']);

          return true;
        }
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.message!;
      }
    } catch (e) {
      throw e.toString();
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

  //This function will login the user through email and password method
  Future<dynamic> loginUserThroughUsernameAndPassword(
      String input, String password,
      [bool isEmail = false]) async {
    final prefs = await SharedPreferences.getInstance();
    var credential = {};

    if (isEmail) {
      credential = {
        'input': input,
        'password': password,
        'isEmail': isEmail,
      };
    } else {
      credential = {
        'input': input,
        'password': password,
        'isEmail': isEmail,
      };
    }

    try {
      final response =
          await dio.post('${HelpingMethods.baseURL}/auth/loginUser',
              options: Options(
                contentType: 'application/json',
              ),
              data: json.encode(credential));

      final newToken = response.data['token'];

      await prefs.setString('loginTimeToken', newToken);

      final responseData = await fetchUserData();

      if (responseData) {
        return true;
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }
  }

  //This function will login the user through Facebook
  Future<dynamic> facebookLogin({bool isFromSignIn = false}) async {
    try {
      final LoginResult result = await FacebookAuth.instance
          .login(permissions: ['email', 'public_profile']);

      if (result.status == LoginStatus.success) {
        facebookObj = result;

        final userData = await FacebookAuth.instance.getUserData();
        final pictureMap = userData['picture'];
        final email = userData['email'] ?? '${userData['name']}@balancer.com';
        final userId = userData['id'];
        //final userImageUrl = pictureMap['data']['url'];
        final userImageUrl = pictureMap['url'];
        final userName = userData['name'];

        //Here we will check if the email and userName is already present inside the DB
        final isFacebookUserPresent = await dio.post(
            '${HelpingMethods.baseURL}/check/checkIfUserEmailExists',
            options: Options(
              contentType: 'application/json',
            ),
            data: json.encode({'userEmail': email}));

        if (isFacebookUserPresent.data == 'false') {
          if (!isFromSignIn) {
            await FacebookAuth.instance.logOut();
          }

          // if (isFromSignIn) {
          //   await loginUserThroughUsernameAndPassword(userName!, email);
          // }

          return {'loggedIn': true, 'email': email};
        } else {
          if (!isFromSignIn || isFromSignIn) {
            await FacebookAuth.instance.logOut();
          }

          final map = {
            'userName': userName,
            'userEmail': email,
            'userPassword': email,
            'userImage': userImageUrl,
            'signInMethod': 2,
          };

          log(map.toString());

          return map;
        }
      } else {
        return null;
      }
    } on PlatformException catch (e) {
      throw e.message!;
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  //This function will login user through Google
  Future<dynamic> googleLogin({bool isFromSignIn = false}) async {
    //Development iOS Client
    // const String clientIdForIOS = "991008029978-hegcfg783qt6290om50ul8v67tttts8c.apps.googleusercontent.com";

    //Production iOS Client
    const String clientIdForIOS =
        "991008029978-nijkh8capoe3unfedpt55ggqdto7o148.apps.googleusercontent.com";
    GoogleSignIn? googleSignIn;

    if (Platform.isAndroid) {
      googleSignIn = GoogleSignIn(scopes: <String>['email', 'profile']);
    } else {
      googleSignIn = GoogleSignIn(clientId: clientIdForIOS);
    }

    try {
      GoogleSignInAccount? response = await googleSignIn.signIn();

      if (response != null) {
        final userName = response.displayName;
        final email = response.email;
        final userId = response.id;
        final userImageUrl = response.photoUrl;

        //192.168.18.74
        //${HelpingMethods.baseURL}/check/checkGoogleUser
        final isGoogleUserPresent = await dio.post(
            '${HelpingMethods.baseURL}/check/checkIfUserEmailExists',
            options: Options(
              contentType: 'application/json',
            ),
            data: json.encode({'userEmail': email}));

        //json.encode({'userName': userName, 'userEmail': email})

        if (isGoogleUserPresent.data == 'false') {
          // await loginUserThroughUsernameAndPassword(userName!, userId);

          if (!isFromSignIn) {
            await googleSignIn.signOut();
          }

          return {'loggedIn': true, 'email': email};
        } else {
          if (isFromSignIn) {
            await googleSignIn.signOut();
          }

          final map = {
            'userName': userName,
            'userEmail': email,
            'userPassword': userId,
            'userImage': userImageUrl,
            'signInMethod': 1,
          };

          log(map.toString());

          return map;
        }
      } else {
        return null;
      }
    } on PlatformException catch (e) {
      throw e.message!;
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  //This function will fetch all of the user's data
  Future<dynamic> fetchUserData([String? upcomingToken]) async {
    try {
      Response response;

      if (upcomingToken != null) {
        response = await dio.get(
          '${HelpingMethods.baseURL}/get/getUserData',
          options: Options(
            contentType: 'application/json',
            headers: {
              "Access-Control-Allow-Origin": "*",
              "authorization_token": upcomingToken,
            },
          ),
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('loginTimeToken', upcomingToken);
      } else {
        final header = await createHeader();

        response = await dio.get(
          '${HelpingMethods.baseURL}/get/getUserData',
          options: Options(
            contentType: 'application/json',
            headers: header,
          ),
        );
      }

      if (response.statusCode == 404) {
        throw response.data;
      } else {
        final userData = response.data['json'][0] as Map<String, dynamic>;
        log(userData.toString());

        final desiredPercentages =
            jsonDecode(userData['user_desiredpercentages']);

        var imagePath;
        String completeUrl = '';

        final signInMethod = userData['user_sign_in_method'];

        if (signInMethod == 1) {
          String imageUrl = userData['user_image'] ?? '';

          if (imageUrl.startsWith('uploads/profileImages/')) {
            imagePath = userData['user_image'] == ''
                ? ''
                : userData['user_image'].split('/');

            completeUrl = imagePath == ''
                ? ''
                : "${HelpingMethods.baseURL}/${imagePath[2]}";
          } else {
            completeUrl = userData['user_image'] ?? '';
          }
        } else if (signInMethod == 2) {
          String imageUrl = userData['user_image'] ?? '';

          if (imageUrl.startsWith('uploads/profileImages/')) {
            imagePath = userData['user_image'] == ''
                ? ''
                : userData['user_image'].split('/');

            completeUrl = imagePath == ''
                ? ''
                : "${HelpingMethods.baseURL}/${imagePath[2]}";
          } else {
            completeUrl = userData['user_image'] ?? '';
          }
        } else {
          if (userData['user_image'] != '' && userData['user_image'] != null) {
            imagePath = userData['user_image'] == ''
                ? ''
                : userData['user_image'].split('/');

            completeUrl = imagePath == ''
                ? ''
                : "${HelpingMethods.baseURL}/${imagePath[2]}";
          } else {
            completeUrl = '';
          }
        }
        log(completeUrl);

        final user = UserModel(
            userId: userData['user_id'],
            userName: userData['user_name'],
            userEmail: userData['user_email'],
            userPassword: userData['user_password'],
            userFirstName: userData['user_firstname'] ?? '',
            userLastName: userData['user_lastname'] ?? '',
            userPhoneNumber: userData['user_phonenumber'] ?? '',
            userBirthday: userData['user_birthday'],
            userImage: completeUrl,
            accountCreationDate:
                DateTime.parse(userData['accountcreationdate']),
            signInMethod: signInMethod!,
            token: userData['jwt_token'],
            mapOfDesiredPercentages: {
              'nutrition': desiredPercentages['nutrition'],
              'space1': desiredPercentages['nutrition'] == 0.0 ? 0.0 : 0.4,
              'exercise': desiredPercentages['exercise'],
              'space2': desiredPercentages['exercise'] == 0.0 ? 0.0 : 0.4,
              'occupation': desiredPercentages['occupation'],
              'space3': desiredPercentages['occupation'] == 0.0 ? 0.0 : 0.4,
              'wealth': desiredPercentages['wealth'],
              'space4': desiredPercentages['wealth'] == 0.0 ? 0.0 : 0.4,
              'creation': desiredPercentages['creation'],
              'space5': desiredPercentages['creation'] == 0.0 ? 0.0 : 0.4,
              'recreation': desiredPercentages['recreation'],
              'space6': desiredPercentages['recreation'] == 0.0 ? 0.0 : 0.4,
              'kids': desiredPercentages['kids'],
              'space7': desiredPercentages['kids'] == 0.0 ? 0.0 : 0.4,
              'family': desiredPercentages['family'],
              'space8': desiredPercentages['family'] == 0.0 ? 0.0 : 0.4,
              'romance': desiredPercentages['romance'],
              'space9': desiredPercentages['romance'] == 0.0 ? 0.0 : 0.4,
              'friends': desiredPercentages['friends'],
              'space10': desiredPercentages['friends'] == 0.0 ? 0.0 : 0.4,
              'spirituality': desiredPercentages['spirituality'],
              'space11': desiredPercentages['spirituality'] == 0.0 ? 0.0 : 0.4,
              'self_love': desiredPercentages['self_love'],
              'space12': desiredPercentages['self_love'] == 0.0 ? 0.0 : 0.4,
            });

        desiredPercentagesForProgressbar = {
          'nutrition': desiredPercentages['nutrition'],
          'exercise': desiredPercentages['exercise'],
          'occupation': desiredPercentages['occupation'],
          'wealth': desiredPercentages['wealth'],
          'creation': desiredPercentages['creation'],
          'recreation': desiredPercentages['recreation'],
          'kids': desiredPercentages['kids'],
          'family': desiredPercentages['family'],
          'romance': desiredPercentages['romance'],
          'friends': desiredPercentages['friends'],
          'spirituality': desiredPercentages['spirituality'],
          'self_love': desiredPercentages['self_love'],
        };

        currentUser = user;

        notifyListeners();

        return true;
      }
    } on DioError catch (e) {
      if (e.message == 'Http status error [404]') {
        throw false;
      }
    }

    return false;
  }

  //This function will make user to logout from the application
  Future<void> logoutUser() async {
    final header = await createHeader();

    final prefs = await SharedPreferences.getInstance();

    final loginMethod = prefs.getString('login-through');

    print('Log Out From Method');
    print(loginMethod);

    final signInMethod = currentUser.signInMethod;

    try {
      if (loginMethod == 'google') {
        const String clientIdForIOS =
            "721097966591-2821ndn7ind2u2ga549b3enu5d6fn4re.apps.googleusercontent.com";
        GoogleSignIn googleSignIn;

        if (Platform.isAndroid) {
          googleSignIn = GoogleSignIn();
        } else {
          googleSignIn = GoogleSignIn(clientId: clientIdForIOS);
        }

        await googleSignIn.signOut();

        currentUser = UserModel.emptyUser();

        await prefs.setString('loginTimeToken', '');

        await dio.post(
          '${HelpingMethods.baseURL}/get/logout',
          options: Options(
            contentType: 'application/json',
            headers: header,
          ),
        );
      } else if (loginMethod == 'facebook') {
        await FacebookAuth.instance.logOut();

        currentUser = UserModel.emptyUser();

        await prefs.setString('loginTimeToken', '');

        await dio.post(
          '${HelpingMethods.baseURL}/get/logout',
          options: Options(
            contentType: 'application/json',
            headers: header,
          ),
        );
      } else if (loginMethod == 'apple') {
        currentUser = UserModel.emptyUser();

        await prefs.setString('loginTimeToken', '');

        await dio.post(
          '${HelpingMethods.baseURL}/get/logout',
          options: Options(
            contentType: 'application/json',
            headers: header,
          ),
        );
      } else {
        currentUser = UserModel.emptyUser();

        await prefs.setString('loginTimeToken', '');

        await dio.post(
          '${HelpingMethods.baseURL}/get/logout',
          options: Options(
            contentType: 'application/json',
            headers: header,
          ),
        );
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.message!;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  //This function will delete user account permanently from Db
  Future<dynamic> deleteUserAccount(
      [String? username, String? password]) async {
    final prefs = await SharedPreferences.getInstance();

    final loggedInStatus = prefs.getString('login-through');

    if (loggedInStatus == 'email-pass') {
      try {
        final headers = await createHeader();

        final response = await dio.delete(
          '${HelpingMethods.baseURL}/update/deleteAccount',
          data: json.encode({
            "user_id": currentUser.userId,
            "user_name": username,
            "user_password": password,
            "logged_in_status": 0
          }),
          options: Options(contentType: 'application/json', headers: headers),
        );

        if (response.statusCode == 200) {
          final responseData = response.data;
          final status = responseData['status'];
          final message = responseData['message'];
          if (status) {
            return message;
          }
        }
      } on DioError catch (e) {
        if (e.response != null) {
          throw e.response!.data;
        }
      } catch (e) {
        throw e.toString();
      }
    } else {
      try {
        final headers = await createHeader();

        final response = await dio.delete(
          '${HelpingMethods.baseURL}/update/deleteAccount',
          data: json
              .encode({"user_id": currentUser.userId, "logged_in_status": 1}),
          options: Options(contentType: 'application/json', headers: headers),
        );

        if (response.statusCode == 200) {
          final responseData = response.data;
          final status = responseData['status'];
          final message = responseData['message'];
          if (status) {
            return message;
          }
        }
      } on DioError catch (e) {
        if (e.response != null) {
          throw e.response!.data;
        }
      } catch (e) {
        throw e.toString();
      }
    }
  }

  //This function will reset user's activities for the selected year
  Future<dynamic> resetUserReportsData(
      String year, ActivityProvider activityProvider) async {
    int intYear = int.tryParse(year)!;

    try {
      final headers = await createHeader();

      final startingYearDate = "$year-01-01";

      final nextYear = intYear + 1;

      final endingYearDate = "$nextYear-01-01";

      final newActualPercentages = {
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

      final response = await dio.delete(
        '${HelpingMethods.baseURL}/reports/resetReport',
        data: json.encode({
          "user_id": currentUser.userId,
          "year": year,
          "starting_year": startingYearDate,
          "ending_year": endingYearDate,
          "actual_percentages": json.encode(newActualPercentages)
        }),
        options: Options(contentType: 'application/json', headers: headers),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        final status = responseData['status'];
        final message = responseData['message'];

        if (status) {
          int intYear = int.tryParse(year)!;

          final currentYearReport = activityProvider.listOfReports
              .firstWhere((report) => report['Year'] == intYear);
          print(currentYearReport);
          final indexOfCurrentYearReport =
              activityProvider.listOfReports.indexOf(currentYearReport);
          currentYearReport['actualPercentages'] = newActualPercentages;
          activityProvider.listOfReports.removeAt(indexOfCurrentYearReport);
          activityProvider.listOfReports
              .insert(indexOfCurrentYearReport, currentYearReport);
          final headers = await createHeader();

          try {
            final response = await dio.patch(
                '${HelpingMethods.baseURL}/reports/updateReports',
                options: Options(
                  contentType: 'application/json',
                  headers: headers,
                ),
                data: json.encode({
                  'userId': currentUser.userId,
                  'reports': json.encode(activityProvider.listOfReports)
                }));

            if (response.statusCode == 200) {
              return message;
            }
          } on DioError catch (e) {
            if (e.response != null) {
              throw e.response!;
            }
          }
        }
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!.data;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  //This function will check if user's name is already exists in DB
  Future<dynamic> checkUserNameExists(String userName) async {
    try {
      final response = await dio.post(
          '${HelpingMethods.baseURL}/check/checkIfUserNameExists',
          options: Options(
            contentType: 'application/json',
            headers: {"Access-Control-Allow-Origin": "*"},
          ),
          data: json.encode({'userName': userName}));

      if (response.data == 'true') {
        return true;
      } else if (response.data == 'false') {
        return false;
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.message!;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  //This function will set or update user's desired percentages
  Future<void> setUserDesiredPercentages(
      Map<String, double> map, String userId) async {
    final newMap = {
      'nutrition': map['nutrition']!,
      'space1': map['nutrition'] == 0.0 ? 0.0 : 0.4,
      'exercise': map['exercise']!,
      'space2': map['exercise'] == 0.0 ? 0.0 : 0.4,
      'occupation': map['occupation']!,
      'space3': map['occupation'] == 0.0 ? 0.0 : 0.4,
      'wealth': map['wealth']!,
      'space4': map['wealth'] == 0.0 ? 0.0 : 0.4,
      'creation': map['creation']!,
      'space5': map['creation'] == 0.0 ? 0.0 : 0.4,
      'recreation': map['recreation']!,
      'space6': map['recreation'] == 0.0 ? 0.0 : 0.4,
      'kids': map['kids']!,
      'space7': map['kids'] == 0.0 ? 0.0 : 0.4,
      'family': map['family']!,
      'space8': map['family'] == 0.0 ? 0.0 : 0.4,
      'romance': map['romance']!,
      'space9': map['romance'] == 0.0 ? 0.0 : 0.4,
      'friends': map['friends']!,
      'space10': map['friends'] == 0.0 ? 0.0 : 0.4,
      'spirituality': map['spirituality']!,
      'space11': map['spirituality'] == 0.0 ? 0.0 : 0.4,
      'self_love': map['self_love']!,
      'space12': map['self_love'] == 0.0 ? 0.0 : 0.4,
    };

    currentUser.mapOfDesiredPercentages = newMap;

    notifyListeners();
    final headers = await createHeader();
    final desiredPercentages = {'userDesiredPercentages': json.encode(map)};

    try {
      final response = await dio.patch(
          '${HelpingMethods.baseURL}/update/updateUserDesiredPercentages',
          options: Options(contentType: 'application/json', headers: headers),
          data: json.encode(desiredPercentages));

      if (response.statusCode == 200) {
        final response = await dio.get(
            '${HelpingMethods.baseURL}/reports/getReports',
            options:
                Options(contentType: 'application/json', headers: headers));

        final reportsData = json.decode(response.data['reports']) ?? [];
        final currentYear = DateTime.now().year;

        final currentYearReport =
            reportsData.firstWhere((report) => report['Year'] == currentYear);
        final indexOfCurrentYearReport = reportsData.indexOf(currentYearReport);

        currentYearReport['desiredPercentages'] = map;

        reportsData.removeAt(indexOfCurrentYearReport);

        reportsData.insert(indexOfCurrentYearReport, currentYearReport);

        await dio.patch(
            '${HelpingMethods.baseURL}/reports/updateReports',
            options: Options(contentType: 'application/json', headers: headers),
            data: json.encode(
                {'userId': userId, 'reports': json.encode(reportsData)}));
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }
  }

  //This function will set or update user's details
  Future<dynamic> setUserDetails(Map<String, String?> map) async {
    final headers = await createHeader();
    currentUser.userFirstName = map['firstName'];
    currentUser.userLastName = map['lastName'];
    currentUser.userPhoneNumber = map['phoneNumber'];
    currentUser.userBirthday = map['birthDay'];
    final userDetails = {
      'user_firstname': map['firstName'],
      'user_lastname': map['lastName'],
      'user_phonenumber': map['phoneNumber'],
      'user_birthday': map['birthDay'],
    };

    notifyListeners();

    try {
      final response = await dio.post(
          '${HelpingMethods.baseURL}/update/updateUserDetails',
          options: Options(
            contentType: 'application/json',
            headers: headers,
          ),
          data: json.encode(userDetails));

      if (response.statusCode == 200) {
        return response.data;
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }
  }

  //This function will upload user's image
  Future<void> uploadUserImage(File image, UserProvider userProvider) async {
    final headers = await createHeader();

    try {
      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(image.path),
      });

      final response = await dio.post(
          '${HelpingMethods.baseURL}/updateProfile/updateProfileImage',
          options: Options(headers: headers),
          data: formData,
          queryParameters: {
            'userId': userProvider.getCurrentUser.userId,
          });

      if (response.statusCode == 200) {
        final response = await dio.get(
            '${HelpingMethods.baseURL}/get/getUserImage',
            options: Options(headers: headers),
            queryParameters: {
              'userId': userProvider.getCurrentUser.userId,
            });

        final userImagePath = response.data['user_image'];

        final splittedPath = userImagePath.split('/');

        final fileName = splittedPath[2];

        final url = "${HelpingMethods.baseURL}/$fileName";

        currentUser.userImage = '';
        notifyListeners();

        await Future.delayed(const Duration(seconds: 1));

        currentUser.userImage = url;
        notifyListeners();
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw e.response!;
      }
    }
  }

  //This function will check if the user is already logged in the device
  Future<dynamic> checkIfUserPresent() async {
    final prefs = await SharedPreferences.getInstance();

    final isUserPresent = prefs.getString('loginTimeToken') ?? '';

    if (isUserPresent != '') {
      final response = await fetchUserData();
      return response;
    }

    return false;
  }

  //Variable for the progress bar for enter desired percentages screen
  double totalForProgressBar = 0.0;

  //This function will get the desired percentages total for the progress bar
  void getDesiredPercentagesTotalForProgressbar() {
    double total = 0.0;
    desiredPercentagesForProgressbar.forEach((key, value) {
      total += value;
    });
    total /= 100;

    totalForProgressBar = total;
  }

  //This function will change the desired percentages total for progress bar
  void changeDesiredPercentagesTotalForProgressbar(
      double newValue, String category) {
    String finalCat = '';

    category = category.toLowerCase().split(' ')[0];
    if (category == 'self-love') {
      finalCat = 'self_love';
    } else {
      finalCat = category;
    }

    if (desiredPercentagesForProgressbar.containsKey(finalCat)) {
      WidgetsFlutterBinding.ensureInitialized()
          .addPostFrameCallback((timeStamp) {
        desiredPercentagesForProgressbar.update(finalCat, (value) => newValue);
        getDesiredPercentagesTotalForProgressbar();
        notifyListeners();
      });
    }
  }

  //This function will change the desired percentages back to original
  void changeDesiredPercentagesBackToOriginal() {
    desiredPercentagesForProgressbar = {
      'nutrition': currentUser.mapOfDesiredPercentages['nutrition']!,
      'exercise': currentUser.mapOfDesiredPercentages['exercise']!,
      'occupation': currentUser.mapOfDesiredPercentages['occupation']!,
      'wealth': currentUser.mapOfDesiredPercentages['wealth']!,
      'creation': currentUser.mapOfDesiredPercentages['creation']!,
      'recreation': currentUser.mapOfDesiredPercentages['recreation']!,
      'kids': currentUser.mapOfDesiredPercentages['kids']!,
      'family': currentUser.mapOfDesiredPercentages['family']!,
      'romance': currentUser.mapOfDesiredPercentages['romance']!,
      'friends': currentUser.mapOfDesiredPercentages['friends']!,
      'spirituality': currentUser.mapOfDesiredPercentages['spirituality']!,
      'self_love': currentUser.mapOfDesiredPercentages['self_love']!,
    };
    getDesiredPercentagesTotalForProgressbar();
    notifyListeners();
  }
}
