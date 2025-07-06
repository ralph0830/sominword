import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static const String _deviceIdKey = 'device_id';
  static const String _deviceNameKey = 'device_name';
  
  static final DeviceIdService _instance = DeviceIdService._internal();
  factory DeviceIdService() => _instance;
  DeviceIdService._internal();

  /// 기기 ID를 항상 flutter_udid로 강제 초기화하여 가져옵니다.
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId;
    if (kIsWeb) {
      deviceId = const Uuid().v4();
      debugPrint('[DeviceIdService] Web 환경, 새 UUID 생성: $deviceId');
    } else {
      try {
        deviceId = await FlutterUdid.udid;
        debugPrint('[DeviceIdService][flutter_udid] udid: $deviceId');
      } catch (e) {
        deviceId = const Uuid().v4();
        debugPrint('[DeviceIdService][flutter_udid][오류] $e, fallback UUID: $deviceId');
      }
    }
      await prefs.setString(_deviceIdKey, deviceId);
    debugPrint('[DeviceIdService] SharedPreferences에 device_id 저장(덮어씀): $deviceId');
    return deviceId;
  }

  /// 기기 이름을 반환합니다(플랫폼명+UUID 일부).
  Future<String> getDeviceName() async {
    if (kIsWeb) return 'Web';
    return defaultTargetPlatform.name;
  }

  /// 기기 이름을 업데이트합니다.
  Future<void> updateDeviceName(String newName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceNameKey, newName);
  }
} 