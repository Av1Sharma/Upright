#!/bin/sh
set -eu
cd "$(dirname "$0")"
npm --prefix Comparison ci
NODE_PATH="$PWD/Comparison/node_modules" Comparison/node_modules/.bin/esbuild Model/model.js --bundle --minify --platform=browser --outfile=Model/bundle.js
swift build -c release --product Upright
APP="Upright.app/Contents"
mkdir -p "$APP/MacOS" "$APP/Resources/model"
cp Model/index.html Model/bundle.js "$APP/Resources/model/"
cp .build/release/Upright "$APP/MacOS/Upright"
cat > "$APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Upright</string>
<key>CFBundleIdentifier</key><string>com.upright.prototype</string>
<key>CFBundleName</key><string>Upright</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
<key>NSCameraUsageDescription</key><string>Upright uses the camera to estimate your posture locally.</string>
<key>NSMotionUsageDescription</key><string>Upright uses headphone motion to estimate changes in head tilt.</string>
</dict></plist>
codesign --force --deep --sign - Upright.app
printf "\nBuild complete. Quit Upright from its menu-bar icon, then reopen Upright.app.\n"
