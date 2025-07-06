import firebase_admin
from firebase_admin import credentials, firestore

# Firebase Admin SDK 초기화 (serviceAccountKey.json 경로를 맞게 수정하세요)
cred = credentials.Certificate('sominword-firebase-admin.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

def make_sentence(word, pos=None):
    word = word.strip()
    if not word:
        return ""
    if pos:
        pos = pos.lower()
    if pos and 'noun' in pos:
        return f"I have a {word}."
    elif pos and 'verb' in pos:
        return f"I like to {word}."
    elif pos and 'adj' in pos:
        return f"This is very {word}."
    elif pos and 'adv' in pos:
        return f"He runs {word}."
    else:
        return f"I know the word {word}."

def main():
    devices = db.collection('devices').stream()
    for device in devices:
        device_id = device.id
        words_ref = db.collection('devices').document(device_id).collection('words')
        words = words_ref.stream()
        for word_doc in words:
            data = word_doc.to_dict()
            word = data.get('englishWord') or data.get('english_word') or data.get('word')
            pos = data.get('koreanPartOfSpeech') or data.get('korean_part_of_speech') or data.get('pos')
            if not word:
                continue
            # 이미 sentence 필드가 있으면 건너뜀
            if 'sentence' in data and data['sentence']:
                continue
            sentence = make_sentence(word, pos)
            print(f"{device_id}/{word_doc.id}: {sentence}")
            words_ref.document(word_doc.id).update({'sentence': sentence})

if __name__ == '__main__':
    main()
