#!/bin/bash
# Generate iOS app icons from bftv_eye.png using macOS sips

SOURCE="assets/images/bftv_eye.png"
OUTPUT_DIR="ios/Runner/Assets.xcassets/AppIcon.appiconset"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Generating iOS app icons from $SOURCE..."

# iPhone icons
sips -z 40 40 "$SOURCE" --out "$OUTPUT_DIR/Icon-App-20x20@2x.png"
sips -z 60 60 "$SOURCE" --out "$OUTPUT_DIR/Icon-App-20x20@3x.png"
sips -z 29 29 "$SOURCE" --out "$OUTPUT_DIR/Icon-App-29x29@1x.png"
sips -z 58 58 "$SOURCE" --out "$OUTPUT_DIR/Icon-App-29x29@2x.png"
sips -z 87 87 "$SOURCE" --out "$OUTPUT_DIR/Icon-App-29x29@3x.png"
sips -z 80 80 "$SOURCE" --out "$OUTPUT_DIR/Icon-App-40x40@2x.png"
sips -z 120 120 "$SOURCE" --out "$OUTPUT_DIR/Icon-App-40x40@3x.png"
sips -z 120 120 "$SOURCE" --out "$OUTPUT_DIR/Icon-App-60x60@2x.png"
sips -z 180 180 "$SOURCE" --out "$OUTPUT_DIR/Icon-App-60x60@3x.png"

# iPad icons (some overlap with iPhone)
# 20x20@1x already done above as 20x20@2x (we'll copy it)
cp "$OUTPUT_DIR/Icon-App-20x20@2x.png" "$OUTPUT_DIR/Icon-App-20x20@1x.png" 2>/dev/null || sips -z 20 20 "$SOURCE" --out "$OUTPUT_DIR/Icon-App-20x20@1x.png"
# 29x29@1x already done
# 29x29@2x already done
sips -z 40 40 "$SOURCE" --out "$OUTPUT_DIR/Icon-App-40x40@1x.png"
# 40x40@2x already done
sips -z 76 76 "$SOURCE" --out "$OUTPUT_DIR/Icon-App-76x76@1x.png"
sips -z 152 152 "$SOURCE" --out "$OUTPUT_DIR/Icon-App-76x76@2x.png"
sips -z 167 167 "$SOURCE" --out "$OUTPUT_DIR/Icon-App-83.5x83.5@2x.png"

# iOS Marketing (App Store) - 1024x1024 (must have no alpha channel)
# Composite white icon onto black background, then remove alpha channel
sips -z 1024 1024 --setProperty format png --padToHeightWidth 1024 1024 --padColor 000000 "$SOURCE" --out /tmp/icon_1024_with_bg.png
# Remove alpha by converting to JPEG then back to PNG
sips -s format jpeg -s formatOptions 100 /tmp/icon_1024_with_bg.png --out /tmp/icon_1024_no_alpha.jpg
sips -s format png /tmp/icon_1024_no_alpha.jpg --out "$OUTPUT_DIR/Icon-App-1024x1024@1x.png"
rm -f /tmp/icon_1024_with_bg.png /tmp/icon_1024_no_alpha.jpg

echo "✅ Generated all iOS app icons in $OUTPUT_DIR"

