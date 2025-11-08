#!/bin/bash
# Build script for Cloudflare Pages
# Works whether flutter_viewer is root or subdirectory

set -e

echo "🔨 Building Flutter web app..."

# Check if we're in flutter_viewer directory or parent
if [ -f "pubspec.yaml" ] && [ -d "lib" ]; then
  # We're already in flutter_viewer directory
  echo "✅ Already in flutter_viewer directory"
  FLUTTER_DIR="."
elif [ -d "flutter_viewer" ] && [ -f "flutter_viewer/pubspec.yaml" ]; then
  # flutter_viewer is a subdirectory
  echo "✅ Found flutter_viewer subdirectory"
  FLUTTER_DIR="flutter_viewer"
  cd flutter_viewer
else
  echo "❌ Error: Could not find Flutter project"
  echo "   Current directory: $(pwd)"
  echo "   Contents: $(ls -la)"
  exit 1
fi

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Build for web
echo "🏗️  Building Flutter web (release mode)..."
flutter build web --release --base-href "/"

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
