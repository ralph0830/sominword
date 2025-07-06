import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

void main() async {
  // Firebase 초기화
  await Firebase.initializeApp();
  
  final targetDeviceId = 'bcc12613-7311-4c91-bed6-3ebc0d02915f';
  final firestore = FirebaseFirestore.instance;
  
  if (kDebugMode) {
    debugPrint('단어 이전을 시작합니다...');
    debugPrint('대상 기기 ID: $targetDeviceId');
  }
  
  try {
    // 1. 모든 기기 목록 가져오기
    final devicesSnapshot = await firestore.collection('devices').get();
    if (kDebugMode) {
      debugPrint('총 ${devicesSnapshot.docs.length}개의 기기를 발견했습니다.');
    }
    
    int totalWordsMigrated = 0;
    
    for (final deviceDoc in devicesSnapshot.docs) {
      final deviceId = deviceDoc.id;
      final deviceData = deviceDoc.data();
      final deviceName = deviceData['deviceName'] ?? 'Unknown Device';
      
      // 대상 기기는 건너뛰기
      if (deviceId == targetDeviceId) {
        if (kDebugMode) {
          debugPrint('대상 기기 $deviceName ($deviceId)는 건너뜁니다.');
        }
        continue;
      }
      
      if (kDebugMode) {
        debugPrint('\n기기 $deviceName ($deviceId)의 단어들을 확인 중...');
      }
      
      // 2. 각 기기의 단어들 가져오기
      final wordsSnapshot = await firestore
          .collection('devices/$deviceId/words')
          .get();
      
      if (wordsSnapshot.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint('  - 단어가 없습니다.');
        }
        continue;
      }
      
      if (kDebugMode) {
        debugPrint('  - ${wordsSnapshot.docs.length}개의 단어를 발견했습니다.');
      }
      
      // 3. 각 단어를 대상 기기로 복사
      for (final wordDoc in wordsSnapshot.docs) {
        final wordData = wordDoc.data();
        final englishWord = wordData['englishWord'] ?? '';
        
        // 중복 체크
        final existingWords = await firestore
            .collection('devices/$targetDeviceId/words')
            .where('englishWord', isEqualTo: englishWord)
            .get();
        
        if (existingWords.docs.isNotEmpty) {
          if (kDebugMode) {
            debugPrint('    - "$englishWord" (중복, 건너뜀)');
          }
          continue;
        }
        
        // 단어 복사
        await firestore
            .collection('devices/$targetDeviceId/words')
            .add({
          'englishWord': englishWord,
          'koreanPartOfSpeech': wordData['koreanPartOfSpeech'] ?? '',
          'koreanMeaning': wordData['koreanMeaning'] ?? '',
          'inputTimestamp': wordData['inputTimestamp'] ?? FieldValue.serverTimestamp(),
        });
        
        if (kDebugMode) {
          debugPrint('    - "$englishWord" (이전 완료)');
        }
        totalWordsMigrated++;
      }
    }
    
    if (kDebugMode) {
      debugPrint('\n=== 이전 완료 ===');
      debugPrint('총 $totalWordsMigrated개의 단어가 $targetDeviceId 기기로 이전되었습니다.');
    }
    
    // 4. 대상 기기의 최종 단어 수 확인
    final finalWordsSnapshot = await firestore
        .collection('devices/$targetDeviceId/words')
        .get();
    
    if (kDebugMode) {
      debugPrint('대상 기기의 총 단어 수: ${finalWordsSnapshot.docs.length}개');
    }
    
  } catch (e) {
    if (kDebugMode) {
      debugPrint('오류 발생: $e');
    }
  }
} 