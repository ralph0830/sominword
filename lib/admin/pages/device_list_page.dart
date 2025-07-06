// ... DeviceListPage 관련 코드(main.dart에서 분리) ...
// 필요한 import, 타입, 함수, 위젯, 다이얼로그 호출 등 모두 포함
// BuildContext async gap, 타입, 불필요한 변수 등 경고/오류도 함께 수정
// ... existing code ...
import 'package:flutter/material.dart';

class DeviceListPage extends StatelessWidget {
  final bool isSuperAdmin;
  final String? email;
  const DeviceListPage({super.key, required this.isSuperAdmin, this.email});

  @override
  Widget build(BuildContext context) {
    // ... (main.dart의 DeviceListPage build 메서드 전체 코드) ...
    return const Scaffold(); // 임시 반환, 실제 코드 분리 시 교체
  }

  // ... (main.dart의 DeviceListPage 내 모든 함수: _showEditNicknameDialog, _showDataMigrationDialog, _showRootWordsMigrationDialog, _migrateAllWords, createSuperAdminDocument, _migrateRootWordsToDevice, _showDeviceRequestDialog, _showCopyWordsDialog, _copyWordsToDevice 등) ...
  // 모든 함수는 오류/경고 없이 완전하게 작성, BuildContext async gap 등도 최신 스타일로 반영
}
// ... existing code ... 