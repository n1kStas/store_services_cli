// GENERATED FILE - Contains embedded templates for global installation support
// This file allows the CLI to work when installed globally via `dart pub global activate`

const String storeInterfacesTemplate = r'''
abstract class StoreAnalytics {
  String? get appInstanceId;

  Future<void> init();
}

abstract class StorePush {
  Future<void> init();
  Future<PushNotificationStatus> requestPermission();
  String? get token;

  /// Завершается, когда фоновый дофетч FCM-токена закончился — значением токена
  /// или null. Потребителям, которым нужен реальный токен (например, генерация
  /// affsub), можно дождаться этого Future, не блокируя инициализацию.
  Future<String?> get tokenReady;
  Future<PushNotificationStatus> get checkPermissionStatus;
  PushNotification? get initialMessage;
  Stream<PushNotification> get onMessageReceived;
  Stream<PushNotificationStatus> get permissionStatusReceived;
  PushNotificationStatus get permissionStatus;
}

abstract class StoreAds {
  String get advertisingType;
  String? get advertisingId;

  Future<void> init();
}

abstract class StoreRemoteConfig {
  Future<void> fetchAndActivate();
  String getString(String key);
  bool getBool(String key);
  int getInt(String key);
  double getDouble(String key);
  Map<String, dynamic> getAll();
}

enum PushNotificationStatus { authorized, denied, notDetermined, provisional }

class PushNotification {
  const PushNotification({
    this.title,
    this.body,
    this.imageUrl,
    this.messageId,
    this.data,
  });

  final String? title;
  final String? body;
  final String? imageUrl;
  final String? messageId;
  final Map<String, dynamic>? data;

  factory PushNotification.fromJson(Map<String, dynamic> json) {
    return PushNotification(
      title: json['title'],
      body: json['body'],
      imageUrl: json['imageUrl'],
      messageId: json['messageId'],
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'messageId': messageId,
      'data': data,
    };
  }
}
''';

const String storeServiceGmsTemplate = r'''
import 'services/firebase_service.dart';
import 'store_interfaces.dart';

export 'store_interfaces.dart';

class StoreService {
  static final StoreService _instance = StoreService._internal();

  factory StoreService() {
    return _instance;
  }

  StoreService._internal();

  // Public Interfaces
  late final StoreAnalytics analytics;
  late final StorePush push;
  late final StoreAds ads;
  late final StoreRemoteConfig remoteConfig;

  bool _adaptersAssigned = false;

  Future<void> init() async {
    // 1. Init Firebase (and adapters internally)
    final service = FirebaseService();
    await service.init();

    // 2. Assign adapters from service
    if (!_adaptersAssigned) {
      analytics = service.analytics;
      push = service.push;
      ads = service.ads;
      remoteConfig = service.remoteConfig;
      _adaptersAssigned = true;
    }

    print('✅ StoreService (GMS) fully initialized');
  }
}
''';

const String storeServiceHmsTemplate = r'''
import 'services/hms_service.dart';
import 'store_interfaces.dart';

export 'store_interfaces.dart';

class StoreService {
  static final StoreService _instance = StoreService._internal();

  factory StoreService() {
    return _instance;
  }

  StoreService._internal();

  // Public Interfaces
  late final StoreAnalytics analytics;
  late final StorePush push;
  late final StoreAds ads;
  late final StoreRemoteConfig remoteConfig;

  bool _adaptersAssigned = false;

  Future<void> init() async {
    // 1. Init HMS (and adapters internally)
    final service = HmsService();
    await service.init();

    // 2. Assign adapters
    if (!_adaptersAssigned) {
      analytics = service.analytics;
      push = service.push;
      ads = service.ads;
      remoteConfig = service.remoteConfig;
      _adaptersAssigned = true;
    }

    print('✅ StoreService (HMS) fully initialized');
  }
}
''';

