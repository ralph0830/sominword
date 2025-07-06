import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceIdController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;
  static String? _globalErrorMessage;
  static bool _globalIsLoading = false;

  @override
  void initState() {
    super.initState();
    if (_globalErrorMessage != null) {
      _errorMessage = _globalErrorMessage;
      _globalErrorMessage = null;
    }
    _isLoading = _globalIsLoading;
    _globalIsLoading = false;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      _globalIsLoading = true;
      _globalErrorMessage = null;
    }
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (userCredential.user?.email == 'ralph0830@gmail.com') {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
      final adminDoc = await FirebaseFirestore.instance
          .collection('account')
          .doc(userCredential.user!.email)
          .get();
      if (!adminDoc.exists || !(adminDoc.data()?['isApproved'] ?? false)) {
        _globalErrorMessage = '관리자 승인이 되지 않은 아이디 입니다. 관리자에게 문의 바랍니다.';
        await FirebaseAuth.instance.signOut();
        return;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = '등록되지 않은 이메일입니다.';
          break;
        case 'wrong-password':
          message = '잘못된 비밀번호입니다.';
          break;
        case 'invalid-email':
          message = '유효하지 않은 이메일 형식입니다.';
          break;
        case 'weak-password':
          message = '비밀번호가 너무 약합니다.';
          break;
        case 'email-already-in-use':
          message = '이미 사용 중인 이메일입니다.';
          break;
        default:
          message = '로그인 실패: ${e.message}';
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '오류가 발생했습니다: $e';
        });
      }
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final email = _emailController.text.trim();
      final deviceId = _deviceIdController.text.trim();
      if (email.isEmpty || deviceId.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = '이메일과 기기 고유번호를 모두 입력해주세요.';
          });
        }
        return;
      }
      final deviceDoc = await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .get();
      if (!deviceDoc.exists) {
        if (mounted) {
          setState(() {
            _errorMessage = '유효하지 않은 기기 고유번호입니다. 앱에서 확인한 번호를 정확히 입력해주세요.';
          });
        }
        return;
      }
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );
      await FirebaseFirestore.instance
          .collection('account')
          .doc(userCredential.user!.email)
          .set({
        'uid': userCredential.user!.uid,
        'email': email,
        'deviceId': deviceId,
        'deviceName': deviceDoc.data()?['deviceName'] ?? 'Unknown Device',
        'isApproved': false,
        'isSuperAdmin': false,
        'requestedAt': FieldValue.serverTimestamp(),
        'approvedAt': null,
        'approvedBy': null,
      });
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() {
          _errorMessage = '관리자 신청이 완료되었습니다. 슈퍼 관리자의 승인을 기다려주세요.';
          _isSignUp = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = '비밀번호가 너무 약합니다.';
          break;
        case 'email-already-in-use':
          message = '이미 사용 중인 이메일입니다.';
          break;
        case 'invalid-email':
          message = '유효하지 않은 이메일 형식입니다.';
          break;
        default:
          message = '회원가입 실패: ${e.message}';
      }
      if (mounted) {
        setState(() {
          _errorMessage = message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '오류가 발생했습니다: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp ? '관리자 신청' : '관리자 로그인'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isSignUp ? Icons.person_add : Icons.admin_panel_settings,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),
              Text(
                _isSignUp ? '관리자 신청' : '관리자 로그인',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isSignUp
                    ? '기기별 단어를 관리할 수 있는 권한을 신청합니다.'
                    : '슈퍼 관리자 또는 승인된 관리자만 접근할 수 있습니다.',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '이메일을 입력해주세요.';
                  }
                  if (!value.contains('@')) {
                    return '유효한 이메일 형식을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_isSignUp) ...[
                TextFormField(
                  controller: _deviceIdController,
                  decoration: const InputDecoration(
                    labelText: '기기 고유번호',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.device_hub),
                    hintText: '앱에서 확인한 기기 고유번호를 입력하세요',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '기기 고유번호를 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                onFieldSubmitted: (value) {
                  if (!_isLoading) {
                    _isSignUp ? _signUp() : _signIn();
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호를 입력해주세요.';
                  }
                  if (value.length < 6) {
                    return '비밀번호는 6자 이상이어야 합니다.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300, width: 2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning, color: Colors.red.shade600, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '로그인 오류',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : (_isSignUp ? _signUp : _signIn),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(_isSignUp ? '관리자 신청' : '로그인'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSignUp = !_isSignUp;
                    _errorMessage = null;
                    _emailController.clear();
                    _passwordController.clear();
                    _deviceIdController.clear();
                  });
                },
                child: Text(_isSignUp ? '이미 계정이 있으신가요? 로그인' : '관리자 신청하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 