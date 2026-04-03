// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        ); // Use default app icon

    // iOS initialization (requesting permissions)
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    // Initialize the plugin
    await _notificationsPlugin.initialize(
      initializationSettings,
      // onDidReceiveNotificationResponse: onDidReceiveNotificationResponse, // Optional callback for tap
    );
  }

  static Future<bool> requestPermissionIfNeeded() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return true;

    final granted = await androidPlugin.requestNotificationsPermission();
    return granted ?? false;
  }

  static Future<void> _requestAndroidPermissions() async {
    // Request permission for Android 13+
    final bool? granted = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission(); // Use requestNotificationsPermission for newer versions
    print("Android Notification Permission Granted: $granted");
  }

  // Helper to show a notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload, // Optional data to pass when notification is tapped
  }) async {
    // --- DEFINE BigTextStyle ---
    final BigTextStyleInformation bigTextStyleInformation =
        BigTextStyleInformation(
          body, // Use the full body text here
          htmlFormatBigText:
              true, // Set to true if body contains basic HTML like <b>
          contentTitle: title, // Repeat title in expanded view
          htmlFormatContentTitle: true,
          // summaryText: 'Attendance Alert', // Optional summary text
          // htmlFormatSummaryText: true,
        );

    // --- ANDROID NOTIFICATION DETAILS (with BigTextStyle) ---
    final AndroidNotificationDetails
    androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'attendance_alerts_channel', // Channel ID (must be unique)
      'Attendance Alerts', // Channel Name (visible in system settings)
      channelDescription:
          'Notifications for attendance status', // Channel Description
      importance: Importance.high, // High importance for alerts
      priority: Priority.high, // High priority
      styleInformation: bigTextStyleInformation, // APPLY THE STYLE HERE
      // icon: '@mipmap/ic_notification', // Optional: Small icon for status bar (defaults to app icon)
      // largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'), // Optional: Larger icon
      // color: Colors.blue, // Optional: Accent color
      // ledColor: Colors.blue, // Optional: LED color
      // ledOnMs: 1000,
      // ledOffMs: 500,
    );

    // --- iOS NOTIFICATION DETAILS (No BigTextStyle needed) ---
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          // sound: 'default', // Optional sound
        );

    // --- COMBINE DETAILS ---
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // --- SHOW NOTIFICATION ---
    await _notificationsPlugin.show(
      id,
      title,
      body, // The regular body (truncated view)
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Optional callbacks if you need to handle taps or foreground notifications
  // static void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
  //   // Handle notification tap
  //   final String? payload = notificationResponse.payload;
  //   if (payload != null) {
  //     debugPrint('notification payload: $payload');
  //   }
  //   // Navigate or perform action based on payload
  // }

  // static void onDidReceiveLocalNotification(
  //   int id, String? title, String? body, String? payload) async {
  //   // Handle foreground notification display on older iOS versions
  // }
}
