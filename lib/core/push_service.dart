import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'supabase.dart';

/// Notifiche push con Firebase Cloud Messaging.
///
/// La configurazione arriva da `--dart-define-from-file` (chiavi FIREBASE_*
/// in env/dev.json). Se manca, il push resta disattivato e l'app continua
/// a funzionare con le notifiche in-app.
class PushService {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  // Chiave VAPID (Cloud Messaging > Certificati push web), solo per il web
  static const _vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  static bool get isConfigured =>
      _apiKey.isNotEmpty && _appId.isNotEmpty && _senderId.isNotEmpty && _projectId.isNotEmpty;

  static bool _initialized = false;
  static String? _token;
  static StreamSubscription<String>? _refreshSub;
  static final _foreground = StreamController<RemoteMessage>.broadcast();

  /// Messaggi ricevuti con l'app aperta (il sistema non li mostra da solo).
  static Stream<RemoteMessage> get onForegroundMessage => _foreground.stream;

  static Future<void> init() async {
    if (!isConfigured || _initialized) return;
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
          authDomain: _authDomain.isEmpty ? null : _authDomain,
          storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
        ),
      );
      FirebaseMessaging.onMessage.listen(_foreground.add);
      _initialized = true;
    } catch (e) {
      debugPrint('Push non disponibile: $e');
    }
  }

  /// Chiede il permesso e registra il token del dispositivo per l'utente
  /// loggato in `device_tokens`. Da chiamare dopo il login.
  static Future<void> registerDevice() async {
    if (!_initialized || supabase.auth.currentUser == null) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken(vapidKey: kIsWeb && _vapidKey.isNotEmpty ? _vapidKey : null);
      if (token != null) await _saveToken(token);

      await _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen(_saveToken);
    } catch (e) {
      debugPrint('Registrazione push non riuscita: $e');
    }
  }

  /// Rimuove il token del dispositivo: da chiamare prima del logout, finché
  /// la sessione è ancora valida (RLS: solo i propri token).
  static Future<void> unregisterDevice() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    final token = _token;
    if (!_initialized || token == null) return;
    try {
      await supabase.from('device_tokens').delete().eq('token', token);
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Rimozione token push non riuscita: $e');
    }
    _token = null;
  }

  static Future<void> _saveToken(String token) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    // Il token può essere già associato a questo utente: si sostituisce
    await supabase.from('device_tokens').delete().eq('token', token);
    await supabase.from('device_tokens').insert({'user_id': uid, 'token': token, 'platform': _platform});
    _token = token;
  }

  static String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 'ios',
      _ => 'android',
    };
  }
}
