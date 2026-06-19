import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles FCM push notifications and device token management.
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  FirebaseMessaging? _messaging;
  String? _currentToken;

  SupabaseClient get _supabase => Supabase.instance.client;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool get _isMobile => _isIOS || _isAndroid;

  /// Initialize Firebase and request notification permissions.
  Future<void> initialize() async {
    // Skip on web - push notifications require different setup
    if (kIsWeb) {
      debugPrint('Push notifications not supported on web');
      return;
    }

    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
      return;
    }

    // Request permission (required for iOS)
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
    }
  }

  /// Get and save the FCM token.
  Future<void> _setupToken() async {
    // Skip on web
    if (kIsWeb) return;

    debugPrint('_setupToken called');

    // Check if Firebase Messaging is initialized
    if (_messaging == null) {
      debugPrint('Firebase Messaging not initialized - trying to initialize...');
      try {
        await Firebase.initializeApp();
        _messaging = FirebaseMessaging.instance;
      } catch (e) {
        debugPrint('Firebase initialization failed: $e');
        return;
      }
    }

    try {
      // For iOS, get APNS token first
      if (_isIOS) {
        debugPrint('iOS detected, getting APNS token...');
        final apnsToken = await _messaging!.getAPNSToken();
        debugPrint('APNS token: ${apnsToken != null ? "received" : "null"}');
        if (apnsToken == null) {
          debugPrint('APNS token not available yet - FCM will not work');
          return;
        }
      }

      debugPrint('Getting FCM token...');
      _currentToken = await _messaging!.getToken();
      debugPrint('FCM Token: $_currentToken');

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
      // The in-app notification system will handle display
    });
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
    String platform = 'unknown';
    if (_isIOS) {
      platform = 'ios';
    } else if (_isAndroid) {
      platform = 'android';
    }

    try {
      debugPrint('Saving token to device_tokens table...');
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
    // Skip on web
    if (kIsWeb) return;

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
    // Skip on web
    if (kIsWeb) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || _currentToken == null) return;

    try {
      await _supabase
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', _currentToken!);
      debugPrint('FCM token removed from Supabase');
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }
  }
}
