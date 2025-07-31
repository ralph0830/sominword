import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  /// 기기 정보를 저장합니다. (존재하지 않을 때만 등록)
  Future<void> saveDeviceInfoIfNotExists() async {
    final deviceId = await _deviceIdService.getDeviceId();
    final deviceDoc = await _firestore.collection('devices').doc(deviceId).get();

    if (!deviceDoc.exists) {
      final deviceName = await _deviceIdService.getDeviceName();
      await _firestore.collection('devices').doc(deviceId).set({
        'deviceId': deviceId,
        'deviceName': deviceName,
        'nickname': null,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });

      // words 서브컬렉션에 apple(명사, 사과) 단어 추가
      await _firestore
          .collection('devices')
          .doc(deviceId)
          .collection('words')
          .add({
        'englishWord': 'apple',
        'koreanPartOfSpeech': '명사',
        'koreanMeaning': '사과',
        'inputTimestamp': FieldValue.serverTimestamp(),
      });
    } else {
      // 이미 등록된 경우, lastActiveAt만 갱신
      await updateDeviceInfo();
    }
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
    String? sentence,
    String? sentenceKor,
  }) async {
    final wordsPath = await _deviceWordsPath;
    
    final wordData = <String, dynamic>{
      'englishWord': englishWord,
      'koreanPartOfSpeech': koreanPartOfSpeech,
      'koreanMeaning': koreanMeaning,
      'inputTimestamp': FieldValue.serverTimestamp(),
    };
    
    // 예문 필드가 있는 경우에만 추가
    if (sentence != null && sentence.isNotEmpty) {
      wordData['sentence'] = sentence;
    }
    if (sentenceKor != null && sentenceKor.isNotEmpty) {
      wordData['sentenceKor'] = sentenceKor;
    }
    
    await _firestore.collection(wordsPath).add(wordData);
  }

  /// 단어를 수정합니다.
  Future<void> updateWord({
    required String wordId,
    required String englishWord,
    required String koreanPartOfSpeech,
    required String koreanMeaning,
    String? sentence,
    String? sentenceKor,
  }) async {
    final wordsPath = await _deviceWordsPath;
    
    final updateData = <String, dynamic>{
      'englishWord': englishWord,
      'koreanPartOfSpeech': koreanPartOfSpeech,
      'koreanMeaning': koreanMeaning,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    // 예문 필드가 있는 경우에만 추가
    if (sentence != null && sentence.isNotEmpty) {
      updateData['sentence'] = sentence;
    }
    if (sentenceKor != null && sentenceKor.isNotEmpty) {
      updateData['sentenceKor'] = sentenceKor;
    }
    
    await _firestore.collection(wordsPath).doc(wordId).update(updateData);
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
    // Firestore에 저장하지 않음. Hive에서만 관리
    // 이 함수는 더 이상 사용하지 않거나, 빈 함수로 둡니다.
    return;
  }

  /// 즐겨찾기 단어만 가져옵니다.
  Stream<QuerySnapshot> getFavoriteWordsStream() async* {
    // Firestore에서 즐겨찾기 단어만 가져오는 기능은 제거 (Hive에서만 관리)
    // 필요하다면 전체 단어를 불러와서 Hive에서 필터링
    yield* const Stream.empty();
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
    // 즐겨찾기 개수는 Hive에서 계산해야 함
    return {
      'totalWords': totalWords,
      'favoriteWords': 0, // Hive에서 별도 계산 필요
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

  /// 기기의 ownerEmail을 확인하고, 없으면 단어를 정리합니다.
  Future<bool> checkAndCleanupWordsIfNoOwner() async {
    try {
      final deviceId = await _deviceIdService.getDeviceId();
      final deviceDoc = await _firestore.collection('devices').doc(deviceId).get();
      
      if (!deviceDoc.exists) {
        return false; // 기기가 등록되지 않음
      }
      
      final deviceData = deviceDoc.data();
      final ownerEmail = deviceData?['ownerEmail'];
      
      // ownerEmail이 null이거나 빈 문자열이거나 필드 자체가 없는 경우
      if (ownerEmail == null || ownerEmail.toString().trim().isEmpty) {
        // 해당 기기의 모든 단어 삭제
        await _clearAllWords();
        return false; // ownerEmail이 없으므로 접근 불가
      }
      
      return true; // ownerEmail이 있으므로 접근 가능
    } catch (e) {
      return false;
    }
  }

  /// 기기의 모든 단어를 삭제합니다.
  Future<void> _clearAllWords() async {
    try {
      final wordsPath = await _deviceWordsPath;
      final wordsSnapshot = await _firestore.collection(wordsPath).get();
      
      // 배치 작업으로 모든 단어 삭제
      final batch = _firestore.batch();
      for (final doc in wordsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      // 삭제 실패 시 로그만 남기고 계속 진행
      debugPrint('단어 삭제 중 오류 발생: $e');
    }
  }

  /// 기기 등록 상태를 확인하고 적절한 상태를 반환합니다.
  /// 0: 기기가 등록되지 않음
  /// 1: 기기가 등록되었지만 ownerEmail이 없음 (승인 대기 중)
  /// 2: 기기가 등록되고 ownerEmail이 있음 (정상 사용 가능)
  Future<int> getDeviceRegistrationStatus() async {
    try {
      final deviceId = await _deviceIdService.getDeviceId();
      final deviceDoc = await _firestore.collection('devices').doc(deviceId).get();
      
      if (!deviceDoc.exists) {
        return 0; // 기기가 등록되지 않음
      }
      
      final deviceData = deviceDoc.data();
      final ownerEmail = deviceData?['ownerEmail'];
      
      // ownerEmail이 null이거나 빈 문자열이거나 필드 자체가 없는 경우
      if (ownerEmail == null || ownerEmail.toString().trim().isEmpty) {
        return 1; // 기기는 등록되었지만 ownerEmail이 없음 (승인 대기 중)
      }
      
      return 2; // 기기가 등록되고 ownerEmail이 있음 (정상 사용 가능)
    } catch (e) {
      return 0; // 오류 발생 시 등록되지 않은 것으로 처리
    }
  }

  /// Firestore와 로컬 단어 리스트를 비교하여 Firestore에 동기화
  /// Firestore에 없는 단어는 로컬에서도 제거되도록, 동기화 후 남아있는 id 리스트를 반환
  Future<List<String>> syncWordsWithFirestore(List<Map<String, dynamic>> localWords) async {
    final wordsPath = await _deviceWordsPath;
    final snapshot = await _firestore.collection(wordsPath).get();
    final firestoreWords = <String, Map<String, dynamic>>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      firestoreWords[doc.id] = {
        'id': doc.id,
        'word': data['englishWord'] ?? data['english_word'] ?? '',
        'partOfSpeech': data['koreanPartOfSpeech'] ?? data['korean_part_of_speech'] ?? '',
        'meaning': data['koreanMeaning'] ?? data['korean_meaning'] ?? '',
        'input_timestamp': data['inputTimestamp'] ?? data['input_timestamp'],
      };
    }
    // 로컬 단어를 id 기준으로 맵핑
    final localMap = <String, Map<String, dynamic>>{};
    for (final w in localWords) {
      if (w['id'] != null) {
        localMap[w['id']] = w;
      }
    }
    final batch = _firestore.batch();
    // Firestore에만 있는 단어 → 삭제
    for (final id in firestoreWords.keys) {
      if (!localMap.containsKey(id)) {
        batch.delete(_firestore.collection(wordsPath).doc(id));
      }
    }
    // 로컬에만 있는 단어 → 추가
    for (final w in localWords) {
      if (w['id'] == null || !firestoreWords.containsKey(w['id'])) {
        batch.set(_firestore.collection(wordsPath).doc(), {
          'englishWord': w['word'],
          'koreanPartOfSpeech': w['partOfSpeech'],
          'koreanMeaning': w['meaning'],
          'inputTimestamp': w['input_timestamp'],
        });
      }
    }
    // 둘 다 있지만 내용이 다르면 Firestore 수정
    for (final id in firestoreWords.keys) {
      if (localMap.containsKey(id)) {
        final fw = firestoreWords[id]!;
        final lw = localMap[id]!;
        if (fw['word'] != lw['word'] || fw['partOfSpeech'] != lw['partOfSpeech'] || fw['meaning'] != lw['meaning']) {
          batch.update(_firestore.collection(wordsPath).doc(id), {
            'englishWord': lw['word'],
            'koreanPartOfSpeech': lw['partOfSpeech'],
            'koreanMeaning': lw['meaning'],
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }
    await batch.commit();
    // Firestore에 남아있는 id만 반환
    return firestoreWords.keys.toList();
  }

  /// Firestore에서 단어를 즉시 한 번만 가져오는 메서드 (최신순)
  Future<List<Map<String, dynamic>>> getWordsOnce() async {
    final wordsPath = await _deviceWordsPath;
    final snapshot = await _firestore.collection(wordsPath)
        .orderBy('inputTimestamp', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'word': data['englishWord'] ?? data['english_word'] ?? '',
        'partOfSpeech': data['koreanPartOfSpeech'] ?? data['korean_part_of_speech'] ?? '',
        'meaning': data['koreanMeaning'] ?? data['korean_meaning'] ?? '',
        'input_timestamp': data['inputTimestamp'] ?? data['input_timestamp'],
        'sentence': data['sentence'] ?? data['example'] ?? '',
        'sentenceKor': data['sentenceKor'] ?? data['exampleKor'] ?? '',
      };
    }).toList();
  }
} 