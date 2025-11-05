# Getting Android TV / Chromecast Logs

To debug why Chromecast is rejecting the media, you need to check the logs on the TV/Chromecast device itself.

## Method 1: Chrome DevTools (Easiest for Chromecast)

1. **Open Chrome browser** on your computer
2. **Navigate to**: `chrome://inspect`
3. **Look for your Chromecast device** in the list
4. **Click "inspect"** next to your Chromecast device
5. **Check the Console tab** for errors like:
   - `INVALID_REQUEST`
   - `LOAD_FAILED`
   - `CORS errors`
   - Network errors

## Method 2: Android TV via ADB

If your TV is an Android TV (not just Chromecast):

### Step 1: Enable Developer Options
1. Go to **Settings** > **About**
2. Find **Build Number** and click it 7 times
3. Go back to **Settings** > **Developer Options**
4. Enable **USB Debugging** or **Network Debugging**

### Step 2: Connect via ADB
```bash
# Find your TV's IP address (Settings > Network)
adb connect <TV_IP_ADDRESS>:5555

# Verify connection
adb devices

# Collect logs
adb logcat | grep -E "cast|chromecast|media|hls|m3u8|INVALID|ERROR|LOAD_FAILED" -i
```

### Step 3: Collect Specific Errors
```bash
# Save to file
adb logcat -d | grep -E "cast|chromecast|media|hls|m3u8|INVALID|ERROR|LOAD_FAILED|CORS" -i > tv_logs.txt

# Look for specific errors
grep -i "INVALID_REQUEST" tv_logs.txt
grep -i "LOAD_FAILED" tv_logs.txt
grep -i "CORS" tv_logs.txt
```

## Method 3: Network Monitoring

Monitor network traffic to see what Chromecast is requesting:

1. **Use router logs** (if available)
2. **Check for HTTP errors** (4xx, 5xx responses)
3. **Verify Chromecast can reach your HLS URL**:
   ```bash
   # Test from your computer (should work)
   curl -I "https://tv.danpage.uk/live/playlist.m3u8"
   
   # Check if segments are accessible
   curl -I "<segment-url-from-playlist>"
   ```

## Method 4: Android Device Logs (While Casting)

While casting from your Android device, collect logs on the device:

```bash
# Run the collection script
cd flutter_viewer
./collect_logs.sh

# Select option 2 (Android device logs)
# Or manually:
adb logcat | grep -E "Cast|Chromecast|Media|loadMedia|INVALID|ERROR" -i
```

## Common Errors to Look For

### INVALID_REQUEST
- **Meaning**: Chromecast rejected the media request format
- **Possible causes**:
  - Invalid content type
  - Invalid URL format  
  - Malformed `GoogleCastMediaInformation`
- **Check**: The `contentType` and URL format in Flutter logs

### LOAD_FAILED
- **Meaning**: Chromecast couldn't load the media URL
- **Possible causes**:
  - Network connectivity issue
  - URL not accessible
  - Authentication required but not provided
- **Check**: Verify URL is accessible from Chromecast's network

### CORS Error
- **Meaning**: Cross-origin resource sharing blocked
- **Possible causes**:
  - R2 bucket doesn't allow Chromecast origin
  - Missing CORS headers on segments
- **Check**: R2 CORS configuration

### Media Information: NULL
- **Meaning**: Chromecast rejected the media info we sent
- **Possible causes**:
  - Serialization issue
  - Invalid `GoogleCastMediaInformation` format
  - Chromecast firmware incompatibility
- **Check**: Flutter logs for what we attempted to send

## Quick Debug Commands

```bash
# From flutter_viewer directory
cd flutter_viewer

# Collect Android TV logs (if connected)
./collect_logs.sh
# Select option 3

# Or manually check Android device logs
adb logcat -d | grep -E "Cast|Media|INVALID|ERROR" -i | tail -100

# Watch logs in real-time while testing
flutter logs | grep -E "Cast|Chromecast|Media|NULL|ERROR" -i
```

## What to Share

When reporting issues, include:
1. **TV logs** showing the error (INVALID_REQUEST, LOAD_FAILED, etc.)
2. **Flutter logs** showing what we sent to Chromecast
3. **Network test results** (can Chromecast reach the URL?)
4. **TV/Chromecast model** and firmware version

