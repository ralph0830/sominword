import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../admin/widgets/device_card.dart';
import 'admin_management_page.dart';
import 'device_approval_status_page.dart';
import 'word_admin_page.dart';

class DeviceListPage extends StatefulWidget {
  final bool isSuperAdmin;
  final String? email;
  const DeviceListPage({super.key, required this.isSuperAdmin, this.email});

  @override
  State<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends State<DeviceListPage> {
  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = widget.isSuperAdmin;
    final email = widget.email;
    return Scaffold(
      appBar: AppBar(
        title: const Text('기기별 단어 관리'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (isSuperAdmin)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('pendingDevices').snapshots(),
              builder: (context, pendingSnapshot) {
                final pendingCount = pendingSnapshot.data?.docs.length ?? 0;
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('account').where('isApproved', isEqualTo: false).snapshots(),
                  builder: (context, adminSnapshot) {
                    final adminCount = adminSnapshot.data?.docs.length ?? 0;
                    final totalCount = pendingCount + adminCount;
                    return Row(
                      children: [
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.admin_panel_settings),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AdminManagementPage()),
                                );
                              },
                              tooltip: '관리자 승인 관리',
                            ),
                            if (totalCount > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$totalCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.verified_user),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const DeviceApprovalStatusPage()),
                            );
                          },
                          tooltip: '기기별 승인 현황',
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: '로그아웃',
          ),
        ],
      ),
      floatingActionButton: !isSuperAdmin && email != null
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('기기 추가 신청'),
              onPressed: () => _showDeviceRequestDialog(context, email),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: isSuperAdmin
            ? FirebaseFirestore.instance
                .collection('devices')
                .orderBy('lastActiveAt', descending: true)
                .snapshots()
            : (email != null
                ? FirebaseFirestore.instance
                    .collection('devices')
                    .where('ownerEmail', isEqualTo: email)
                    .snapshots()
                : const Stream.empty()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          final devices = snapshot.data?.docs ?? [];
          if (devices.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.devices, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('등록된 기기가 없습니다.', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  Text('앱을 실행하면 기기가 등록됩니다.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index].data() as Map<String, dynamic>;
              final deviceId = devices[index].id;
              final deviceName = device['deviceName'] ?? 'Unknown Device';
              final nickname = device['nickname'] ?? '';
              final lastActive = device['lastActiveAt'] as Timestamp?;
              return DeviceCard(
                device: device,
                deviceId: deviceId,
                deviceName: deviceName,
                nickname: nickname,
                lastActive: lastActive?.toDate(),
                isSuperAdmin: isSuperAdmin,
                email: email,
                onEditNickname: () {
                  _showEditNicknameDialog(context, deviceId, nickname);
                },
                onCopyWords: null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WordAdminPage(
                        deviceId: deviceId,
                        deviceName: deviceName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showEditNicknameDialog(BuildContext context, String deviceId, String currentNickname) {
    final controller = TextEditingController(text: currentNickname);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기기 닉네임 수정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '닉네임',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newNickname = controller.text.trim();
              await FirebaseFirestore.instance.collection('devices').doc(deviceId).update({'nickname': newNickname});
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showDeviceRequestDialog(BuildContext context, String email) {
    final deviceIdController = TextEditingController();
    final deviceNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기기 추가 신청'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: deviceIdController,
              decoration: const InputDecoration(
                labelText: '기기 고유번호',
                border: OutlineInputBorder(),
                hintText: '앱에서 확인한 기기 고유번호를 입력하세요',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: deviceNameController,
              decoration: const InputDecoration(
                labelText: '기기 이름',
                border: OutlineInputBorder(),
                hintText: '예: android, Web Browser 등',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final deviceId = deviceIdController.text.trim();
              // Firestore 작업: context 사용하지 않음
              final deviceDoc = await FirebaseFirestore.instance.collection('devices').doc(deviceId).get();
              final data = deviceDoc.data();
              final deviceExists = deviceDoc.exists;
              final alreadyRegistered = data?['ownerEmail'] != null && (data?['ownerEmail'] as String).isNotEmpty;
              final deviceName = data?['deviceName'] ?? 'Unknown Device';
              String? errorMsg;
              bool success = false;
              if (!deviceExists) {
                errorMsg = '등록된 고유 번호가 아닙니다. 앱을 기기에서 최소 1회 실행해주세요.';
              } else if (alreadyRegistered) {
                errorMsg = '이미 등록된 번호입니다.';
              } else {
                await FirebaseFirestore.instance.collection('pendingDevices').add({
                  'deviceId': deviceId,
                  'deviceName': deviceName,
                  'ownerEmail': email,
                  'requestedAt': FieldValue.serverTimestamp(),
                });
                success = true;
              }
              // UI 처리: context 사용은 async gap 이후, mounted 체크
              if (!ctx.mounted) return;
              if (success) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('기기 추가 신청이 완료되었습니다. 슈퍼 관리자의 승인을 기다려주세요.')),
                );
              } else if (errorMsg != null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(errorMsg)),
                );
              }
            },
            child: const Text('신청'),
          ),
        ],
      ),
    );
  }
} 