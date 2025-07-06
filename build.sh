#!/bin/bash
set -e

# Flutter 클린 및 의존성 설치
echo "[1/4] flutter clean"
flutter clean

echo "[2/4] flutter pub get"
flutter pub get

echo "[3/4] flutter build apk --release"
flutter build apk --release

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
DEST_PATH="/mnt/e/Document/desktop/sominword.apk"

echo "[4/4] 빌드된 APK 복사: $APK_PATH -> $DEST_PATH"
if [ -f "$APK_PATH" ]; then
    mv "$APK_PATH" "$DEST_PATH"
    echo "✅ 빌드 완료 및 $DEST_PATH 로 복사 완료!"
else
    echo "❌ APK 파일을 찾을 수 없습니다: $APK_PATH"
    exit 1
fi 