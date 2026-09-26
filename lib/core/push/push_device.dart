import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Android notification channel reminders appear in.
///
/// **It must be the channel the backend addresses (`push.ChannelID`) and the
/// one the manifest names as FCM's default.** A message to a channel the phone
/// does not have arrives and is never shown, with no error anywhere.
const reminderChannelId = 'lembretes';

const _channel = AndroidNotificationChannel(
  reminderChannelId,
  'Lembretes',
  // Only the description carries accents: the id above must match the server.
  description: 'Manutenção, IPVA, licenciamento e seguro, quando vencem.',
  importance: Importance.high,
);

/// The mark's white silhouette (tool/notification_icon.dart): Android keeps
/// only the alpha of a notification icon, and a colour icon turns into a white
/// square.
const _smallIcon = '@drawable/ic_notification';

/// AppColors.signalDeep — the manifest's `notification_accent` on a light
/// shade. A message drawn by the app while open uses it too.
const _accent = Color(0xFF1A66DA);

final pushDeviceProvider = Provider<PushDevice>((ref) {
  return FirebasePushDevice(FlutterLocalNotificationsPlugin());
});

/// Called with the app in the background or closed.
///
/// **It draws nothing**: a message carrying a `notification` is drawn by
/// Android itself. It exists because the plugin requires a handler.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// This phone's side of push: permission, channel, token and the taps.
///
/// It knows nothing about cars or screens — [PushCoordinator] turns a tap into
/// a place in the app, and [PushRegistration] tells the server where to send.
/// Everything here **fails in silence**: without google-services.json, without
/// Google Play services, or on the web, the app is whole; it only is not
/// reminded.
abstract interface class PushDevice {
  /// Android only: iOS needs an APNs key and a build this project cannot make
  /// yet, and the web would need a service worker.
  bool get isSupported;

  /// Whether [init] got Firebase up. False until then, and for good on a
  /// build without google-services.json.
  bool get isReady;

  /// Starts Firebase and creates the channel. Called once, at sign-in.
  /// **Asks for no permission** — see [requestPermission].
  Future<void> init();

  /// The `data` of every reminder tapped: drawn by Android with the app
  /// closed or in the background, or drawn by the app while it was open.
  Stream<Map<String, String>> get onTap;

  /// The reminder that opened the app from closed, if one did.
  Future<Map<String, String>?> initialTap();

  /// Android 13+'s question. Asked after Início has shown the car, never on
  /// first boot: someone who has not seen what the app does cannot decide
  /// whether to be reminded, and a "no" there is expensive — Android asks
  /// again once at most.
  Future<bool> requestPermission();

  /// Whether Android lets the app show notifications at all.
  Future<bool> hasPermission();

  /// This installation's token, or null when there is no push. It exists
  /// without the permission, which governs showing, not delivering — so the
  /// phone is registered at sign-in, not after the question.
  Future<String?> currentToken();

  /// FCM replaces the token on its own (reinstall, restored backup, cleared
  /// data). Without listening, the phone stops receiving in silence.
  Stream<String> get onTokenRefresh;

  /// Retires this installation's token at FCM, so a server that still holds
  /// it gets "unregistered" and forgets it.
  Future<void> deleteToken();
}

final class FirebasePushDevice implements PushDevice {
  FirebasePushDevice(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<Map<String, String>>.broadcast();

  FirebaseMessaging? _messaging;
  Future<void>? _initializing;

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  bool get isReady => _messaging != null;

  @override
  Stream<Map<String, String>> get onTap => _taps.stream;

  @override
  Future<void> init() {
    if (!isSupported) return Future.value();
    return _initializing ??= _init();
  }

  Future<void> _init() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_smallIcon),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          final data = _stringMap(jsonDecode(payload));
          if (data != null) _taps.add(data);
        },
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      final messaging = FirebaseMessaging.instance;

      // With the app open FCM **draws nothing**. Without this the reminder
      // vanishes exactly for whoever has the app in hand — the easiest case
      // to try, and the easiest to take for broken.
      FirebaseMessaging.onMessage.listen(_showWhileOpen);
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _taps.add(message.data.map((k, v) => MapEntry(k, '$v')));
      });

      _messaging = messaging;
    } on Object catch (error) {
      debugPrint('Push indisponível: $error');
    }
  }

  @override
  Future<Map<String, String>?> initialTap() async {
    final message = await _messaging?.getInitialMessage();
    if (message == null) return null;
    return message.data.map((k, v) => MapEntry(k, '$v'));
  }

  @override
  Future<bool> requestPermission() async {
    final messaging = _messaging;
    if (messaging == null) return false;
    try {
      return _granted(await messaging.requestPermission());
    } on Object catch (error) {
      debugPrint('Falha ao pedir permissão de notificação: $error');
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    final messaging = _messaging;
    if (messaging == null) return false;
    try {
      return _granted(await messaging.getNotificationSettings());
    } on Object {
      return false;
    }
  }

  @override
  Future<String?> currentToken() async {
    final messaging = _messaging;
    if (messaging == null) return null;
    try {
      return await messaging.getToken();
    } on Object catch (error) {
      debugPrint('Falha ao obter o token do aparelho: $error');
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh =>
      _messaging?.onTokenRefresh ?? const Stream<String>.empty();

  @override
  Future<void> deleteToken() async {
    try {
      await _messaging?.deleteToken();
    } on Object catch (error) {
      debugPrint('Falha ao descartar o token do aparelho: $error');
    }
  }

  static bool _granted(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  Future<void> _showWhileOpen(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _plugin.show(
      id: message.messageId?.hashCode ?? notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: _accent,
          // Several items are several lines: the whole body, not the first.
          styleInformation: BigTextStyleInformation(notification.body ?? ''),
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static Map<String, String>? _stringMap(Object? decoded) {
    if (decoded is! Map) return null;
    return decoded.map((k, v) => MapEntry('$k', '$v'));
  }
}
