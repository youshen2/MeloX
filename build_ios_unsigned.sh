#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build}"
PROJECT="$ROOT/MeloX.xcodeproj"
BUILD_VARIANT="${MELOX_BUILD_BUNDLE_VARIANT:-legacy}"
SCHEME="MeloX"
APP_NAME="MeloX"
DERIVED_DATA="$BUILD/DerivedData-iOS"
STAGING="$BUILD/IPA"
IPA_PATH="$BUILD/MeloX-iOS-unsigned.ipa"
RELEASE_NOTES_PATH="$BUILD/ReleaseNotes.json"
RELEASE_NOTES_MARKDOWN_PATH="$BUILD/ReleaseNotes.md"
TEMPORARY_PROJECT=""
TEMPORARY_WATCH_INFO=""

cleanup_temporary_build_inputs() {
  if [[ -n "$TEMPORARY_PROJECT" && -d "$TEMPORARY_PROJECT" ]]; then
    rm -rf -- "$TEMPORARY_PROJECT"
  fi
  if [[ -n "$TEMPORARY_WATCH_INFO" && -f "$TEMPORARY_WATCH_INFO" ]]; then
    rm -f -- "$TEMPORARY_WATCH_INFO"
  fi
}

trap cleanup_temporary_build_inputs EXIT INT TERM

rm -rf "$DERIVED_DATA" "$STAGING"
rm -f "$IPA_PATH" "$RELEASE_NOTES_PATH" "$RELEASE_NOTES_MARKDOWN_PATH"
mkdir -p "$BUILD"

case "$BUILD_VARIANT" in
  legacy)
    # GitHub CI、Release 和 Telegram 继续使用原有发布身份。只修改临时
    # xcodeproj/Info.plist 副本，避免污染当前用于 TestFlight 的项目配置。
    TEMPORARY_PROJECT="$ROOT/.MeloX-Legacy-Build-$$.xcodeproj"
    TEMPORARY_WATCH_INFO="$BUILD/MeloXWatch-Legacy-Info-$$.plist"

    if [[ -e "$TEMPORARY_PROJECT" || -e "$TEMPORARY_WATCH_INFO" ]]; then
      echo "Temporary build input already exists; refusing to overwrite / 临时构建输入已存在，拒绝覆盖"
      exit 1
    fi

    ditto --norsrc "$PROJECT" "$TEMPORARY_PROJECT"
    ditto --norsrc "$ROOT/MeloXWatch/Info.plist" "$TEMPORARY_WATCH_INFO"

    # Scheme containers must follow the renamed project in the build copy.
    TEMPORARY_PROJECT_NAME="$(basename "$TEMPORARY_PROJECT")"
    find "$TEMPORARY_PROJECT" -name '*.xcscheme' -type f -exec \
      sed -i '' \
        -e "s#container:MeloX.xcodeproj#container:$TEMPORARY_PROJECT_NAME#g" \
        {} +

    sed -i '' \
      -e 's/azki\.moye\.MeloX/moye.MeloX/g' \
      -e 's/LAW363CUU8/YG7LA7A4T5/g' \
      -e "s#INFOPLIST_FILE = MeloXWatch/Info.plist;#INFOPLIST_FILE = \"$TEMPORARY_WATCH_INFO\";#g" \
      "$TEMPORARY_PROJECT/project.pbxproj"
    /usr/libexec/PlistBuddy \
      -c "Set :WKCompanionAppBundleIdentifier moye.MeloX" \
      "$TEMPORARY_WATCH_INFO"

    PROJECT="$TEMPORARY_PROJECT"
    EXPECTED_APP_BUNDLE_ID="moye.MeloX"
    EXPECTED_WIDGET_BUNDLE_ID="moye.MeloX.LyricsWidget"
    EXPECTED_WATCH_BUNDLE_ID="moye.MeloX.watchkitapp"
    ;;
  testflight)
    # TestFlight 使用项目当前的 App Store Connect 身份。
    EXPECTED_APP_BUNDLE_ID="azki.moye.MeloX"
    EXPECTED_WIDGET_BUNDLE_ID="azki.moye.MeloX.LyricsWidget"
    EXPECTED_WATCH_BUNDLE_ID="azki.moye.MeloX.watchkitapp"
    ;;
  *)
    echo "Unknown MELOX_BUILD_BUNDLE_VARIANT / 未知构建变体：${BUILD_VARIANT}"
    echo "Available values / 可用值：legacy, testflight"
    exit 1
    ;;
