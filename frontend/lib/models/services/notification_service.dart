import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Singleton service for handling local notifications
///
/// Usage Examples:
///
/// // Initialize (call once in main.dart)
/// await NotificationService().initialize();
///
/// // Show a basic notification
/// await NotificationService().showNotification(
///   id: 1,
///   title: 'RV Alert',
///   body: 'Temperature is too high!',
/// );
///
/// // Show a scheduled notification
/// await NotificationService().showScheduledNotification(
///   id: 2,
///   title: 'Maintenance Reminder',
///   body: 'Time to check RV fluids',
///   scheduledDate: DateTime.now().add(Duration(hours: 24)),
/// );
///
/// // Show a periodic notification
/// await NotificationService().showPeriodicNotification(
///   id: 3,
///   title: 'Daily Check',
///   body: 'Don\'t forget to check your RV systems',
///   repeatInterval: RepeatInterval.daily,
/// );
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  /// Call this once in main.dart or app initialization
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestProvisionalPermission: false,
      requestCriticalPermission: false,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
    );

    // macOS initialization settings (if needed)
    const DarwinInitializationSettings macOSInitializationSettings =
        DarwinInitializationSettings();

    // Combine initialization settings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
      macOS: macOSInitializationSettings,
    );

    // Initialize the plugin
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );

    _isInitialized = true;

    if (kDebugMode) {
      print('NotificationService: Initialized successfully');
    }
  }

  /// Handle notification tap when app is in foreground
  void _onDidReceiveNotificationResponse(NotificationResponse notificationResponse) {
    if (kDebugMode) {
      print('Notification tapped: ${notificationResponse.payload}');
    }
    // Handle notification tap - you can add navigation logic here
  }

  /// Handle notification tap when app is in background
  @pragma('vm:entry-point')
  static void onDidReceiveBackgroundNotificationResponse(NotificationResponse notificationResponse) {
    if (kDebugMode) {
      print('Background notification tapped: ${notificationResponse.payload}');
    }
    // Handle background notification tap
  }

  /// Show a basic notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationDetails? notificationDetails,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Default notification details for Android
    final androidDetails = AndroidNotificationDetails(
      'rv_channel_id',
      'RV Notifications',
      channelDescription: 'Notifications for RV control system',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    // Default notification details for iOS
    const iosDetails = DarwinNotificationDetails();

    final details = notificationDetails ??
        NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );

    if (kDebugMode) {
      print('NotificationService: Showed notification - $title: $body');
    }
  }

  /// Show a scheduled notification
  Future<void> showScheduledNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    NotificationDetails? notificationDetails,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Default notification details for Android
    final androidDetails = AndroidNotificationDetails(
      'rv_scheduled_channel_id',
      'RV Scheduled Notifications',
      channelDescription: 'Scheduled notifications for RV system',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    // Default notification details for iOS
    const iosDetails = DarwinNotificationDetails();

    final details = notificationDetails ??
        NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );

    if (kDebugMode) {
      print('NotificationService: Scheduled notification for ${scheduledDate.toString()}');
    }
  }

  /// Show a periodic notification
  Future<void> showPeriodicNotification({
    required int id,
    required String title,
    required String body,
    required RepeatInterval repeatInterval,
    String? payload,
    NotificationDetails? notificationDetails,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Default notification details for Android
    final androidDetails = AndroidNotificationDetails(
      'rv_periodic_channel_id',
      'RV Periodic Notifications',
      channelDescription: 'Periodic notifications for RV system',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    // Default notification details for iOS
    const iosDetails = DarwinNotificationDetails();

    final details = notificationDetails ??
        NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

    await _flutterLocalNotificationsPlugin.periodicallyShow(
      id,
      title,
      body,
      repeatInterval,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );

    if (kDebugMode) {
      print('NotificationService: Set up periodic notification');
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
    if (kDebugMode) {
      print('NotificationService: Cancelled notification with id: $id');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    if (kDebugMode) {
      print('NotificationService: Cancelled all notifications');
    }
  }

  /// Get pending notification requests
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  /// Get active (currently shown) notifications
  Future<List<ActiveNotification>> getActiveNotifications() async {
    return await _flutterLocalNotificationsPlugin.getActiveNotifications();
  }
  Future<bool> areNotificationsEnabled() async {
    return await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled() ??
        true; // Assume enabled on other platforms
  }

  /// Request notification permissions (iOS only)
  Future<bool> requestPermissions() async {
    final iosPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      final result = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: false,
        provisional: false,
      );
      return result ?? false;
    }

    return true; // Permissions not needed on Android
  }

  /// Create notification channel (Android only)
  Future<void> createNotificationChannel({
    required String id,
    required String name,
    String? description,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
  }) async {
    final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final channel = AndroidNotificationChannel(
        id,
        name,
        description: description,
        importance: importance,
      );

      await androidPlugin.createNotificationChannel(channel);
    }
  }
}
