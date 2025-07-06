import 'package:flutter/material.dart';
import '../utils.dart';

class DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  final String deviceId;
  final String deviceName;
  final String nickname;
  final dynamic lastActive;
  final bool isSuperAdmin;
  final String? email;
  final VoidCallback? onEditNickname;
  final VoidCallback? onCopyWords;
  final VoidCallback? onTap;

  const DeviceCard({
    super.key,
    required this.device,
    required this.deviceId,
    required this.deviceName,
    required this.nickname,
    required this.lastActive,
    required this.isSuperAdmin,
    this.email,
    this.onEditNickname,
    this.onCopyWords,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.phone_android, size: 32),
        title: Row(
          children: [
            Expanded(child: Text(deviceName)),
            if (nickname.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text('닉네임: $nickname', style: const TextStyle(color: Colors.deepPurple)),
              ),
            if (onEditNickname != null)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                tooltip: '닉네임 수정',
                onPressed: onEditNickname,
              ),
            if (!isSuperAdmin && email != null && onCopyWords != null)
              IconButton(
                icon: const Icon(Icons.copy, size: 20, color: Colors.deepPurple),
                tooltip: '다른 기기로 단어 복사',
                onPressed: onCopyWords,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    'ID: $deviceId',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  ),
                ),
                if (isSuperAdmin && onCopyWords != null)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: Colors.deepPurple),
                    tooltip: '다른 기기로 단어 복사',
                    onPressed: onCopyWords,
                  ),
              ],
            ),
            if (lastActive != null)
              Text('마지막 활동: ${formatRelativeDate(lastActive)}'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
} 