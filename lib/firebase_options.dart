import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
    apiKey: 'AIzaSyBS-3lZ713ckznBzwIHip0pd3YXvxGnJEQ',
    authDomain: 'smartpatch-medical.firebaseapp.com',
    databaseURL: 'https://smartpatch-medical-default-rtdb.firebaseio.com',
    projectId: 'smartpatch-medical',
    storageBucket: 'smartpatch-medical.firebasestorage.app',
    messagingSenderId: '272526395006',
    appId: '1:272526395006:web:85ec1f810346c0b28e7a2f',
  );
}
