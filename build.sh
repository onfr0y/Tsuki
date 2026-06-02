#!/bin/bash

# Configuration
APP_NAME="tsuki"
SRC_DIR="Sources"
OUT_DIR="Build"
APP_BUNDLE="${OUT_DIR}/${APP_NAME}.app"
MAC_OS_DIR="${APP_BUNDLE}/Contents/MacOS"
RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"
INFO_PLIST="${APP_BUNDLE}/Contents/Info.plist"

# Clean previous build
rm -rf "${OUT_DIR}"
mkdir -p "${MAC_OS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Compile Swift code
echo "Compiling Swift code..."
swiftc ${SRC_DIR}/*.swift -o "${MAC_OS_DIR}/${APP_NAME}"

# Copy resources if available
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi
if [ -f "grain.jpg" ]; then
    cp "grain.jpg" "${RESOURCES_DIR}/grain.jpg"
fi

# Create Info.plist
echo "Creating Info.plist..."
cat > "${INFO_PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.fr0y.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Sign the application (ad-hoc) to allow Accessibility permissions to stick
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Build complete! App bundle created at ${APP_BUNDLE}"
echo "To run it, open ${APP_BUNDLE}"
