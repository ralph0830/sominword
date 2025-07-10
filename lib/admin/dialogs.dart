import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // Clipboard 사용을 위한 추가

export 'dialogs.dart' show showEditWordInputDialog, showDeleteWordConfirmDialog, showTsvExportDialog;

// showEditNicknameDialog: 입력값만 반환, Firestore 등 비동기 작업은 State에서 처리
Future<String?> showEditNicknameDialog(BuildContext context, String currentNickname) {
  final controller = TextEditingController(text: currentNickname);
  return showDialog<String>(
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
          onPressed: () {
            final newNickname = controller.text.trim();
            Navigator.pop(ctx, newNickname);
          },
          child: const Text('저장'),
        ),
      ],
    ),
  );
}

Future<Map<String, dynamic>?> showDeviceRequestDialog(BuildContext context) async {
  final deviceIdController = TextEditingController();
  final deviceNameController = TextEditingController();
  return await showDialog<Map<String, dynamic>>(
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

            // Add this check
            if (!ctx.mounted) return;

            Navigator.pop(ctx, {
              'exists': deviceDoc.exists,
              'alreadyRegistered': deviceDoc.data()?['ownerEmail'] != null && (deviceDoc.data()?['ownerEmail'] as String).isNotEmpty,
              'deviceName': deviceDoc.data()?['deviceName'] ?? 'Unknown Device',
              'deviceId': deviceId,
            });
          },
          child: const Text('신청'),
        ),
      ],
    ),
  );
}

/// 단어 입력 다이얼로그: 입력값만 반환, Firestore 작업은 State에서 처리
Future<Map<String, String>?> showEditWordInputDialog(BuildContext context, {Map<String, dynamic>? word}) async {
  final engController = TextEditingController(text: word?['englishWord'] ?? '');
  final posController = TextEditingController(text: word?['koreanPartOfSpeech'] ?? '');
  final korController = TextEditingController(text: word?['koreanMeaning'] ?? '');
  final sentenceController = TextEditingController(text: word?['sentence'] ?? '');
  final sentenceKorController = TextEditingController(text: word?['sentenceKor'] ?? '');
  return await showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(word == null ? '단어 추가' : '단어 수정'),
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
          TextField(
            controller: sentenceController,
            decoration: const InputDecoration(labelText: '예문'),
          ),
          TextField(
            controller: sentenceKorController,
            decoration: const InputDecoration(labelText: '예문 해석'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            final eng = engController.text.trim();
            final pos = posController.text.trim();
            final kor = korController.text.trim();
            final sentence = sentenceController.text.trim();
            final sentenceKor = sentenceKorController.text.trim();
            if (eng.isEmpty || pos.isEmpty || kor.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('모든 필드를 입력해주세요.')),
              );
              return;
            }
            Navigator.pop(ctx, {
              'englishWord': eng,
              'koreanPartOfSpeech': pos,
              'koreanMeaning': kor,
              'sentence': sentence,
              'sentenceKor': sentenceKor,
            });
          },
          child: Text(word == null ? '추가' : '수정'),
        ),
      ],
    ),
  );
}

/// 단어 삭제 확인 다이얼로그: 삭제 여부만 반환, Firestore 작업은 State에서 처리
Future<bool> showDeleteWordConfirmDialog(BuildContext context, String englishWord) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('단어 삭제'),
      content: Text('"$englishWord" 단어를 삭제하시겠습니까?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('삭제', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  return result == true;
}

/// TSV 추출 다이얼로그: TSV 문자열만 받아서 보여줌, Firestore 작업은 State에서 처리
Future<void> showTsvExportDialog(BuildContext context, String deviceName, String tsv) async {
  final controller = TextEditingController(text: tsv);
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('[$deviceName] 단어 TSV 추출'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('아래 내용을 복사해서 TSV 파일로 저장하세요.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 12,
              minLines: 6,
              readOnly: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('닫기'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('복사'),
          onPressed: () {
            Navigator.pop(ctx, 'copied');
          },
        ),
      ],
    ),
  ).then((result) async {
    // Add this check
    if (!context.mounted) return;

    if (result == 'copied') {
      await Clipboard.setData(ClipboardData(text: tsv));
      // UI 갱신(알림 등)은 State에서 처리
    }
  });
}