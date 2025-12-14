import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize notifications
  Future<void> initialize() async {
    // Initialize timezone data
    tz_data.initializeTimeZones();
    
    // Request permission for iOS
    await _requestPermission();
    
    // Initialize local notifications
    await _initializeLocalNotifications();
    
    // Handle FCM messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('Notification permission: ${settings.authorizationStatus}');
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(settings);
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');
    
    if (message.notification != null) {
      showLocalNotification(
        title: message.notification!.title ?? 'Chai Tracker',
        body: message.notification!.body ?? '',
      );
    }
  }

  // Handle when app is opened via notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened app: ${message.data}');
  }

  // Show local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'chai_tracker_channel',
      'Chai Tracker Notifications',
      channelDescription: 'Notifications for chai duty and debt requests',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Schedule chai reminders for the next 14 days with dynamic assignees
  // Note: We schedule individual notifications because the assignee changes daily
  Future<void> scheduleChaiRemindersForNextTwoWeeks({
    required int hour,
    required int minute,
    required String groupId,
    required String groupName,
    required List<String> memberOrder,
    required DateTime groupCreatedAt,
    required Function(String id) getMemberName,
  }) async {
    // Cancel existing scheduled notifications for this group
    await cancelChaiReminder(groupId);
    
    final now = DateTime.now();
    
    // Schedule for next 14 days
    for (int i = 0; i < 14; i++) {
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute).add(Duration(days: i));
      
      // If today's time has passed, skip today (start from tomorrow) effectively inside loop logic
      if (scheduledDate.isBefore(now)) {
        continue;
      }

      // Calculate assignee for this specific date
      final daysSinceCreation = scheduledDate.difference(groupCreatedAt).inDays;
      final index = daysSinceCreation.abs() % memberOrder.length;
      final assigneeId = memberOrder[index];
      final assigneeName = await getMemberName(assigneeId);
      
      const androidDetails = AndroidNotificationDetails(
        'chai_reminder_channel',
        'Chai Duty Reminders',
        channelDescription: 'Daily reminders for who brings chai',
        importance: Importance.high,
        priority: Priority.high,
      );
      
      const details = NotificationDetails(android: androidDetails);
      
      // Use unique ID for each day: groupHash + dayIndex
      final notificationId = groupId.hashCode + i;
      
      await _localNotifications.zonedSchedule(
        notificationId,
        '☕ Chai Time!',
        '$assigneeName is bringing chai today!',
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // Cancel scheduled notifications for a group
  Future<void> cancelChaiReminder(String groupId) async {
    // Cancel potential 14 notifications
    for (int i = 0; i < 14; i++) {
      await _localNotifications.cancel(groupId.hashCode + i);
    }
  }

  // Get FCM token for this device
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  // Save FCM token to Firestore for user
  Future<void> saveTokenToFirestore(String userId) async {
    final token = await getToken();
    if (token != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    }
  }

  // Show notification for debt request
  Future<void> notifyDebtRequest({
    required String fromUserName,
    required double amount,
    required String reason,
  }) async {
    await showLocalNotification(
      title: '💰 New Debt Request',
      body: '$fromUserName is requesting Rs. ${amount.toStringAsFixed(0)} for $reason',
    );
  }

  // Show notification for chai duty
  Future<void> notifyChaiDuty({
    required String groupName,
    required String assigneeName,
  }) async {
    await showLocalNotification(
      title: '☕ Chai Time!',
      body: '$assigneeName is bringing chai today in $groupName',
    );
  }
}
