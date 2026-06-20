import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
}

/// Handles FCM push notifications and device token management.
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  FirebaseMessaging? _messaging;
  String? _currentToken;

  SupabaseClient get _supabase => Supabase.instance.client;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  bool get _isDesktop => _isMacOS ||
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) ||
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux);

  /// Initialize Firebase and request notification permissions.
  Future<void> initialize() async {
    try {
      _messaging = FirebaseMessaging.instance;

      // Set up background message handler for mobile
      if (_isAndroid || _isIOS) {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      }
    } catch (e) {
      debugPrint('Firebase Messaging initialization failed: $e');
      return;
    }

    // Request permission (required for iOS, macOS, and web)
    try {
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _setupToken();
        _setupTokenRefresh();
        _setupForegroundHandler();
        _setupNotificationTapHandler();
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  /// Get and save the FCM token.
  Future<void> _setupToken() async {
    debugPrint('_setupToken called - Platform: ${kIsWeb ? "web" : defaultTargetPlatform.toString()}');

    // Check if Firebase Messaging is initialized
    if (_messaging == null) {
      debugPrint('Firebase Messaging not initialized - trying to initialize...');
      try {
        _messaging = FirebaseMessaging.instance;
      } catch (e) {
        debugPrint('Firebase Messaging initialization failed: $e');
        return;
      }
    }

    try {
      // For iOS/macOS, get APNS token first
      if (_isIOS || _isMacOS) {
        debugPrint('Apple platform detected, getting APNS token...');
        final apnsToken = await _messaging!.getAPNSToken();
        debugPrint('APNS token: ${apnsToken != null ? "received" : "null"}');
        if (apnsToken == null) {
          debugPrint('APNS token not available yet - FCM will not work');
          // Retry after a delay on Apple platforms
          Future.delayed(const Duration(seconds: 2), () async {
            final retryToken = await _messaging!.getAPNSToken();
            if (retryToken != null) {
              debugPrint('APNS token received on retry');
              await _getAndSaveFCMToken();
            }
          });
          return;
        }
      }

      await _getAndSaveFCMToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _getAndSaveFCMToken() async {
    debugPrint('Getting FCM token...');

    try {
      // For web, we need to pass the VAPID key
      if (kIsWeb) {
        // You'll need to add your VAPID key from Firebase Console
        // Project Settings > Cloud Messaging > Web Push certificates
        _currentToken = await _messaging!.getToken(
          vapidKey: 'YOUR_VAPID_KEY_HERE', // Replace with actual VAPID key
        );
      } else {
        _currentToken = await _messaging!.getToken();
      }

      debugPrint('FCM Token: ${_currentToken != null ? "received (${_currentToken!.length} chars)" : "null"}');

      if (_currentToken != null) {
        await _saveTokenToSupabase(_currentToken!);
      } else {
        debugPrint('FCM token is null!');
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  /// Listen for token refresh.
  void _setupTokenRefresh() {
    _messaging?.onTokenRefresh.listen((newToken) async {
      _currentToken = newToken;
      await _saveTokenToSupabase(newToken);
    });
  }

  /// Handle foreground messages.
  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message: ${message.notification?.title}');
      debugPrint('Message data: ${message.data}');
      // The in-app notification system will handle display
    });
  }

  /// Handle notification taps (when user taps on a notification)
  void _setupNotificationTapHandler() {
    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification tapped (background): ${message.notification?.title}');
      _handleNotificationTap(message);
    });

    // Check if app was opened from a notification (when app was terminated)
    _messaging?.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('App opened from notification (terminated): ${message.notification?.title}');
        _handleNotificationTap(message);
      }
    });
  }

  /// Handle the notification tap action
  void _handleNotificationTap(RemoteMessage message) {
    // You can navigate to specific screens based on message.data
    final type = message.data['type'];
    final taskId = message.data['task_id'];
    debugPrint('Notification type: $type, taskId: $taskId');
    // Add navigation logic here if needed
  }

  /// Save FCM token to Supabase for the current user.
  Future<void> _saveTokenToSupabase(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    debugPrint('Attempting to save FCM token. User ID: $userId');
    if (userId == null) {
      debugPrint('Cannot save FCM token: user not logged in');
      return;
    }

    // Determine platform
    String platform;
    if (kIsWeb) {
      platform = 'web';
    } else if (_isIOS) {
      platform = 'ios';
    } else if (_isAndroid) {
      platform = 'android';
    } else if (_isMacOS) {
      platform = 'macos';
    } else {
      platform = 'unknown';
    }

    try {
      debugPrint('Saving token to device_tokens table (platform: $platform)...');
      await _supabase.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, token');

      debugPrint('FCM token saved to Supabase successfully!');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Call this when user logs in to ensure token is saved.
  Future<void> onUserLogin() async {
    debugPrint('onUserLogin called. Current token: ${_currentToken != null ? "exists" : "null"}');
    if (_currentToken != null) {
      await _saveTokenToSupabase(_currentToken!);
    } else {
      debugPrint('No token cached, calling _setupToken...');
      await _setupToken();
    }
  }

  /// Call this when user logs out to remove token.
  Future<void> onUserLogout() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || _currentToken == null) return;

    try {
      await _supabase
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', _currentToken!);
      debugPrint('FCM token removed from Supabase');
      _currentToken = null;
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }
  }

  /// Get the current FCM token (for debugging)
  String? get currentToken => _currentToken;
}
