// 다이얼로그 함수들 전체 복사 및 export
// ... (위에서 추출한 함수 전체) ...

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> showEditNicknameDialog(BuildContext context, String deviceId, String currentNickname) async {
  final controller = TextEditingController(text: currentNickname);
  await showDialog(
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

Future<void> showDeviceRequestDialog(BuildContext context, String email) async {
  final deviceIdController = TextEditingController();
  final deviceNameController = TextEditingController();
  await showDialog(
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
            final deviceDoc = await FirebaseFirestore.instance.collection('devices').doc(deviceId).get();
            if (!ctx.mounted) return;
            if (!deviceDoc.exists) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('등록된 고유 번호가 아닙니다. 앱을 기기에서 최소 1회 실행해주세요.')),
                );
              }
              return;
            }
            final data = deviceDoc.data();
            if (data?['ownerEmail'] != null && (data?['ownerEmail'] as String).isNotEmpty) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('이미 등록된 번호입니다.')),
                );
              }
              return;
            }
            final deviceName = data?['deviceName'] ?? 'Unknown Device';
            await FirebaseFirestore.instance.collection('pendingDevices').add({
              'deviceId': deviceId,
              'deviceName': deviceName,
              'ownerEmail': email,
              'requestedAt': FieldValue.serverTimestamp(),
            });
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('기기 추가 신청이 완료되었습니다. 슈퍼 관리자의 승인을 기다려주세요.')),
            );
          },
          child: const Text('신청'),
        ),
      ],
    ),
  );
}

Future<void> showCopyWordsDialog(BuildContext context, String fromDeviceId, String fromDeviceName, String email) async {
  final devicesSnapshot = await FirebaseFirestore.instance
      .collection('devices')
      .where('ownerEmail', isEqualTo: email)
      .get();
  final devices = devicesSnapshot.docs.where((doc) => doc.id != fromDeviceId).toList();
  if (devices.isEmpty) {
    await showDialog(
      context: context,
      builder: (ctx) => const AlertDialog(
        title: Text('단어 복사'),
        content: Text('복사할 대상 기기가 없습니다.'),
      ),
    );
    return;
  }
  String? selectedDeviceId;
  String? selectedDeviceName;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('다른 기기로 단어 복사'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('[$fromDeviceName]의 단어를 복사할 기기를 선택하세요.'),
            const SizedBox(height: 16),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedDeviceId,
              hint: const Text('대상 기기 선택'),
              items: devices.map((doc) {
                final data = doc.data();
                final name = data['deviceName'] ?? doc.id;
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text('$name (${doc.id})'),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  selectedDeviceId = val;
                  selectedDeviceName = devices.firstWhere((d) => d.id == val).data()['deviceName'] ?? val;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: selectedDeviceId == null
                ? null
                : () async {
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    await copyWordsToDevice(context, fromDeviceId, selectedDeviceId!, fromDeviceName, selectedDeviceName ?? selectedDeviceId!);
                  },
            child: const Text('복사'),
          ),
        ],
      ),
    ),
  );
}

Future<void> copyWordsToDevice(BuildContext context, String fromDeviceId, String toDeviceId, String fromDeviceName, String toDeviceName) async {
  final firestore = FirebaseFirestore.instance;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const AlertDialog(
      title: Text('단어 복사 중...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('단어를 복사하고 있습니다.'),
        ],
      ),
    ),
  );
  try {
    final fromWordsSnap = await firestore.collection('devices/$fromDeviceId/words').get();
    if (fromWordsSnap.docs.isEmpty) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('복사할 단어가 없습니다.')),
        );
      }
      return;
    }
    final toWordsSnap = await firestore.collection('devices/$toDeviceId/words').get();
    final toWords = toWordsSnap.docs.map((d) => d.data()['englishWord'] as String?).toSet();
    int copied = 0;
    final batch = firestore.batch();
    for (final doc in fromWordsSnap.docs) {
      final data = doc.data();
      final eng = data['englishWord'] ?? data['eng'] ?? '';
      if (eng.isEmpty || toWords.contains(eng)) continue;
      final newDoc = firestore.collection('devices/$toDeviceId/words').doc();
      batch.set(newDoc, data);
      copied++;
    }
    await batch.commit();
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('[$fromDeviceName]의 단어 $copied개가 [$toDeviceName]로 복사되었습니다.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('복사 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

Future<void> showEditDialog(BuildContext context, {required String deviceId, String? wordId, Map<String, dynamic>? word}) async {
  final engController = TextEditingController(text: word?['englishWord'] ?? '');
  final posController = TextEditingController(text: word?['koreanPartOfSpeech'] ?? '');
  final korController = TextEditingController(text: word?['koreanMeaning'] ?? '');
  final isEdit = wordId != null;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isEdit ? '단어 수정' : '단어 추가'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: engController,
            decoration: const InputDecoration(labelText: '영어 단어'),
          ),
          TextField(
            controller: posController,
            decoration: const InputDecoration(labelText: '품사'),
          ),
          TextField(
            controller: korController,
            decoration: const InputDecoration(labelText: '한글 뜻'),
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
            final eng = engController.text.trim();
            final pos = posController.text.trim();
            final kor = korController.text.trim();
            if (eng.isEmpty || pos.isEmpty || kor.isEmpty) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('모든 필드를 입력해주세요.')),
                );
              }
              return;
            }
            final wordsPath = 'devices/$deviceId/words';
            if (isEdit) {
              await FirebaseFirestore.instance.collection(wordsPath).doc(wordId).update({
                'englishWord': eng,
                'koreanPartOfSpeech': pos,
                'koreanMeaning': kor,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } else {
              await FirebaseFirestore.instance.collection(wordsPath).add({
                'englishWord': eng,
                'koreanPartOfSpeech': pos,
                'koreanMeaning': kor,
                'inputTimestamp': FieldValue.serverTimestamp(),
                'isFavorite': false,
              });
            }
            if (ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text(isEdit ? '단어가 수정되었습니다.' : '단어가 추가되었습니다.')),
              );
            }
          },
          child: Text(isEdit ? '수정' : '추가'),
        ),
      ],
    ),
  );
}

Future<void> showDeleteDialog(BuildContext context, {required String deviceId, required String wordId}) async {
  final wordDoc = await FirebaseFirestore.instance.collection('devices/$deviceId/words').doc(wordId).get();
  final englishWord = wordDoc.data()?['englishWord'] ?? '';
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('단어 삭제'),
      content: Text('"$englishWord" 단어를 삭제하시겠습니까?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () async {
            await FirebaseFirestore.instance.collection('devices/$deviceId/words').doc(wordId).delete();
            if (ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('단어가 삭제되었습니다.')),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('삭제', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
