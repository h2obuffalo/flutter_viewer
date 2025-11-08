#!/bin/bash
# Build script for Cloudflare Pages (when flutter_viewer is repository root)
# This version assumes the repository root IS the Flutter project

set -e

echo "🔨 Building Flutter web app..."

# Verify we're in a Flutter project
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found"
  echo "   Current directory: $(pwd)"
  exit 1
fi

# Install Flutter if not already installed
if ! command -v flutter &> /dev/null; then
  echo "📥 Installing Flutter..."
  
  # Save current directory
  PROJECT_DIR=$(pwd)
  
  # Download Flutter SDK
  FLUTTER_VERSION="3.35.7"
  FLUTTER_SDK_DIR="$HOME/flutter"
  
  if [ ! -d "$FLUTTER_SDK_DIR" ]; then
    cd $HOME
    git clone --branch stable --depth 1 https://github.com/flutter/flutter.git $FLUTTER_SDK_DIR
    cd $FLUTTER_SDK_DIR
    git checkout $FLUTTER_VERSION 2>/dev/null || true
  fi
  
  # Add Flutter to PATH
  export PATH="$FLUTTER_SDK_DIR/bin:$PATH"
  
  # Accept licenses
  flutter doctor --android-licenses 2>/dev/null || true
  
  # Return to project directory
  cd "$PROJECT_DIR"
  
  echo "✅ Flutter installed"
fi

# Verify Flutter is available
if ! command -v flutter &> /dev/null; then
  echo "❌ Error: Flutter installation failed"
  exit 1
fi

# Disable iOS/macOS builds to prevent Xcode errors
export FLUTTER_BUILD_MODE=release
export SKIP_POD_INSTALL=1

# Get dependencies (web only, skip platform-specific setup)
echo "📦 Getting Flutter dependencies (web only)..."
flutter config --no-enable-ios 2>/dev/null || true
flutter config --no-enable-macos 2>/dev/null || true
flutter config --enable-web 2>/dev/null || true

# Get dependencies without triggering platform builds
flutter pub get

# Build for web only
echo "🏗️  Building Flutter web (release mode)..."
flutter build web --release --base-href "/" --web-renderer canvaskit

# Copy _redirects file for SPA routing
echo "📋 Copying _redirects file..."
if [ -f "web/_redirects" ]; then
  cp web/_redirects build/web/_redirects
  echo "✅ _redirects file copied"
else
  echo "⚠️  No _redirects file found, creating default..."
  echo "/*    /index.html   200" > build/web/_redirects
fi

echo "✅ Build complete! Output directory: build/web"

