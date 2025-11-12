#!/bin/bash
# Fix CocoaPods sync issue
cd "$(dirname "$0")/.."

echo "🔧 Fixing CocoaPods sync..."

# Clean everything
echo "Cleaning Flutter..."
flutter clean

# Remove iOS build artifacts
echo "Removing iOS build artifacts..."
rm -rf ios/Pods ios/Podfile.lock ios/.symlinks
rm -rf ios/Flutter/Flutter.framework ios/Flutter/Flutter.podspec

# Get Flutter dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Install pods with proper encoding
echo "Installing CocoaPods..."
cd ios
export LANG=en_US.UTF-8
pod install --repo-update

echo "✅ Done! Podfile.lock and Manifest.lock should now be in sync."
