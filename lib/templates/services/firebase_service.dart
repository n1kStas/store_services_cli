import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
// ignore: depend_on_referenced_packages
import 'package:advertising_id/advertising_id.dart';
import '../store_interfaces.dart';

class FirebaseAnalyticsImpl implements StoreAnalytics {
  final _analytics = FirebaseAnalytics.instance;

  String? _appInstanceId;

  @override
  String? get appInstanceId => _appInstanceId;

  @override
  Future<void> init() async {
    _appInstanceId = await _getAppInstanceId();
  }

  Future<String?> _getAppInstanceId() async {
    try {
      final id = await _analytics.appInstanceId;
      return id;
    } catch (e) {
      return null;
    }
  }
}

class FirebasePushImpl implements StorePush {
  PushNotification? _initialMessage;

  @override
  PushNotification? get initialMessage => _initialMessage;

  final _onMessageReceived = StreamController<PushNotification>.broadcast();

  @override
  Stream<PushNotification> get onMessageReceived => _onMessageReceived.stream;

  @override
  PushNotificationStatus get permissionStatus => _permissionStatus;

  @override
  Stream<PushNotificationStatus> get permissionStatusReceived =>
      _permissionStatusReceived.stream;

  @override
  String? get token => _token;

  final _messaging = FirebaseMessaging.instance;

  String? _token;

  /// Завершается значением токена (или null) после фонового дофетча в [init].
  final Completer<String?> _tokenReady = Completer<String?>();

  @override
  Future<String?> get tokenReady => _tokenReady.future;

  PushNotificationStatus _permissionStatus =
      PushNotificationStatus.notDetermined;

  final _permissionStatusReceived =
      StreamController<PushNotificationStatus>.broadcast();

  @override
  Future<void> init() async {
    _permissionStatusReceived.add(PushNotificationStatus.notDetermined);
    // Слушатели и initial message ставим сразу — это локально, без сети.
    await _initInitialMessage();
    _handleOnMessageReceived();
    _handleOnMessageOpenedApp();
    // FCM-токен дофетчиваем в фоне: getToken на заблокированном эндпоинте (РФ)
    // может висеть ~30с. Не блокируем инициализацию; готовность — через
    // [tokenReady].
    unawaited(_initToken());
  }

  Future<void> _initToken() async {
    _token = await _getToken();
    if (!_tokenReady.isCompleted) {
      _tokenReady.complete(_token);
    }
  }

  Future<String?> _getToken() async {
    try {
      final token = await _messaging.getToken();
      return token;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<PushNotificationStatus> get checkPermissionStatus async {
    final settings = await _messaging.getNotificationSettings();
    final status = settings.authorizationStatus;
    switch (status) {
      case AuthorizationStatus.authorized:
        _permissionStatus = PushNotificationStatus.authorized;
        break;
      case AuthorizationStatus.provisional:
        _permissionStatus = PushNotificationStatus.provisional;
        break;
      case AuthorizationStatus.denied:
        _permissionStatus = PushNotificationStatus.denied;
        break;
      case AuthorizationStatus.notDetermined:
        _permissionStatus = PushNotificationStatus.notDetermined;
        break;
    }
    _permissionStatusReceived.add(_permissionStatus);
    return _permissionStatus;
  }

  @override
  Future<PushNotificationStatus> requestPermission() async {
    await _messaging.requestPermission();
    return await checkPermissionStatus;
  }

  Future<void> _initInitialMessage() async {
    try {
      final message = await _messaging.getInitialMessage();
      if (message == null) return;
      _initialMessage = _parseMessage(message);
    } catch (e) {
      _initialMessage = null;
    }
  }

  Future<void> _handleOnMessageReceived() async {
    FirebaseMessaging.onMessage.listen((message) {
      final notification = _parseMessage(message);
      _onMessageReceived.add(notification);
    });
  }

  Future<void> _handleOnMessageOpenedApp() async {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final notification = _parseMessage(message);
      _onMessageReceived.add(notification);
    });
  }

  PushNotification _parseMessage(RemoteMessage message) {
    String? imageUrl;
    if (Platform.isAndroid) {
      imageUrl = message.notification?.android?.imageUrl;
    } else if (Platform.isIOS) {
      imageUrl = message.notification?.apple?.imageUrl;
    }
    return PushNotification(
      title: message.notification?.title,
      body: message.notification?.body,
      imageUrl: imageUrl,
      messageId: message.messageId,
      data: message.data,
    );
  }
}

class FirebaseAdsImpl implements StoreAds {
  String? _advertisingId;

  @override
  final String advertisingType = 'GAID';

  @override
  String? get advertisingId => _advertisingId;

  @override
  Future<void> init() async {
    _advertisingId = await _getAdvertisingId();
  }

  Future<String?> _getAdvertisingId() async {
    try {
      final id = await AdvertisingId.id(true);
      return id;
    } catch (e) {
      return null;
    }
  }
}

class FirebaseRemoteConfigImpl implements StoreRemoteConfig {
  final FirebaseRemoteConfig _config = FirebaseRemoteConfig.instance;

  final _settings = RemoteConfigSettings(
    fetchTimeout: Duration.zero,
    minimumFetchInterval: Duration.zero,
  );

  @override
  Future<void> fetchAndActivate() async {
    await _config.setConfigSettings(_settings);
    await _config.fetchAndActivate();
  }

  @override
  String getString(String key) => _config.getString(key);

  @override
  bool getBool(String key) => _config.getBool(key);

  @override
  int getInt(String key) => _config.getInt(key);

  @override
  double getDouble(String key) => _config.getDouble(key);

  @override
  Map<String, dynamic> getAll() => _config.getAll();
}

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  late final StoreAnalytics analytics;
  late final StorePush push;
  late final StoreAds ads;
  late final StoreRemoteConfig remoteConfig;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      print('🔥 FirebaseService initialized');

      analytics = FirebaseAnalyticsImpl();
      push = FirebasePushImpl();
      ads = FirebaseAdsImpl();
      remoteConfig = FirebaseRemoteConfigImpl();

      await analytics.init();
      await ads.init();
      await push.init();
      // Remote Config фетчим в фоне: сетевой вызов Google-эндпоинта в РФ может
      // висеть/падать по таймауту. Не блокируем инициализацию — значение
      // подхватится, когда (и если) фетч завершится.
      unawaited(remoteConfig.fetchAndActivate().catchError((Object e) {
        print('🔥 RemoteConfig fetch failed (background): $e');
      }));

      print('🔥 Firebase Adapters initialized');
    } catch (e) {
      print('🔥 FirebaseService init error: $e');
    }
  }
}
