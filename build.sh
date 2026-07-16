#!/bin/bash
# Presence build: SPM release build -> assemble Presence.app -> codesign with the
# pinned identity -> assert the designated requirement is identity-based (not cdhash).
# No Xcode on this machine: SPM + this script is the entire build system.
set -euo pipefail
cd "$(dirname "$0")"

BUNDLE_ID="com.solarthis.presence"                    # IMMUTABLE — TCC grants are keyed to it
SIGN_ID="FCD7116289F2B86E3CA5477065F9172129AA68E6"     # Apple Development (MB77Q6TVVS); ad-hoc is FORBIDDEN
APP="Presence.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Presence "$APP/Contents/MacOS/Presence"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>Presence</string>
    <key>CFBundleExecutable</key><string>Presence</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSCameraUsageDescription</key><string>Presence uses the camera locally to notice when you step away or when another person may be able to view your screen. No images ever leave this Mac.</string>
</dict>
</plist>
PLIST
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Gate: bundle id must never drift (TCC grants die if it does).
grep -q "<string>com.solarthis.presence</string>" "$APP/Contents/Info.plist" \
  || { echo "FATAL: CFBundleIdentifier drifted"; exit 1; }

codesign --force --sign "$SIGN_ID" "$APP"

# Gate: designated requirement must be identity-based; a cdhash DR means ad-hoc
# signing sneaked in and the camera TCC grant will silently die on next rebuild.
DR="$(codesign -d -r- "$APP" 2>&1)"
echo "$DR" | grep -q "Apple Development" || { echo "FATAL: not signed with the pinned identity"; echo "$DR"; exit 1; }
echo "$DR" | grep -q 'cdhash H"' && { echo "FATAL: cdhash designated requirement (ad-hoc?)"; echo "$DR"; exit 1; }

echo "OK: $APP built and signed (bundle id ${BUNDLE_ID})"
