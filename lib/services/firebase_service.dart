import 'package:cloud_firestore/cloud_firestore.dart';
import 'device_id_service.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceIdService _deviceIdService = DeviceIdService();

  /// 기기별 단어장 컬렉션 경로를 가져옵니다.
  Future<String> get _deviceWordsPath async {
    final deviceId = await _deviceIdService.getDeviceId();
    return 'devices/$deviceId/words';
  }

  /// 기기 정보를 저장합니다.
  Future<void> saveDeviceInfo() async {
    final deviceId = await _deviceIdService.getDeviceId();
    final deviceName = await _deviceIdService.getDeviceName();
    
    await _firestore.collection('devices').doc(deviceId).set({
      'deviceId': deviceId,
      'deviceName': deviceName,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  /// 기기 정보를 업데이트합니다.
  Future<void> updateDeviceInfo({String? deviceName}) async {
    final deviceId = await _deviceIdService.getDeviceId();
    
    final updateData = <String, dynamic>{
      'lastActiveAt': FieldValue.serverTimestamp(),
    };
    
    if (deviceName != null) {
      updateData['deviceName'] = deviceName;
    }
    
    await _firestore.collection('devices').doc(deviceId).update(updateData);
  }

  /// 단어를 추가합니다.
  Future<void> addWord({
    required String englishWord,
    required String koreanPartOfSpeech,
    required String koreanMeaning,
  }) async {
    final wordsPath = await _deviceWordsPath;
    
    await _firestore.collection(wordsPath).add({
      'englishWord': englishWord,
      'koreanPartOfSpeech': koreanPartOfSpeech,
      'koreanMeaning': koreanMeaning,
      'inputTimestamp': FieldValue.serverTimestamp(),
      'isFavorite': false,
    });
  }

  /// 단어를 수정합니다.
  Future<void> updateWord({
    required String wordId,
    required String englishWord,
    required String koreanPartOfSpeech,
    required String koreanMeaning,
  }) async {
    final wordsPath = await _deviceWordsPath;
    
    await _firestore.collection(wordsPath).doc(wordId).update({
      'englishWord': englishWord,
      'koreanPartOfSpeech': koreanPartOfSpeech,
      'koreanMeaning': koreanMeaning,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 단어를 삭제합니다.
  Future<void> deleteWord(String wordId) async {
    final wordsPath = await _deviceWordsPath;
    await _firestore.collection(wordsPath).doc(wordId).delete();
  }

  /// 모든 단어를 가져옵니다 (최신순 정렬).
  Stream<QuerySnapshot> getWordsStream() async* {
    final wordsPath = await _deviceWordsPath;
    yield* _firestore
        .collection(wordsPath)
        .orderBy('inputTimestamp', descending: true)
        .snapshots();
  }

  /// 오늘 추가된 단어만 가져옵니다.
  Stream<QuerySnapshot> getTodayWordsStream() async* {
    final wordsPath = await _deviceWordsPath;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    yield* _firestore
        .collection(wordsPath)
        .where('inputTimestamp', isGreaterThanOrEqualTo: startOfDay)
        .orderBy('inputTimestamp', descending: true)
        .snapshots();
  }

  /// 즐겨찾기 상태를 토글합니다.
  Future<void> toggleFavorite(String wordId, bool isFavorite) async {
    final wordsPath = await _deviceWordsPath;
    await _firestore.collection(wordsPath).doc(wordId).update({
      'isFavorite': isFavorite,
    });
  }

  /// 즐겨찾기 단어만 가져옵니다.
  Stream<QuerySnapshot> getFavoriteWordsStream() async* {
    final wordsPath = await _deviceWordsPath;
    yield* _firestore
        .collection(wordsPath)
        .where('isFavorite', isEqualTo: true)
        .orderBy('inputTimestamp', descending: true)
        .snapshots();
  }

  /// 특정 날짜의 단어를 가져옵니다.
  Stream<QuerySnapshot> getWordsByDateStream(DateTime date) async* {
    final wordsPath = await _deviceWordsPath;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    yield* _firestore
        .collection(wordsPath)
        .where('inputTimestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('inputTimestamp', isLessThan: endOfDay)
        .orderBy('inputTimestamp', descending: true)
        .snapshots();
  }

  /// 기기별 단어 통계를 가져옵니다.
  Future<Map<String, dynamic>> getDeviceStats() async {
    final wordsPath = await _deviceWordsPath;
    final snapshot = await _firestore.collection(wordsPath).get();
    
    final totalWords = snapshot.docs.length;
    final favoriteWords = snapshot.docs.where((doc) => doc.data()['isFavorite'] == true).length;
    
    return {
      'totalWords': totalWords,
      'favoriteWords': favoriteWords,
    };
  }

  /// 기기가 등록되어 있는지 확인합니다.
  Future<bool> isDeviceRegistered() async {
    try {
      final deviceId = await _deviceIdService.getDeviceId();
      final deviceDoc = await _firestore.collection('devices').doc(deviceId).get();
      return deviceDoc.exists;
    } catch (e) {
      return false;
    }
  }
} 