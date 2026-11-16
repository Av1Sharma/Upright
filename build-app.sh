#!/bin/sh
set -eu
swift build -c release
APP="Upright.app/Contents"
mkdir -p "$APP/MacOS"
cp .build/release/Upright "$APP/MacOS/Upright"
cat > "$APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Upright</string>
<key>CFBundleIdentifier</key><string>com.upright.prototype</string>
<key>CFBundleName</key><string>Upright</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSCameraUsageDescription</key><string>Upright uses the camera to estimate your posture locally.</string>
<key>NSMotionUsageDescription</key><string>Upright uses headphone motion to estimate changes in head tilt.</string>
</dict></plist>
codesign --force --deep --sign - Upright.app
