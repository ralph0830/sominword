#!/bin/bash

# 관리자 페이지 Flutter Web 빌드 및 서버 배포 스크립트
# id: ralph, host: ralphpark.com, port: 2202, dir: /var/www/html/sominword

set -e

# 1. admin 디렉토리로 이동 후 빌드 (base-href 옵션 추가)
cd "$(dirname "$0")/admin" || exit 1
echo "[0/5] Flutter clean & pub get..."
flutter clean
flutter pub get

echo "[1/5] Flutter Web 빌드 시작..."
flutter build web --base-href /sominword/

# 2. 배포 전 소유자 ralph로 변경
echo "[2/5] 배포 전 소유자(ralph)로 변경..."
ssh -p 2202 ralph@ralphpark.com 'sudo chown -R ralph:ralph /var/www/html/sominword'

# 3. 서버로 파일 전송
echo "[3/5] 서버로 파일 전송 (scp, 포트 2202) ..."
scp -P 2202 -r ../build/web/* ralph@ralphpark.com:/var/www/html/sominword/

# 4. 배포 후 소유자/권한 nginx(101:101)로 변경

echo "[4/5] 서버에서 소유자(101:101) 및 권한(755) 자동 설정..."
ssh -p 2202 ralph@ralphpark.com 'sudo chown -R 101:101 /var/www/html/sominword && sudo chmod -R 755 /var/www/html/sominword'

if [ $? -eq 0 ]; then
  echo "[5/5] ✅ 관리자 페이지가 성공적으로 배포 및 권한 설정되었습니다!"
else
  echo "❌ 파일 전송 또는 권한 설정에 실패했습니다."
  exit 1
fi 