const String storeServiceHybridTemplate = r'''
import 'package:huawei_hmsavailability/huawei_hmsavailability.dart';
import 'services/firebase_service.dart';
import 'services/hms_service.dart';
import 'store_interfaces.dart';

export 'store_interfaces.dart';

class StoreService {
  static final StoreService _instance = StoreService._internal();

  factory StoreService() {
    return _instance;
  }

  StoreService._internal();

  // Public Interfaces
  late final StoreAnalytics analytics;
  late final StorePush push;
  late final StoreAds ads;
  late final StoreRemoteConfig remoteConfig;

  bool _isHms = false;
  bool _adaptersAssigned = false;

  Future<void> init() async {
    // Check HMS Availability
    try {
      final hmsApi = HmsApiAvailability();
      final result = await hmsApi.isHMSAvailable();
      // 0 means SUCCESS (HMS Available)
      _isHms = result == 0;
      print('🔍 HMS Available: $_isHms (Code: $result)');
    } catch (e) {
      print('⚠️ HmsApiAvailability check failed: $e');
      _isHms = false;
    }

    if (_isHms) {
      final service = HmsService();
      await service.init();

      if (!_adaptersAssigned) {
        analytics = service.analytics;
        push = service.push;
        ads = service.ads;
        remoteConfig = service.remoteConfig;
        _adaptersAssigned = true;
      }

      print('✅ StoreService initialized in HMS Mode');
    } else {
      final service = FirebaseService();
      await service.init();

      if (!_adaptersAssigned) {
        analytics = service.analytics;
        push = service.push;
        ads = service.ads;
        remoteConfig = service.remoteConfig;
        _adaptersAssigned = true;
      }

      print('✅ StoreService initialized in GMS Mode');
    }
  }
}
''';

const String firebaseServiceTemplate = r'''
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

  bool _adaptersCreated = false;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      print('🔥 FirebaseService initialized');

      if (!_adaptersCreated) {
        analytics = FirebaseAnalyticsImpl();
        push = FirebasePushImpl();
        ads = FirebaseAdsImpl();
        remoteConfig = FirebaseRemoteConfigImpl();
        _adaptersCreated = true;
      }

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
''';

