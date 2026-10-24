#!/bin/bash
# install.sh: build Habits, signed, and install it on the iPhone — by cable or Wi-Fi

set -euo pipefail
cd "$(dirname "$0")/.."
source .env

xcodebuild build -quiet \
    -project Habits.xcodeproj -scheme Habits -configuration Debug \
    -destination "id=$DEVICE_UDID" -derivedDataPath build \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    -authenticationKeyPath "$API_KEY_PATH" -authenticationKeyID "$API_KEY_ID" -authenticationKeyIssuerID "$API_ISSUER_ID" \
    DEVELOPMENT_TEAM="$TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"

xcrun devicectl device install app --device "$DEVICE_UDID" build/Build/Products/Debug-iphoneos/Habits.app
