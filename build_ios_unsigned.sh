#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build}"
PROJECT="$ROOT/MeloX.xcodeproj"
SCHEME="MeloX"
APP_NAME="MeloX"
DERIVED_DATA="$BUILD/DerivedData-iOS"
STAGING="$BUILD/IPA"
IPA_PATH="$BUILD/MeloX-iOS-unsigned.ipa"

rm -rf "$DERIVED_DATA" "$STAGING"
rm -f "$IPA_PATH"
mkdir -p "$BUILD"

echo "========== 构建 iOS Release =========="

xcodebuild clean build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
  TARGETED_DEVICE_FAMILY="1,2" \
  REGISTER_APP_GROUPS=NO \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE="" \
  PROVISIONING_PROFILE_SPECIFIER=""

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Release-iphoneos" -maxdepth 2 -name "$APP_NAME.app" -type d -print -quit)"

if [[ -z "$APP_PATH" ]]; then
  echo "找不到 iOS 构建产物：$APP_NAME.app"
  exit 1
fi

echo "========== 生成未签名 IPA =========="

mkdir -p "$STAGING/Payload"
ditto --norsrc "$APP_PATH" "$STAGING/Payload/$APP_NAME.app"
ditto -c -k --norsrc --keepParent "$STAGING/Payload" "$IPA_PATH"

if [[ ! -f "$IPA_PATH" ]]; then
  echo "生成未签名 IPA 失败"
  exit 1
fi

unzip -tq "$IPA_PATH"
ls -lh "$IPA_PATH"

echo "已生成：$IPA_PATH"
