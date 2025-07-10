import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class DeviceIdService {
  static const String _deviceIdKey = 'device_id';
  static const String _deviceNameKey = 'device_name';
  
  static final DeviceIdService _instance = DeviceIdService._internal();
  factory DeviceIdService() => _instance;
  DeviceIdService._internal();

  String? _cachedDeviceId;
  String? _cachedDeviceName;

  /// 기기 ID를 가져오거나 생성합니다.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null) {
      final deviceInfo = DeviceInfoPlugin();
      
      try {
        if (kIsWeb) {
          // 웹 환경에서는 UUID 생성
          deviceId = const Uuid().v4();
        } else {
          // 모바일 환경에서만 Platform 체크
          if (defaultTargetPlatform == TargetPlatform.android) {
            final androidInfo = await deviceInfo.androidInfo;
            deviceId = androidInfo.id;
          } else if (defaultTargetPlatform == TargetPlatform.iOS) {
            final iosInfo = await deviceInfo.iosInfo;
            deviceId = iosInfo.identifierForVendor;
          } else {
            // 기타 플랫폼에서는 UUID 생성
            deviceId = const Uuid().v4();
          }
        }
      } catch (e) {
        // 예외 발생 시 UUID 생성
        deviceId = const Uuid().v4();
      }
      
      await prefs.setString(_deviceIdKey, deviceId!);
    }
    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// 기기 이름을 가져오거나 생성합니다.
  Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) {
      return _cachedDeviceName!;
    }

    final prefs = await SharedPreferences.getInstance();
    String? deviceName = prefs.getString(_deviceNameKey);
    
    if (deviceName == null) {
      deviceName = _generateDefaultDeviceName();
      await prefs.setString(_deviceNameKey, deviceName);
    }
    _cachedDeviceName = deviceName;
    return deviceName;
  }

  /// 기기 이름을 업데이트합니다.
  Future<void> updateDeviceName(String newName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceNameKey, newName);
    _cachedDeviceName = newName;
  }

  /// 기본 기기 이름을 생성합니다.
  String _generateDefaultDeviceName() {
    if (kIsWeb) {
      return 'Web Browser';
    }
    
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  /// 캐시를 초기화합니다.
  void clearCache() {
    _cachedDeviceId = null;
    _cachedDeviceName = null;
  }
} 