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
