// File generated based on google-services.json and GoogleService-Info.plist
// This file configures Firebase for all platforms.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return android; // fallback
      case TargetPlatform.linux:
        return android; // fallback
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAqps1uA_5G1_xSIKuhhrsTiJ-1l7H5z9E',
    appId: '1:983485775721:web:a2c7f8najd8f19d',
    messagingSenderId: '983485775721',
    projectId: 'najd-8f19d',
    storageBucket: 'najd-8f19d.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAqps1uA_5G1_xSIKuhhrsTiJ-1l7H5z9E',
    appId: '1:983485775721:android:8317a3cceb3d5908a2c7f8',
    messagingSenderId: '983485775721',
    projectId: 'najd-8f19d',
    storageBucket: 'najd-8f19d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAqYwc3Ict3uwwTiQXy954-Qr7ZSVfSae0',
    appId: '1:983485775721:ios:d3815bbb33e3d4f9a2c7f8',
    messagingSenderId: '983485775721',
    projectId: 'najd-8f19d',
    storageBucket: 'najd-8f19d.firebasestorage.app',
    iosBundleId: 'com.tasneemdabash.najdvolunteer',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAqYwc3Ict3uwwTiQXy954-Qr7ZSVfSae0',
    appId: '1:983485775721:ios:d3815bbb33e3d4f9a2c7f8',
    messagingSenderId: '983485775721',
    projectId: 'najd-8f19d',
    storageBucket: 'najd-8f19d.firebasestorage.app',
    iosBundleId: 'com.tasneemdabash.najdvolunteer',
  );
}
