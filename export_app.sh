#!/bin/bash
set -e

APP_NAME="macTablaPro"
BUILD_DIR="./build"
DESKTOP_DIR="$HOME/Desktop"
ZIP_PATH="$DESKTOP_DIR/${APP_NAME}.zip"

echo "🔨 Building ${APP_NAME} for macOS (Release configuration)..."

xcodebuild -project "${APP_NAME}.xcodeproj" \
           -scheme "${APP_NAME}" \
           -configuration Release \
           -derivedDataPath "${BUILD_DIR}" \
           CODE_SIGN_IDENTITY="-" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=YES \
           build

APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Built app bundle not found at $APP_PATH"
    exit 1
fi

echo "🔏 Ad-hoc code signing app bundle..."
codesign --force --deep --sign - "$APP_PATH"

echo "📦 Packaging into zip on Desktop..."
rm -f "$ZIP_PATH"
cd "${BUILD_DIR}/Build/Products/Release"
zip -r "$ZIP_PATH" "${APP_NAME}.app"

echo ""
echo "✅ SUCCESS! App packaged cleanly at:"
echo "   $ZIP_PATH"
echo ""
echo "--------------------------------------------------------"
echo "Instructions for your teacher:"
echo "1. Unzip ${APP_NAME}.zip on their Mac."
echo "2. Right-click ${APP_NAME}.app and select 'Open'."
echo "3. If macOS displays 'App is damaged' or 'Unidentified Developer':"
echo "   Open Terminal and run:"
echo "   xattr -cr ~/Downloads/${APP_NAME}.app"
echo "--------------------------------------------------------"
