import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/device_id_service.dart';
import '../services/firebase_service.dart';
import 'home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FlutterTts flutterTts = FlutterTts();
  String? deviceId;
  bool showDeviceId = false;
  bool isDeviceRegistered = false;
  int deviceStatus = 0; // 0: 미등록, 1: 승인대기, 2: 정상

  @override
  void initState() {
    super.initState();
    flutterTts.setLanguage('en-US');
    flutterTts.setPitch(1.0);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final deviceIdService = DeviceIdService();
    final firebaseService = FirebaseService();
    final id = await deviceIdService.getDeviceId();
    final status = await firebaseService.getDeviceRegistrationStatus();
    if (mounted) {
      setState(() {
        deviceId = id;
        deviceStatus = status;
        isDeviceRegistered = status > 0;
      });
    }
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    if (status == 2) {
      _proceedToApp();
    } else {
      if (mounted) {
        setState(() {
          showDeviceId = true;
        });
      }
    }
  }

  void _copyDeviceId() {
    if (deviceId != null) {
      Clipboard.setData(ClipboardData(text: deviceId!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('기기 고유번호가 클립보드에 복사되었습니다.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _proceedToApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!showDeviceId) {
      return const _SplashLoadingView();
    }
    return _DeviceIdView(
      deviceId: deviceId,
      deviceStatus: deviceStatus,
      onCopyDeviceId: _copyDeviceId,
      onProceedToApp: _proceedToApp,
    );
  }
}

class _SplashLoadingView extends StatelessWidget {
  const _SplashLoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.purple],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    fit: BoxFit.contain,
                    width: 120,
                    height: 120,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'SominWord',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '영어 단어 학습 앱',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceIdView extends StatelessWidget {
  const _DeviceIdView({
    required this.deviceId,
    required this.deviceStatus,
    required this.onCopyDeviceId,
    required this.onProceedToApp,
  });

  final String? deviceId;
  final int deviceStatus;
  final VoidCallback onCopyDeviceId;
  final VoidCallback onProceedToApp;

  String _getStatusMessage() {
    switch (deviceStatus) {
      case 0:
        return '기기가 등록되지 않았습니다.';
      case 1:
        return '승인 대기 중입니다.';
      case 2:
        return '기기가 정상 등록되었습니다.';
      default:
        return '알 수 없는 상태입니다.';
    }
  }

  Color _getBorderColor() {
    switch (deviceStatus) {
      case 0:
        return Colors.red;
      case 1:
        return Colors.yellow;
      case 2:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getHelpMessage() {
    switch (deviceStatus) {
      case 0:
        return '관리자 페이지에서 기기를 등록해주세요.';
      case 1:
        return '관리자 페이지에서 승인을 기다리고 있습니다.';
      case 2:
        return '관리자 페이지에서 이 번호를 입력하여 단어를 추가/수정할 수 있습니다.';
      default:
        return '도움말을 찾을 수 없습니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.purple],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.contain,
                      width: 100,
                      height: 100,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '기기 고유번호',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        offset: Offset(0, 2),
                        blurRadius: 4,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _getStatusMessage(),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: _getBorderColor(), width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: _getBorderColor().withValues(alpha: 0.1),
                  ),
                  child: Column(
                    children: [
                      Text(
                        deviceId ?? '로딩 중...',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: onCopyDeviceId,
                            icon: const Icon(Icons.copy),
                            label: const Text('복사'),
                          ),
                          if (deviceStatus == 2) ...[
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: onProceedToApp,
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('앱 시작'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _getHelpMessage(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white60,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 