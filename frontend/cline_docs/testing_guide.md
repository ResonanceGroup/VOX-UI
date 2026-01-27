# VOX-UI Testing Guide

## System Status Check

### Prerequisites Running:
- ✅ Speaches (STT): port 8000
- ✅ Kokoro TTS: port 8880  
- ✅ Ollama: Model `granite4:1b-h` loaded
- 🔄 LiveKit Backend: Starting...

## Testing Steps

### 1. Backend Startup
```bash
cd A:/Software/livekit-offline-agent
.\venv\Scripts\activate
python src/app.py dev
```

**Expected Output:**
```
LiveKit Dev Server running at: http://localhost:7880
Room: <room-name>
Token: <access-token>
```

### 2. Configure Flutter App

**In Settings Screen:**
1. Navigate to Settings (drawer menu)
2. Expand "Voice Agent" section
3. Fill in:
   - **Server URL**: `ws://localhost:7880` (from backend output)
   - **LiveKit Token**: Copy token from backend output
   - **System Prompt**: (default is fine)
   - **Model**: `granite4:1b-h` (matches backend)
   - **Voice**: `af_heart` (default)
4. Click "Save Changes"

### 3. Run Flutter App
```bash
cd A:/Software/VOX-UI
flutter run -d windows
```

### 4. Test Voice Interaction

**Connection Flow:**
1. App auto-connects on startup
2. Watch orb state transitions:
   - `disconnected` → `connecting` → `connected_with_agent`
3. Check app bar for connection status

**Voice Testing:**
1. Click microphone button to ensure unmuted
2. Speak: "Hello, can you hear me?"
3. Watch orb states:
   - `idle` → `processing` (agent thinking)
   - `processing` → `idle` (response complete)
4. Listen for TTS response

**Text Testing:**
1. Type message in text input
2. Click send button
3. Watch for agent response

**Expected Orb Behavior:**
- **Disconnected** (gray): No connection
- **Connecting** (yellow/muted): Initial connection
- **Idle** (blue): Connected, waiting
- **Processing** (purple): Agent responding
- **Listening** (green): User speaking (if implemented)
- **Muted** (orange): Microphone off

### 5. Debugging

**If connection fails:**
- Check backend terminal for errors
- Verify token is correctly copied
- Ensure no firewall blocking port 7880
- Try "Settings" button in error message

**If no audio:**
- Check microphone permissions
- Verify Speaches/Kokoro containers running
- Check backend terminal for STT/TTS errors

**If orb not responding:**
- Check browser console (F12) for JavaScript errors
- Verify orb HTML asset loads correctly
- Check LiveKit service logs in Flutter debug console

## Success Criteria

✅ Backend starts without errors  
✅ Flutter app connects successfully  
✅ Orb shows "connected_with_agent" state  
✅ Can send text messages  
✅ Agent responds with TTS  
✅ Microphone mute button works  
✅ Settings persist across restarts  

## Next Steps After Success

1. Test different models (change .env, restart backend)
2. Test custom system prompts
3. Test different TTS voices
4. Add tool functions to agent
5. Implement real-time voice visualization