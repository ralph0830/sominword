import 'package:flutter/material.dart';

class AdminManagementCard extends StatelessWidget {
  final Map<String, dynamic>? admin;
  final String adminId;
  final String email;
  final String deviceId;
  final String deviceName;
  final bool isApproved;
  final DateTime? requestedAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const AdminManagementCard({
    super.key,
    required this.admin,
    required this.adminId,
    required this.email,
    required this.deviceId,
    required this.deviceName,
    required this.isApproved,
    this.requestedAt,
    this.approvedAt,
    this.approvedBy,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          isApproved ? Icons.check_circle : Icons.pending,
          color: isApproved ? Colors.green : Colors.orange,
          size: 32,
        ),
        title: Text(email),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('기기: $deviceName'),
            Text('기기 ID: $deviceId'),
            if (requestedAt != null)
              Text('신청일: ${requestedAt.toString()}'),
            if (isApproved && approvedAt != null)
              Text('승인일: ${approvedAt.toString()}'),
            if (isApproved && approvedBy != null)
              Text('승인자: $approvedBy'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isApproved && onApprove != null)
              ElevatedButton(
                onPressed: onApprove,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text('승인'),
              ),
            if (!isApproved && onReject != null)
              ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onReject,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  child: const Text('거부'),
                ),
              ],
          ],
        ),
      ),
    );
  }
} 