esac

echo "========== Build iOS Release / 构建 iOS Release（${BUILD_VARIANT}）=========="

xcodebuild clean build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
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
  echo "iOS build artifact not found / 找不到 iOS 构建产物：$APP_NAME.app"
  exit 1
fi

if [[ ! -f "$APP_PATH/ReleaseNotes.json" || ! -f "$APP_PATH/ReleaseNotes.md" ]]; then
  echo "Release-note metadata or Markdown is missing / 构建产物中缺少更新日志元数据或 Markdown"
  exit 1
fi

WIDGET_PATH="$APP_PATH/PlugIns/MeloXLyricsWidget.appex"
WATCH_PATH="$APP_PATH/Watch/MeloX Watch App.app"

assert_bundle_identifier() {
  local bundle_path="$1"
  local expected_bundle_id="$2"
  local product_name="$3"
  local actual_bundle_id

  if [[ ! -f "$bundle_path/Info.plist" ]]; then
    echo "$product_name Info.plist not found / 找不到 Info.plist：$bundle_path"
    exit 1
  fi

  actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bundle_path/Info.plist")"
  if [[ "$actual_bundle_id" != "$expected_bundle_id" ]]; then
    echo "$product_name Bundle ID does not match $BUILD_VARIANT requirements / Bundle ID 不符合构建要求"
    echo "Expected / 期望：$expected_bundle_id"
    echo "Actual / 实际：$actual_bundle_id"
    exit 1
  fi
}

assert_bundle_identifier "$APP_PATH" "$EXPECTED_APP_BUNDLE_ID" "MeloX"
assert_bundle_identifier "$WIDGET_PATH" "$EXPECTED_WIDGET_BUNDLE_ID" "MeloXLyricsWidget"
assert_bundle_identifier "$WATCH_PATH" "$EXPECTED_WATCH_BUNDLE_ID" "MeloX Watch App"

if [[ "$BUILD_VARIANT" == "legacy" ]]; then
  WATCH_COMPANION_BUNDLE_ID="$(
    /usr/libexec/PlistBuddy \
      -c 'Print :WKCompanionAppBundleIdentifier' \
      "$WATCH_PATH/Info.plist"
  )"
  if [[ "$WATCH_COMPANION_BUNDLE_ID" != "$EXPECTED_APP_BUNDLE_ID" ]]; then
    echo "Watch Companion Bundle ID does not match legacy requirements / Bundle ID 不符合 legacy 构建要求"
    echo "Expected / 期望：$EXPECTED_APP_BUNDLE_ID"
    echo "Actual / 实际：$WATCH_COMPANION_BUNDLE_ID"
    exit 1
  fi
fi

ditto --norsrc "$APP_PATH/ReleaseNotes.json" "$RELEASE_NOTES_PATH"
ditto --norsrc "$APP_PATH/ReleaseNotes.md" "$RELEASE_NOTES_MARKDOWN_PATH"

echo "========== Create unsigned IPA / 生成未签名 IPA =========="

mkdir -p "$STAGING/Payload"
ditto --norsrc "$APP_PATH" "$STAGING/Payload/$APP_NAME.app"
ditto -c -k --norsrc --keepParent "$STAGING/Payload" "$IPA_PATH"

if [[ ! -f "$IPA_PATH" ]]; then
  echo "Failed to create unsigned IPA / 生成未签名 IPA 失败"
  exit 1
fi

unzip -tq "$IPA_PATH"
ls -lh "$IPA_PATH"

echo "Generated / 已生成：$IPA_PATH"
