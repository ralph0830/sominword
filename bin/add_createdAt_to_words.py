import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Firebase Admin SDK 초기화 (serviceAccountKey.json 경로를 맞게 수정하세요)
cred = credentials.Certificate('sominword-firebase-admin.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

def main():
    devices = db.collection('devices').stream()
    for device in devices:
        device_id = device.id
        words_ref = db.collection('devices').document(device_id).collection('words')
        words = words_ref.stream()
        for word_doc in words:
            data = word_doc.to_dict()
            updates = {}
            # createdAt 필드가 없으면 inputTimestamp, updatedAt, 없으면 서버 타임스탬프
            if 'createdAt' not in data:
                if 'inputTimestamp' in data:
                    updates['createdAt'] = data['inputTimestamp']
                elif 'updatedAt' in data:
                    updates['createdAt'] = data['updatedAt']
                else:
                    updates['createdAt'] = firestore.SERVER_TIMESTAMP
            # inputTimestamp 필드가 없으면 createdAt, updatedAt, 없으면 서버 타임스탬프
            if 'inputTimestamp' not in data:
                if 'createdAt' in data:
                    updates['inputTimestamp'] = data['createdAt']
                elif 'updatedAt' in data:
                    updates['inputTimestamp'] = data['updatedAt']
                else:
                    updates['inputTimestamp'] = firestore.SERVER_TIMESTAMP
            if updates:
                print(f"{device_id}/{word_doc.id}: {updates}")
                words_ref.document(word_doc.id).update(updates)

if __name__ == '__main__':
    main()
