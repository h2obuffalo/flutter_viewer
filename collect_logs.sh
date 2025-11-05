#!/bin/bash

# Script to collect Chromecast debugging logs from iOS, Android, and TV

echo "📱 Chromecast Debug Log Collection"
echo "=================================="
echo ""

# Detect platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
else
    PLATFORM="unknown"
fi

echo "Platform: $PLATFORM"
echo ""

# Check for Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

# Function to collect iOS logs
collect_ios_logs() {
    echo "📱 Collecting iOS logs..."
    echo "========================="
    
    if [[ "$PLATFORM" != "macos" ]]; then
        echo "⚠️  iOS logs can only be collected on macOS"
        return
    fi
    
    if ! command -v xcrun simctl &> /dev/null; then
        echo "❌ xcrun simctl not found"
        return
    fi
    
    # Get list of booted simulators
    BOOTED_SIMS=$(xcrun simctl list devices | grep "Booted" | head -1)
    
    if [ -z "$BOOTED_SIMS" ]; then
        echo "⚠️  No booted iOS simulators found"
        echo "   To collect logs from a physical device, use Xcode:"
        echo "   Window > Devices and Simulators > Select device > View Device Logs"
        return
    fi
    
    # Extract device UDID (first booted device)
    DEVICE_UDID=$(xcrun simctl list devices | grep "Booted" | head -1 | sed -E 's/.*\(([^)]+)\).*/\1/')
    
    if [ -z "$DEVICE_UDID" ]; then
        echo "⚠️  Could not extract device UDID"
        return
    fi
    
    echo "Device UDID: $DEVICE_UDID"
    echo ""
    echo "Collecting logs (last 100 lines)..."
    xcrun simctl spawn "$DEVICE_UDID" log stream --predicate 'processImagePath contains "Runner" OR processImagePath contains "Chromecast" OR eventMessage contains "Cast" OR eventMessage contains "Chromecast"' --level=debug --style=compact | tail -100 > ios_chromecast_logs.txt
    
    if [ -f ios_chromecast_logs.txt ]; then
        echo "✅ iOS logs saved to: ios_chromecast_logs.txt"
        echo "   Lines: $(wc -l < ios_chromecast_logs.txt)"
    else
        echo "❌ Failed to collect iOS logs"
    fi
    
    echo ""
}

# Function to collect Android logs
collect_android_logs() {
    echo "🤖 Collecting Android logs..."
    echo "=============================="
    
    if ! command -v adb &> /dev/null; then
        echo "❌ adb not found. Please install Android SDK Platform Tools"
        echo "   Install: brew install android-platform-tools (macOS) or apt-get install android-tools-adb (Linux)"
        return
    fi
    
    # Check for connected devices
    DEVICES=$(adb devices | grep -v "List" | grep "device$" | wc -l)
    
    if [ "$DEVICES" -eq 0 ]; then
        echo "⚠️  No Android devices connected"
        echo "   Please connect your device via USB and enable USB debugging"
        return
    fi
    
    echo "Connected devices: $DEVICES"
    echo ""
    echo "Collecting logs (last 200 lines)..."
    adb logcat -d | grep -E "Chromecast|Cast|CastService|flutter_chrome_cast|GoogleCast" | tail -200 > android_chromecast_logs.txt
    
    if [ -f android_chromecast_logs.txt ]; then
        echo "✅ Android logs saved to: android_chromecast_logs.txt"
        echo "   Lines: $(wc -l < android_chromecast_logs.txt)"
    else
        echo "❌ Failed to collect Android logs"
    fi
    
    echo ""
    echo "Full logcat (cleared previous, watching for new logs)..."
    echo "Run your app and cast, then press Ctrl+C to stop"
    adb logcat -c  # Clear previous logs
    adb logcat | grep -E "Chromecast|Cast|CastService|flutter_chrome_cast|GoogleCast|MediaStatus|loadMedia|play" > android_chromecast_realtime.txt &
    LOG_PID=$!
    
    echo "Logging to android_chromecast_realtime.txt (PID: $LOG_PID)"
    echo "Press Ctrl+C to stop logging..."
    trap "kill $LOG_PID 2>/dev/null; echo ''; echo '✅ Logging stopped'" INT
    wait $LOG_PID
}

