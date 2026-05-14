#!/usr/bin/env bash
# build_ipa.sh — ImunDe IPA 빌드 스크립트
# macOS + Xcode 26 beta 이상 환경에서 실행하세요.
#
# 사용법:
#   chmod +x build_ipa.sh
#   ./build_ipa.sh                          # 자동 서명 (개인 개발자)
#   TEAM_ID=ABCD1234EF ./build_ipa.sh       # 팀 ID 지정

set -euo pipefail

SCHEME="ImunDe"
BUNDLE_ID="app.imunde.ImunDe"
BUILD_DIR="$(pwd)/build"
ARCHIVE_PATH="$BUILD_DIR/ImunDe.xcarchive"
IPA_DIR="$BUILD_DIR/ipa"

# ── 1. Team ID 확인 ──────────────────────────────────────────────────────────
if [[ -z "${TEAM_ID:-}" ]]; then
    # Keychain에서 자동 감지
    TEAM_ID=$(security find-identity -v -p codesigning 2>/dev/null \
        | grep -o '([A-Z0-9]\{10\})' | head -1 | tr -d '()' || true)
fi

if [[ -z "${TEAM_ID:-}" ]]; then
    echo "❌  Apple Developer Team ID를 찾을 수 없습니다."
    echo "    TEAM_ID=XXXXXXXXXX ./build_ipa.sh  형식으로 실행하거나"
    echo "    Xcode → Settings → Accounts 에서 계정을 추가하세요."
    exit 1
fi
echo "✅  Team ID: $TEAM_ID"

# ── 2. XcodeGen ──────────────────────────────────────────────────────────────
if ! command -v xcodegen &>/dev/null; then
    echo "⚙️   xcodegen 설치 중..."
    brew install xcodegen
fi

echo "⚙️   xcodeproj 생성 중..."
# project.yml의 DEVELOPMENT_TEAM을 임시로 주입
sed "s/DEVELOPMENT_TEAM: \"\"/DEVELOPMENT_TEAM: \"$TEAM_ID\"/" project.yml > /tmp/project_signed.yml
cp project.yml project.yml.bak
cp /tmp/project_signed.yml project.yml
xcodegen generate --spec project.yml
cp project.yml.bak project.yml   # 원본 복원

# ── 3. Archive ───────────────────────────────────────────────────────────────
mkdir -p "$BUILD_DIR"
echo "🔨  빌드 & 아카이브 중..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic \
    | xcpretty 2>/dev/null || cat  # xcpretty 없으면 raw 출력

# ── 4. ExportOptions.plist 생성 ──────────────────────────────────────────────
EXPORT_PLIST="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
PLIST

# ── 5. IPA Export ────────────────────────────────────────────────────────────
echo "📦  IPA 내보내는 중..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$IPA_DIR" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    | xcpretty 2>/dev/null || cat

IPA_FILE=$(find "$IPA_DIR" -name "*.ipa" | head -1)
if [[ -n "$IPA_FILE" ]]; then
    echo ""
    echo "🎉  IPA 완성: $IPA_FILE"
    echo "    → AltStore / Sideloadly / TestFlight 로 설치하세요."
else
    echo "❌  IPA 파일을 찾을 수 없습니다. 위 로그를 확인하세요."
    exit 1
fi
