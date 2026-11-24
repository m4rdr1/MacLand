set -euo pipefail
cd "$(dirname "$0")"

APP="MacLand.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

swiftc -swift-version 5 -O \
    -target "$(uname -m)-apple-macos12.0" \
    -o "$APP/Contents/MacOS/MacLand" \
    Sources/*.swift \
    -framework AppKit -framework CoreText -framework CoreAudio -framework EventKit -framework ImageIO

clang -dynamiclib -O2 -fblocks \
    -target "$(uname -m)-apple-macos12.0" \
    -o "$APP/Contents/Resources/MacLandMedia.dylib" \
    Sources/MediaBridge.c \
    -framework CoreFoundation

cp Resources/macland-media.pl "$APP/Contents/Resources/macland-media.pl"

codesign --force --sign - "$APP/Contents/Resources/MacLandMedia.dylib" >/dev/null 2>&1 || true
codesign --force --sign - --identifier com.macland.app "$APP" >/dev/null 2>&1 || true
echo "built $APP"
