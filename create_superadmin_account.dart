import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;

  const email = 'ralph0830@gmail.com';

  await firestore.collection('account').doc(email).set({
    'email': email,
    'isSuperAdmin': true,
    'isApproved': true,
    'deviceId': '',
    'deviceName': '',
    'requestedAt': FieldValue.serverTimestamp(),
    'approvedAt': FieldValue.serverTimestamp(),
    'approvedBy': email,
  }, SetOptions(merge: true));

  // print('슈퍼관리자 계정이 account 컬렉션에 생성되었습니다.'); // 프로덕션에서는 사용하지 않음
} 