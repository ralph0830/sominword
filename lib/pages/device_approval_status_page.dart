import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceApprovalStatusPage extends StatelessWidget {
  const DeviceApprovalStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기기별 승인 현황'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pendingDevices').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류: \\${snapshot.error}'));
          }
          final pending = snapshot.data?.docs ?? [];
          if (pending.isEmpty) {
            return const Center(child: Text('승인 대기 중인 기기가 없습니다.'));
          }
          return ListView.builder(
            itemCount: pending.length,
            itemBuilder: (context, index) {
              final device = pending[index].data() as Map<String, dynamic>;
              final deviceId = device['deviceId'] ?? '';
              final deviceName = device['deviceName'] ?? 'Unknown';
              final ownerEmail = device['ownerEmail'] ?? '';
              return ListTile(
                leading: const Icon(Icons.devices),
                title: Text('$deviceName ($deviceId)'),
                subtitle: Text('신청자: $ownerEmail'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('devices').doc(deviceId).update({
                          'ownerEmail': ownerEmail,
                        });
                        await FirebaseFirestore.instance.collection('pendingDevices').doc(pending[index].id).delete();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('기기 승인 완료: $deviceName ($deviceId)')),
                          );
                        }
                      },
                      tooltip: '승인',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('pendingDevices').doc(pending[index].id).delete();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('기기 신청 거절: $deviceName ($deviceId)')),
                          );
                        }
                      },
                      tooltip: '거절',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
} 