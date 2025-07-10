// 공통 기기 모델 (앱/관리자 공용)

class Device {
  final String id;
  final String name;
  final String? ownerEmail;
  final String? nickname;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;

  Device({
    required this.id,
    required this.name,
    this.ownerEmail,
    this.nickname,
    this.createdAt,
    this.lastActiveAt,
  });
} 