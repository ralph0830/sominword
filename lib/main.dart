import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/device_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin - 기기별 단어 관리',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasData) {
          final user = snapshot.data!;
          
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('account')
                .doc(user.email)
                .get(),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              // Firestore account 문서가 없으면 자동 생성
              if (adminSnapshot.data == null || !adminSnapshot.data!.exists) {
                FirebaseFirestore.instance.collection('account').doc(user.email).set({
                  'uid': user.uid,
                  'email': user.email,
                  'isApproved': false,
                  'isSuperAdmin': false,
                  'requestedAt': FieldValue.serverTimestamp(),
                });
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              final adminData = adminSnapshot.data?.data() as Map<String, dynamic>?;
              final isSuperAdmin = adminData?['isSuperAdmin'] == true;
              final isApproved = adminData?['isApproved'] ?? false;
              final email = adminData?['email'] as String?;
              
              debugPrint('🔍 [DEBUG] AuthWrapper: Admin 문서 존재: [33m${adminSnapshot.data?.exists}[0m');
              debugPrint('🔍 [DEBUG] AuthWrapper: Admin 데이터: $adminData');
              debugPrint('🔍 [DEBUG] AuthWrapper: isSuperAdmin: $isSuperAdmin, isApproved: $isApproved');
              
              if (isApproved) {
                return DeviceListPage(isSuperAdmin: isSuperAdmin, email: email);
              } else {
                FirebaseAuth.instance.signOut();
                return const LoginPage();
              }
            },
          );
        }
        
        return const LoginPage();
      },
    );
  }
}
