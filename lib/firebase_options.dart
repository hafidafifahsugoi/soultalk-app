// File generated for SoulTalk AI Firebase integration.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opsi konfigurasi default Firebase untuk SoulTalk AI.
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
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB3E9AOApYpeptCsI4QduVc0AEOeIOWpEA',
    appId: '1:927314681728:android:3536588bb0133e6d442b65',
    messagingSenderId: '927314681728',
    projectId: 'soultalk-ai-1c8cd',
    storageBucket: 'soultalk-ai-1c8cd.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB3E9AOApYpeptCsI4QduVc0AEOeIOWpEA',
    appId: '1:927314681728:android:3536588bb0133e6d442b65',
    messagingSenderId: '927314681728',
    projectId: 'soultalk-ai-1c8cd',
    storageBucket: 'soultalk-ai-1c8cd.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB3E9AOApYpeptCsI4QduVc0AEOeIOWpEA',
    appId: '1:927314681728:android:3536588bb0133e6d442b65',
    messagingSenderId: '927314681728',
    projectId: 'soultalk-ai-1c8cd',
    storageBucket: 'soultalk-ai-1c8cd.firebasestorage.app',
  );
}
