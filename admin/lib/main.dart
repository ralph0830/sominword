import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

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
      title: 'Admin - 단어 관리',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return WordAdminPage(user: snapshot.data!);
        }
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _pwController = TextEditingController();
  String? _error;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _pwController.text.trim(),
        );
      } catch (e) {
        setState(() {
          _error = '로그인 실패: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 로그인')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: '이메일'),
                  validator: (v) => v == null || v.isEmpty ? '이메일 입력' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pwController,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  obscureText: true,
                  validator: (v) => v == null || v.isEmpty ? '비밀번호 입력' : null,
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                ],
                ElevatedButton(
                  onPressed: _login,
                  child: const Text('로그인'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WordAdminPage extends StatefulWidget {
  final User user;
  const WordAdminPage({super.key, required this.user});

  @override
  State<WordAdminPage> createState() => _WordAdminPageState();
}

class _WordAdminPageState extends State<WordAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _engController = TextEditingController();
  final TextEditingController _posController = TextEditingController();
  final TextEditingController _korController = TextEditingController();

  Future<void> _addWord() async {
    if (_formKey.currentState!.validate()) {
      final eng = _engController.text.trim();
      try {
        // 중복 단어 체크
        final dup = await FirebaseFirestore.instance
            .collection('words')
            .where('english_word', isEqualTo: eng)
            .get();
        if (dup.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미 등록된 단어입니다.')),
          );
          return;
        }
        // 중복이 아니면 추가
        await FirebaseFirestore.instance.collection('words').add({
          'english_word': eng,
          'korean_part_of_speech': _posController.text.trim(),
          'korean_meaning': _korController.text.trim(),
          'input_timestamp': FieldValue.serverTimestamp(),
        });
        _engController.clear();
        _posController.clear();
        _korController.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어가 추가되었습니다.')),
        );
        setState(() {});
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추가 실패: $e')),
        );
      }
    }
  }

  void _showCsvDialog() {
    final csvController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CSV 붙여넣기 (영어,품사,뜻)'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: csvController,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: '예시: apple,명사,사과\nrun,동사,달리다',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final lines = csvController.text.trim().split('\n');
              int success = 0, duplicate = 0, fail = 0;
              for (final line in lines) {
                final parts = line.split(',');
                if (parts.length < 3) { fail++; continue; }
                final eng = parts[0].trim();
                final pos = parts[1].trim();
                final kor = parts[2].trim();
                try {
                  final dup = await FirebaseFirestore.instance
                      .collection('words')
                      .where('english_word', isEqualTo: eng)
                      .get();
                  if (dup.docs.isNotEmpty) {
                    duplicate++;
                    continue;
                  }
                  await FirebaseFirestore.instance.collection('words').add({
                    'english_word': eng,
                    'korean_part_of_speech': pos,
                    'korean_meaning': kor,
                    'input_timestamp': FieldValue.serverTimestamp(),
                  });
                  success++;
                } catch (e) {
                  fail++;
                }
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('등록: $success, 중복: $duplicate, 실패: $fail')),
              );
              setState(() {});
            },
            child: const Text('일괄 등록'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('단어 관리(Admin)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'CSV 붙여넣기',
            onPressed: _showCsvDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _engController,
                      decoration: const InputDecoration(labelText: '영어 단어'),
                      validator: (v) => v == null || v.isEmpty ? '필수 입력' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _posController,
                      decoration: const InputDecoration(labelText: '품사'),
                      validator: (v) => v == null || v.isEmpty ? '필수 입력' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _korController,
                      decoration: const InputDecoration(labelText: '한글 뜻'),
                      validator: (v) => v == null || v.isEmpty ? '필수 입력' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addWord,
                    child: const Text('추가'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showCsvDialog,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('CSV 붙여넣기'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('words')
                    .orderBy('input_timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('등록된 단어가 없습니다.'));
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, idx) {
                      final data = docs[idx].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(data['english_word'] ?? ''),
                        subtitle: Text('${data['korean_part_of_speech'] ?? ''} / ${data['korean_meaning'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                final engCtrl = TextEditingController(text: data['english_word'] ?? '');
                                final posCtrl = TextEditingController(text: data['korean_part_of_speech'] ?? '');
                                final korCtrl = TextEditingController(text: data['korean_meaning'] ?? '');
                                await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('단어 수정'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: engCtrl,
                                          decoration: const InputDecoration(labelText: '영어 단어'),
                                        ),
                                        TextField(
                                          controller: posCtrl,
                                          decoration: const InputDecoration(labelText: '품사'),
                                        ),
                                        TextField(
                                          controller: korCtrl,
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
                                          try {
                                            await docs[idx].reference.update({
                                              'english_word': engCtrl.text.trim(),
                                              'korean_part_of_speech': posCtrl.text.trim(),
                                              'korean_meaning': korCtrl.text.trim(),
                                            });
                                            if (!ctx.mounted) return;
                                            ScaffoldMessenger.of(ctx).showSnackBar(
                                              const SnackBar(content: Text('단어가 수정되었습니다.')),
                                            );
                                            Navigator.pop(ctx);
                                            setState(() {});
                                          } catch (e) {
                                            if (!ctx.mounted) return;
                                            ScaffoldMessenger.of(ctx).showSnackBar(
                                              SnackBar(content: Text('수정 실패: $e')),
                                            );
                                          }
                                        },
                                        child: const Text('저장'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                try {
                                  await docs[idx].reference.delete();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('단어가 삭제되었습니다.')),
                                  );
                                  setState(() {});
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('삭제 실패: $e')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