# Function to collect TV (Chromecast) logs via ADB
collect_tv_logs() {
    echo "📺 Collecting TV (Chromecast) logs..."
    echo "======================================"
    
    if ! command -v adb &> /dev/null; then
        echo "❌ adb not found. Please install Android SDK Platform Tools"
        return
    fi
    
    # List all connected devices
    echo "Checking for connected devices..."
    adb devices
    
    # Check for connected Android TV devices
    TV_DEVICES=$(adb devices | grep -E "tv|androidtv|chromecast" -i || adb devices | grep "device$" | wc -l)
    
    if [ "$TV_DEVICES" -eq 0 ]; then
        echo ""
        echo "⚠️  No Android TV/Chromecast devices found via ADB"
        echo ""
        echo "📋 To connect Android TV via ADB:"
        echo "   1. Enable Developer Options on your Android TV"
        echo "   2. Enable USB Debugging (or Network Debugging)"
        echo "   3. Connect via: adb connect <TV_IP_ADDRESS>:5555"
        echo ""
        echo "📋 Alternative methods to get Chromecast/TV logs:"
        echo ""
        echo "1. Chrome DevTools (for Chromecast devices):"
        echo "   - Open Chrome browser"
        echo "   - Go to: chrome://inspect"
        echo "   - Look for your Chromecast device"
        echo "   - Click 'inspect' to see console logs"
        echo ""
        echo "2. Android TV ADB (if TV supports it):"
        echo "   - Connect via network: adb connect <TV_IP>:5555"
        echo "   - Then run: adb logcat | grep -E 'cast|media|hls|m3u8|INVALID|ERROR' -i"
        echo ""
        echo "3. Network monitoring:"
        echo "   - Monitor network traffic on your router"
        echo "   - Look for HTTP requests to your HLS playlist URL"
        echo "   - Check for 4xx/5xx error responses"
        echo ""
        echo "4. Collect logs from Android device casting to TV:"
        echo "   - Run this script's Android log collection"
        echo "   - Look for Chromecast-related errors"
        return
    fi
    
    echo ""
    echo "Found device(s). Collecting TV logs..."
    echo ""
    
    # Collect recent logs with Chromecast-related keywords
    echo "Collecting recent logs (last 500 lines)..."
    adb logcat -d | grep -E "cast|chromecast|media|hls|m3u8|INVALID_REQUEST|LOAD_FAILED|error|ERROR" -i | tail -500 > tv_chromecast_logs.txt
    
    if [ -f tv_chromecast_logs.txt ]; then
        echo "✅ TV logs saved to: tv_chromecast_logs.txt"
        echo "   Lines: $(wc -l < tv_chromecast_logs.txt)"
        echo ""
        echo "📋 Looking for critical errors..."
        
        # Search for specific error patterns
        if grep -q "INVALID_REQUEST" tv_chromecast_logs.txt -i; then
            echo "   🚨 Found INVALID_REQUEST errors!"
            grep "INVALID_REQUEST" tv_chromecast_logs.txt -i | head -10
        fi
        
        if grep -q "LOAD_FAILED" tv_chromecast_logs.txt -i; then
            echo "   🚨 Found LOAD_FAILED errors!"
            grep "LOAD_FAILED" tv_chromecast_logs.txt -i | head -10
        fi
        
        if grep -q "CORS" tv_chromecast_logs.txt -i; then
            echo "   🚨 Found CORS errors!"
            grep "CORS" tv_chromecast_logs.txt -i | head -10
        fi
        
        echo ""
        echo "📋 Full error log (last 50 error lines):"
        grep -E "error|ERROR|fail|FAIL" tv_chromecast_logs.txt -i | tail -50
    else
        echo "❌ Failed to collect TV logs"
    fi
    
    echo ""
    echo "💡 To watch TV logs in real-time:"
    echo "   adb logcat | grep -E 'cast|media|hls|m3u8|INVALID|ERROR' -i"
    echo ""
}

# Function to show Flutter logs
show_flutter_logs() {
    echo "📱 Flutter App Logs"
    echo "==================="
    echo ""
    echo "To view Flutter logs in real-time, run:"
    echo "  flutter logs"
    echo ""
    echo "Or filter for Cast-related logs:"
    echo "  flutter logs | grep -E 'Cast|Chromecast|Media'"
    echo ""
}

# Main menu
echo "Select log collection method:"
echo "1) iOS Simulator logs"
echo "2) Android device logs"
echo "3) TV/Chromecast logs (via ADB)"
echo "4) All of the above"
echo "5) Show Flutter log commands"
echo ""
read -p "Enter choice (1-5): " choice

case $choice in
    1)
        collect_ios_logs
        ;;
    2)
        collect_android_logs
        ;;
    3)
        collect_tv_logs
        ;;
    4)
        collect_ios_logs
        collect_android_logs
        collect_tv_logs
        ;;
    5)
        show_flutter_logs
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ Log collection complete!"
echo ""
echo "Next steps:"
echo "1. Review the generated log files"
echo "2. Look for errors containing: Cast, Chromecast, Media, HLS, loadMedia, play"
echo "3. Check for connection issues, authentication failures, or media loading errors"
echo ""



