import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class FirebaseAppConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  static bool get isConfigured {
    if (kIsWeb) return false;
    final appId = defaultTargetPlatform == TargetPlatform.iOS
        ? iosAppId
        : androidAppId;
    return apiKey.isNotEmpty &&
        projectId.isNotEmpty &&
        senderId.isNotEmpty &&
        appId.isNotEmpty;
  }

  static FirebaseOptions get current {
    final appId = defaultTargetPlatform == TargetPlatform.iOS
        ? iosAppId
        : androidAppId;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      iosBundleId: defaultTargetPlatform == TargetPlatform.iOS
          ? 'com.technocare.technocare'
          : null,
    );
  }
}
