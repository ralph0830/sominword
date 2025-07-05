import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/device_id_service.dart';
import 'services/firebase_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  await Hive.openBox('favorites');
  // Firestore 오프라인 캐싱(퍼시스턴스) 활성화 (공식 가이드)
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  
  // 기기 ID 초기화 및 기기 정보 저장
  final deviceIdService = DeviceIdService();
  final firebaseService = FirebaseService();
  await deviceIdService.getDeviceId(); // 기기 ID 생성/확인
  await firebaseService.saveDeviceInfoIfNotExists(); // 기기 정보를 Firebase에 저장 (존재하지 않을 때만 등록)
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SominWord',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Pretendard', // 가독성 높은 폰트(설치 필요시 NotoSans, Pretendard 등)
        scaffoldBackgroundColor: const Color(0xFFF6F2FF), // 연보라 파스텔톤 배경
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF), // 브랜드 보라색
          primary: const Color(0xFF7C4DFF),
          primaryContainer: const Color(0xFFD1C4E9),
          secondary: const Color(0xFF9575CD),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSurface: Colors.black87,
        ),
        cardTheme: const CardThemeData(
          elevation: 8,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          color: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            backgroundColor: const Color(0xFFD1C4E9),
            foregroundColor: const Color(0xFF7C4DFF),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        textTheme: const TextTheme(
          displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Pretendard'),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Pretendard'),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, fontFamily: 'Pretendard'),
          bodyLarge: TextStyle(fontSize: 16, fontFamily: 'Pretendard'),
          bodyMedium: TextStyle(fontSize: 14, fontFamily: 'Pretendard'),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF7C4DFF)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF7C4DFF),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Pretendard'),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF7C4DFF),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Pretendard'),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
