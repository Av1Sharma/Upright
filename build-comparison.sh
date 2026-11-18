#!/bin/sh
set -eu
cd "$(dirname "$0")"
npm --prefix Comparison ci
Comparison/node_modules/.bin/esbuild Comparison/comparison.js --bundle --minify --platform=browser --outfile=Comparison/bundle.js
swift build -c release --product PoseComparison
APP="Shoulder Comparison.app/Contents"
mkdir -p "$APP/MacOS" "$APP/Resources/comparison"
cp .build/release/PoseComparison "$APP/MacOS/PoseComparison"
cp Comparison/index.html Comparison/bundle.js "$APP/Resources/comparison/"
cat > "$APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PoseComparison</string>
<key>CFBundleIdentifier</key><string>com.upright.shouldercomparison</string>
<key>CFBundleName</key><string>Shoulder Comparison</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSCameraUsageDescription</key><string>Compare shoulder detection on camera frames.</string>
</dict></plist>
codesign --force --deep --sign - "Shoulder Comparison.app"
