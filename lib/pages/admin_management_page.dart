import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminManagementPage extends StatelessWidget {
  const AdminManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 승인 관리'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('account').where('isApproved', isEqualTo: false).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류: \\${snapshot.error}'));
          }
          final admins = snapshot.data?.docs ?? [];
          if (admins.isEmpty) {
            return const Center(child: Text('승인 대기 중인 관리자가 없습니다.'));
          }
          return ListView.builder(
            itemCount: admins.length,
            itemBuilder: (context, index) {
              final admin = admins[index].data() as Map<String, dynamic>;
              final email = admins[index].id;
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(email),
                subtitle: Text('기기: \\${admin['deviceName'] ?? 'Unknown'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('account').doc(email).update({
                          'isApproved': true,
                          'approvedAt': FieldValue.serverTimestamp(),
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('관리자 승인 완료: $email')),
                          );
                        }
                      },
                      tooltip: '승인',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('account').doc(email).delete();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('관리자 신청 거절: $email')),
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