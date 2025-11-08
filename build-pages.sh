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

