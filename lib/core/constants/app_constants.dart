class AppConstants {
  AppConstants._();

  static const double defaultEarlyWarningMeters = 5000;
  static const double defaultWakeUpMeters = 2000;
  static const double defaultCriticalMeters = 500;
  static const double defaultArrivalRadiusMeters = 150;
  static const int gpsMaxAgeSeconds = 30;
  static const double gpsMaxAccuracyMeters = 50;
  static const int hysteresisReadingsRequired = 3;
  static const String channelName = 'com.wakemethere.app/tracking';
  static const String alarmChannelName = 'com.wakemethere.app/alarm';
  static const int locationUpdateIntervalMs = 5000;
}
