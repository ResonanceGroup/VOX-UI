#!/usr/bin/env python3
"""
E2E test for VoxUI tool_call_status feature.
Simplified version that uses the LiveKit API to check agent status
and the token service to verify config.
"""

import asyncio
import json
import sys
import time
import urllib.request

# Test 1: Token service is running and returns correct config
print("[TEST 1] Token service health check...")
try:
    req = urllib.request.Request("http://localhost:7882/token?identity=e2e-test", method="GET")
    with urllib.request.urlopen(req, timeout=5) as resp:
        token_data = json.loads(resp.read())
    print(f"  ✅ Token service running. Room: {token_data['room']}")
    print(f"     URL: {token_data['url']}")
    print(f"     ICE servers: {len(token_data.get('iceServers', []))}")
except Exception as e:
    print(f"  ❌ Token service failed: {e}")
    sys.exit(1)

# Test 2: Config endpoint returns Milo profile with Lettabot URL
print("\n[TEST 2] Config endpoint check...")
try:
    req = urllib.request.Request("http://localhost:7882/config", method="GET")
    with urllib.request.urlopen(req, timeout=5) as resp:
        config_data = json.loads(resp.read())
    llm_url = config_data.get("llm_base_url", "")
    llm_model = config_data.get("llm_model", "")
    print(f"  LLM URL: {llm_url}")
    print(f"  LLM model: {llm_model}")
    if "192.168.122" in llm_url and ":8080" in llm_url:
        print(f"  ✅ Milo profile correctly points to Lettabot API")
    else:
        print(f"  ⚠️ LLM URL doesn't match Lettabot pattern")
except Exception as e:
    print(f"  ❌ Config endpoint failed: {e}")

# Test 3: Lettabot API is accessible
print("\n[TEST 3] Lettabot API health check...")
try:
    req = urllib.request.Request("http://192.168.122.116:8080/v1/models", method="GET")
    req.add_header("Authorization", "Bearer f15b903e50429d097afb6bdbbbeaa7761bea329185cb6a06a21fb95049630476")
    with urllib.request.urlopen(req, timeout=10) as resp:
        models_data = json.loads(resp.read())
    models = [m["id"] for m in models_data.get("data", [])]
    print(f"  Models: {models}")
    if "Milo" in models:
        print(f"  ✅ Milo model available on Lettabot API")
    else:
        print(f"  ❌ Milo model NOT found in Lettabot API")
except Exception as e:
    print(f"  ❌ Lettabot API failed: {e}")

