#!/bin/sh
set -eu
cd "$(dirname "$0")"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

swiftc -module-cache-path "$TEST_DIR/module-cache" Sources/Upright/PostureConfirmation.swift Tests/UprightTests/PostureConfirmationTests.swift -o "$TEST_DIR/confirmation"
"$TEST_DIR/confirmation"
swiftc -module-cache-path "$TEST_DIR/module-cache" Sources/Upright/PostureConfirmation.swift Sources/Upright/PostureAlertPolicy.swift Tests/UprightTests/PostureAlertPolicyTests.swift -o "$TEST_DIR/alerts"
"$TEST_DIR/alerts"
swiftc -module-cache-path "$TEST_DIR/module-cache" Sources/Upright/PoseFeatures.swift Tests/UprightTests/PoseFeaturesTests.swift -o "$TEST_DIR/features"
"$TEST_DIR/features"
swiftc -module-cache-path "$TEST_DIR/module-cache" Sources/Upright/LandmarkLayout.swift Tests/UprightTests/LandmarkLayoutTests.swift -o "$TEST_DIR/layout"
"$TEST_DIR/layout"
