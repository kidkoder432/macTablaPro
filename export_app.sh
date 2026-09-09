#!/bin/bash
set -e

APP_NAME="macTablaPro"
BUILD_DIR="./build"
DEFAULT_OUTPUT_DIR="$HOME/Desktop"
OUTPUT_TARGET=""
VERBOSE=false
QUIET=false
CLEAN=false

print_usage() {
    cat << EOF
Usage: ./export_app.sh [OPTIONS]

Exports, ad-hoc signs, and packages ${APP_NAME} into a standalone zip archive.

Options:
  -o, --output <path>    Specify custom output zip file path or target directory
                         (Default: ~/Desktop/${APP_NAME}.zip)
  -v, --verbose          Show full Xcode build output in the terminal
  -q, --quiet            Suppress standard build logs (summary & errors only)
  -c, --clean            Clean previous build artifacts before compiling
  -h, --help             Display this help message

Examples:
  ./export_app.sh
  ./export_app.sh -v
  ./export_app.sh -o ~/Downloads/${APP_NAME}-v1.0.zip
  ./export_app.sh --output ./dist --clean
EOF
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            if [ -n "$2" ] && [[ "$2" != -* ]]; then
                OUTPUT_TARGET="$2"
                shift 2
            else
                echo "❌ Error: --output requires a file or directory path argument."
                exit 1
            fi
            ;;
        -v|--verbose)
            VERBOSE=true
            QUIET=false
            shift
            ;;
        -q|--quiet)
            QUIET=true
            VERBOSE=false
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "❌ Error: Unknown option '$1'"
            print_usage
            exit 1
            ;;
    esac
done

# Resolve Output File Path
if [ -z "$OUTPUT_TARGET" ]; then
    FINAL_ZIP_PATH="${DEFAULT_OUTPUT_DIR}/${APP_NAME}.zip"
    mkdir -p "$DEFAULT_OUTPUT_DIR"
elif [ -d "$OUTPUT_TARGET" ] || [[ "$OUTPUT_TARGET" == */ ]]; then
    mkdir -p "$OUTPUT_TARGET"
    DEST_DIR=$(cd "$OUTPUT_TARGET" && pwd)
    FINAL_ZIP_PATH="${DEST_DIR}/${APP_NAME}.zip"
else
    DEST_DIR=$(dirname "$OUTPUT_TARGET")
    mkdir -p "$DEST_DIR"
    DEST_DIR_ABS=$(cd "$DEST_DIR" && pwd)
    BASE_NAME=$(basename "$OUTPUT_TARGET")
    if [[ "$BASE_NAME" != *.zip ]]; then
        BASE_NAME="${BASE_NAME}.zip"
    fi
    FINAL_ZIP_PATH="${DEST_DIR_ABS}/${BASE_NAME}"
fi

# Optional Clean Step
if [ "$CLEAN" = true ]; then
    echo "🧹 Cleaning previous build cache at ${BUILD_DIR}..."
    rm -rf "${BUILD_DIR}"
fi

echo "🔨 Building ${APP_NAME} for macOS (Release configuration)..."

LOG_FILE="/tmp/${APP_NAME}_build.log"

XCODE_CMD=(
    xcodebuild -project "${APP_NAME}.xcodeproj"
               -scheme "${APP_NAME}"
               -configuration Release
               -derivedDataPath "${BUILD_DIR}"
               CODE_SIGN_IDENTITY="-"
               CODE_SIGNING_REQUIRED=NO
               CODE_SIGNING_ALLOWED=YES
               build
)

if [ "$VERBOSE" = true ]; then
    "${XCODE_CMD[@]}" | tee "$LOG_FILE"
else
    if [ "$QUIET" = false ]; then
        echo "   (Build logs redirected to ${LOG_FILE}. Use -v / --verbose for real-time output)"
    fi
    "${XCODE_CMD[@]}" > "$LOG_FILE" 2>&1 || {
        echo ""
        echo "❌ Build failed! Showing error log:"
        echo "--------------------------------------------------------"
        cat "$LOG_FILE"
        echo "--------------------------------------------------------"
        exit 1
    }
fi

APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Built app bundle not found at $APP_PATH"
    exit 1
fi

echo "🔏 Ad-hoc code signing app bundle..."
codesign --force --deep --sign - "$APP_PATH"

echo "📦 Packaging into zip archive..."
rm -f "$FINAL_ZIP_PATH"

ORIGINAL_DIR="$(pwd)"
cd "${BUILD_DIR}/Build/Products/Release"
zip -qry "$FINAL_ZIP_PATH" "${APP_NAME}.app"
cd "$ORIGINAL_DIR"

ZIP_SIZE=$(du -h "$FINAL_ZIP_PATH" | cut -f1 | xargs)

echo ""
echo "✅ SUCCESS! App packaged cleanly (${ZIP_SIZE}) at:"
echo "   $FINAL_ZIP_PATH"
echo ""
echo "--------------------------------------------------------"
echo "Instructions for recipients:"
echo "1. Unzip $(basename "$FINAL_ZIP_PATH") on target Mac."
echo "2. Right-click ${APP_NAME}.app and select 'Open'."
echo "3. If macOS displays 'App is damaged' or 'Unidentified Developer':"
echo "   Open Terminal and run:"
echo "   xattr -cr path/to/${APP_NAME}.app"
echo "--------------------------------------------------------"