# Test 4: Lettabot API streaming produces tool_call chunks
print("\n[TEST 4] Lettabot streaming test (tool_call chunks)...")
print("  Sending 'What time is it?' to Milo via Lettabot API...")
print("  (This may take 30-60s due to agent processing)")
try:
    import http.client
    conn = http.client.HTTPConnection("192.168.122.116", 8080, timeout=300)
    body = json.dumps({
        "model": "Milo",
        "messages": [{"role": "user", "content": "What time is it right now?"}],
        "stream": True,
    })
    headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer f15b903e50429d097afb6bdbbbeaa7761bea329185cb6a06a21fb95049630476",
    }
    conn.request("POST", "/v1/chat/completions", body, headers)
    resp = conn.getresponse()
    
    tool_call_chunks = []
    text_chunks = []
    all_chunks = []
    
    buffer = ""
    start_time = time.time()
    
    while True:
        chunk = resp.read(1)
        if not chunk:
            break
        buffer += chunk.decode("utf-8", errors="replace")
        
        while "\n\n" in buffer:
            line, buffer = buffer.split("\n\n", 1)
            line = line.strip()
            if not line or line == "data: [DONE]":
                if line == "data: [DONE]":
                    print(f"  Stream complete [DONE]")
                continue
            
            if line.startswith("data: "):
                try:
                    data = json.loads(line[6:])
                    all_chunks.append(data)
                    
                    if data.get("choices"):
                        choice = data["choices"][0]
                        delta = choice.get("delta", {})
                        finish_reason = choice.get("finish_reason")
                        
                        if delta.get("tool_calls"):
                            for tc in delta["tool_calls"]:
                                func = tc.get("function", {})
                                name = func.get("name", "unknown")
                                tool_call_chunks.append(name)
                                print(f"  🔧 TOOL CALL: {name}")
                        
                        if delta.get("content"):
                            text_chunks.append(delta["content"])
                        
                        if finish_reason:
                            print(f"  Finish reason: {finish_reason}")
                except json.JSONDecodeError:
                    pass
        
        # Timeout after 120s
        if time.time() - start_time > 120:
            print("  ⏰ Timeout after 120s")
            break
    
    elapsed = time.time() - start_time
    print(f"\n  Stream completed in {elapsed:.1f}s")
    print(f"  Total chunks: {len(all_chunks)}")
    print(f"  Tool call chunks: {len(tool_call_chunks)}")
    print(f"  Text chunks: {len(text_chunks)}")
    
    if tool_call_chunks:
        print(f"\n  ✅ PASS: Tool call chunks received: {tool_call_chunks}")
    else:
        print(f"\n  ❌ FAIL: No tool call chunks in stream")
        print(f"  (The Lettabot API may not emit tool_call chunks for this query)")
    
    full_text = "".join(text_chunks)
    if full_text:
        print(f"  Response text: {full_text[:200]}...")
    
    conn.close()
except Exception as e:
    print(f"  ❌ Streaming test failed: {e}")
    import traceback
    traceback.print_exc()

# Test 5: Check VoxUI agent process is running
print("\n[TEST 5] VoxUI agent process check...")
try:
    import subprocess
    result = subprocess.run(["pgrep", "-f", "python3 src/main.py"], capture_output=True, text=True)
    pids = result.stdout.strip().split("\n") if result.stdout.strip() else []
    print(f"  Agent PIDs: {pids}")
    if pids and pids[0]:
        print(f"  ✅ VoxUI agent is running")
    else:
        print(f"  ❌ VoxUI agent is NOT running")
except Exception as e:
    print(f"  ⚠️ Could not check agent process: {e}")

# Test 6: Check agent logs for LettaLLM initialization
print("\n[TEST 6] Agent log check (LettaLLM usage)...")
try:
    result = subprocess.run(
        ["tail", "-100", "/tmp/voxui-agent2.log"],
        capture_output=True, text=True, timeout=5,
    )
    log = result.stdout
    if "Using LettaLLM" in log:
        print(f"  ✅ Agent logs show LettaLLM being used")
    elif "Using openai.LLM" in log:
        print(f"  ❌ Agent is using openai.LLM (not LettaLLM)")
    else:
        print(f"  ⚠️ No LLM selection found in recent logs")
    
    if "tool_call_status" in log:
        print(f"  ✅ tool_call_status found in logs")
    else:
        print(f"  ⚠️ No tool_call_status in recent logs")
    
    # Check for errors
    errors = [line for line in log.split("\n") if "ERROR" in line or "Traceback" in line]
    if errors:
        print(f"  ❌ Errors found in logs:")
        for e in errors[:5]:
            print(f"     {e[:150]}")
except Exception as e:
    print(f"  ⚠️ Could not check logs: {e}")

# Summary
print("\n" + "=" * 60)
print("E2E TEST SUMMARY")
print("=" * 60)
print("The Lettabot API streaming test (TEST 4) is the key test.")
print("If tool_call chunks appear in the SSE stream, then:")
print("  - The Lettabot API emits them correctly")
print("  - The LettaLLM plugin should parse them")
print("  - The Flutter UI should receive tool_call_status data messages")
print()
print("Next step: Jason refreshes VoxUI and asks 'What time is it?'")
print("The orb status should show 'Getting the time' and a tile")
print("should appear in the chat tray.")