const String hmsServiceTemplate = r'''
import 'dart:async';

import 'package:huawei_ads/huawei_ads.dart';
import 'package:huawei_push/huawei_push.dart';
import 'package:permission_handler/permission_handler.dart';

import '../store_interfaces.dart';

class HmsAnalyticsImpl implements StoreAnalytics {
  String? _appInstanceId;

  @override
  String? get appInstanceId => _appInstanceId;

  @override
  Future<void> init() async {
    _appInstanceId = await _getAppInstanceId();
  }

  Future<String?> _getAppInstanceId() async {
    await Future.delayed(const Duration(seconds: 1));
    return null;
  }
}

class HmsPushImpl implements StorePush {
  String? _token;

  /// Завершается значением токена (или null) после фонового дофетча в [init].
  final Completer<String?> _tokenReady = Completer<String?>();

  @override
  String? get token => _token;

  @override
  Future<String?> get tokenReady => _tokenReady.future;

  PushNotificationStatus _permissionStatus =
      PushNotificationStatus.notDetermined;

  @override
  PushNotificationStatus get permissionStatus => _permissionStatus;

  final _permissionStatusReceived =
      StreamController<PushNotificationStatus>.broadcast();

  @override
  Stream<PushNotificationStatus> get permissionStatusReceived =>
      _permissionStatusReceived.stream;

  @override
  Future<PushNotificationStatus> get checkPermissionStatus async {
    final status = await Permission.notification.status;
    switch (status) {
      case PermissionStatus.granted:
        _permissionStatus = PushNotificationStatus.authorized;
        break;
      case PermissionStatus.denied:
        _permissionStatus = PushNotificationStatus.denied;
        break;
      case PermissionStatus.permanentlyDenied:
        _permissionStatus = PushNotificationStatus.denied;
        break;
      case PermissionStatus.restricted:
        _permissionStatus = PushNotificationStatus.denied;
        break;
      case PermissionStatus.limited:
        _permissionStatus = PushNotificationStatus.denied;
        break;
      case PermissionStatus.provisional:
        _permissionStatus = PushNotificationStatus.denied;
        break;
    }
    _permissionStatusReceived.add(_permissionStatus);
    return _permissionStatus;
  }

  PushNotification? _initialMessage;

  @override
  PushNotification? get initialMessage => _initialMessage;

  final _onMessageReceived = StreamController<PushNotification>.broadcast();

  @override
  Stream<PushNotification> get onMessageReceived => _onMessageReceived.stream;

  @override
  Future<void> init() async {
    await _getToken();
    await _initInitialMessage();
    _handleOnMessageReceived();
    _handleOnMessageOpenedApp();
  }

  Future<void> _getToken() async {
    Push.getToken('');
    Push.getTokenStream.listen(
      (token) {
        _token = token;
        if (!_tokenReady.isCompleted) {
          _tokenReady.complete(_token);
        }
      },
      onError: (error) {
        _token = null;
        if (!_tokenReady.isCompleted) {
          _tokenReady.complete(null);
        }
      },
    );
  }

  @override
  Future<PushNotificationStatus> requestPermission() async {
    await Permission.notification.request();
    return checkPermissionStatus;
  }

  Future<void> _initInitialMessage() async {
    final message = await Push.getInitialNotification();
    if (message != null) {
      _initialMessage = _parsePushNotification(message);
    }
  }

  PushNotification _parsePushNotification(Map<Object?, Object?> message) {
    final extras = message['extras'] as Map<Object?, Object?>;
    return PushNotification(
      title: extras['title'] as String?,
      body: extras['body'] as String?,
      imageUrl: extras['image'] as String?,
      data: {'link': extras['link'] as String?},
      messageId: extras['_push_msgid'] as String?,
    );
  }

  void _handleOnMessageReceived() {
    Push.onMessageReceivedStream.listen(
      (message) {
        _onMessageReceived.add(_parsePushNotification(message.toMap()));
      },
      onError: (error) {
        _onMessageReceived.addError(error);
      },
    );
  }

  void _handleOnMessageOpenedApp() {
    Push.onNotificationOpenedApp.listen(
      (message) {
        _onMessageReceived.add(_parsePushNotification(message.toMap()));
      },
      onError: (error) {
        _onMessageReceived.addError(error);
      },
    );
  }
}

class HmsAdsImpl implements StoreAds {
  String? _advertisingId;

  @override
  final String advertisingType = 'OAID';

  @override
  String? get advertisingId => _advertisingId;

  Future<String?> _getAdvertisingId() async {
    try {
      final client = await AdvertisingIdClient.getAdvertisingIdInfo();
      return client.getId;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> init() async {
    _advertisingId = await _getAdvertisingId();
  }
}

class HmsRemoteConfigImpl implements StoreRemoteConfig {
  @override
  Future<void> fetchAndActivate() async {
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  String getString(String key) => '';

  @override
  bool getBool(String key) => false;

  @override
  int getInt(String key) => 0;

  @override
  double getDouble(String key) => 0.0;

  @override
  Map<String, dynamic> getAll() => {};
}

class HmsService {
  static final HmsService _instance = HmsService._internal();

  factory HmsService() {
    return _instance;
  }

  HmsService._internal();

  late final StoreAnalytics analytics;
  late final StorePush push;
  late final StoreAds ads;
  late final StoreRemoteConfig remoteConfig;

  bool _adaptersCreated = false;

  Future<void> init() async {
    print('🔴 HmsService initialized');

    if (!_adaptersCreated) {
      analytics = HmsAnalyticsImpl();
      push = HmsPushImpl();
      ads = HmsAdsImpl();
      remoteConfig = HmsRemoteConfigImpl();
      _adaptersCreated = true;
    }

    await analytics.init();
    await ads.init();
    await push.init();
    await remoteConfig.fetchAndActivate();

    print('🔴 Hms Adapters initialized');
  }
}
''';
