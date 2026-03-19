import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'notification_helper.dart';

class OngoingRideNotificationService {
  static const String channelId = 'ongoing_ride_channel';
  static const String channelName = 'Ongoing Ride Updates';
  static const int notificationId = 888;

  static Future<void> initialize() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    
    await NotificationHelper.initialize(channelId, channelName);

    // Initial setup for the background service
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: channelId,
        initialNotificationTitle: 'SaaradhiGo Ride',
        initialNotificationContent: 'Connecting...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Listen for state updates to refresh the notification
    service.on('update').listen((event) async {
      if (service is AndroidServiceInstance) {
        if (event != null) {
          final title = event['title'] as String?;
          final content = event['content'] as String?;
          
          if (title != null && content != null) {
            await NotificationHelper.showNotification(
              notificationId,
              title,
              content,
              channelId,
              channelName,
            );
          }
        }
      }
    });
  }

  static Future<void> startService() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  static void stopService() {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  static void updateNotification({required String title, required String content}) {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    
    final service = FlutterBackgroundService();
    service.invoke('update', {
      'title': title,
      'content': content,
    });
  }
}
