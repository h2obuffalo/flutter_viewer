# Chromecast Debugging Guide

## Enhanced Logging

The CastService now includes enhanced logging for:
- Media status updates with detailed information
- Idle reason details
- Playback rate and position
- Media session ID
- Error handling with stack traces

## Collecting Logs

### iOS Simulator Logs

```bash
# Get device UDID
xcrun simctl list devices | grep "Booted"

# Collect logs (replace UDID with your device UDID)
xcrun simctl spawn <UDID> log stream --predicate 'processImagePath contains "Runner" OR eventMessage contains "Cast" OR eventMessage contains "Chromecast"' --level=debug

# Or use the helper script
./collect_logs.sh
# Select option 1
```

### iOS Physical Device Logs

1. Open Xcode
2. Window > Devices and Simulators
3. Select your device
4. Click "View Device Logs"
5. Filter for "Cast" or "Chromecast"

### Android Device Logs

```bash
# Check connected devices
adb devices

# Collect Chromecast-related logs
adb logcat | grep -E "Chromecast|Cast|CastService|flutter_chrome_cast|GoogleCast|MediaStatus|loadMedia|play"

# Save to file
adb logcat | grep -E "Chromecast|Cast|CastService|flutter_chrome_cast|GoogleCast|MediaStatus|loadMedia|play" > android_chromecast_logs.txt

# Or use the helper script
./collect_logs.sh
# Select option 2
```

### TV/Chromecast Logs

```bash
# If your TV is connected via ADB
adb logcat | grep -E "cast|chromecast|media|hls|m3u8" -i

# Or use Chrome DevTools
# 1. Open Chrome
# 2. Go to chrome://inspect
# 3. Look for your Chromecast device
# 4. Click "inspect" to view console logs

# Or use the helper script
./collect_logs.sh
# Select option 3
```

### Flutter App Logs

```bash
# View all logs
flutter logs

# Filter for Cast-related logs
flutter logs | grep -E "Cast|Chromecast|Media|📺|❌|✅|⚠️"

# Or specify device
flutter logs -d <device-id>
```

## What to Look For

### Key Log Messages

1. **Connection Issues:**
   - `❌ No active cast session`
   - `❌ Session still not ready after wait`
   - `Error connecting to device`

2. **Media Loading Issues:**
   - `❌ Error loading media`
   - `⚠️ WARNING: Media Information is NULL!`
   - `❌ Error starting HLS cast`

3. **Playback Issues:**
   - `⚠️ Chromecast is idle - stream may have failed to load`
   - `Idle Reason:` (check what reason is given)
   - `❌ Stream error detected`
   - `⚠️ Error sending play command`

4. **Media Status Updates:**
   - `📺 Chromecast Media Status Update:`
   - `Player State:` (should be `playing` not `idle`)
   - `Media Information:` (should be `Present` not `NULL`)

### Common Error Patterns

1. **Idle Reason: ERROR or INTERRUPTED**
   - Usually means the stream URL is invalid or unreachable
   - Check if the HLS URL is accessible from the Chromecast device
   - Verify authentication token is valid

2. **Media Information is NULL**
   - The loadMedia call may have failed
   - Check for errors in the loadMedia try-catch block

3. **Session Not Ready**
   - The Chromecast session may not be fully established
   - Try increasing the delay before loading media

## Debugging Steps

1. **Enable Enhanced Logging:**
   - The code now includes detailed logging
   - Run the app and attempt to cast
   - Watch the logs in real-time

2. **Check Connection:**
   - Verify device is discovered
   - Check session is established
   - Look for "✅ Connected to" message

3. **Check Media Loading:**
   - Verify "📤 Loading media" message appears
   - Check for "✅ Media load request sent successfully"
   - Look for any errors in loadMedia

4. **Check Playback:**
   - Verify "▶️ Sending play command" message
   - Check media status updates
   - Look for idle reason if playback fails

5. **Check Stream URL:**
   - Verify the HLS URL is accessible
   - Test URL in browser or VLC
   - Check authentication token is valid

## Quick Test Commands

```bash
# Test HLS URL accessibility (from Chromecast network)
curl -I "https://your-hls-url.m3u8?token=your-token"

# Check if Chromecast can reach the URL
# (Use Chrome DevTools on Chromecast to test)

# Monitor network traffic
# Use Wireshark or router logs to see if Chromecast is requesting the stream
```

## Reporting Issues

When reporting issues, please include:

1. **Platform:** iOS/Android/TV
2. **Device:** Model and OS version
3. **Logs:** Relevant log excerpts
4. **Steps to Reproduce:** What you did before the error
5. **Expected Behavior:** What should happen
6. **Actual Behavior:** What actually happened
7. **Media Status:** Player state and idle reason if available

## Example Log Output

Good (working):
```
✅ Connected to Living Room TV
📤 Loading media with HLS configuration...
✅ Media load request sent successfully
▶️ Sending play command...
✅ Play command sent to Chromecast
📺 Chromecast Media Status Update:
   Player State: GoogleCastPlayerState.buffering
   Media Information: Present
▶️ Chromecast is playing
```

Bad (not working):
```
✅ Connected to Living Room TV
📤 Loading media with HLS configuration...
❌ Error loading media: [error details]
⚠️ Chromecast is idle - stream may have failed to load
   Idle Reason: ERROR
   Media Information: NULL
```



