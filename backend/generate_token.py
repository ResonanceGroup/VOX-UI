#!/usr/bin/env python3
"""
Simple script to generate a long-lived LiveKit token for local development
"""
from livekit import api
import os
from datetime import timedelta

# Your LiveKit credentials
API_KEY = "devkey"
API_SECRET = "secret"

# Token configuration
ROOM_NAME = "test-room"
IDENTITY = "flutter-user"
VALIDITY_HOURS = 87600  # 10 years

# Create token
token = api.AccessToken(API_KEY, API_SECRET) \
    .with_identity(IDENTITY) \
    .with_name("Flutter User") \
    .with_grants(api.VideoGrants(
        room_join=True,
        room=ROOM_NAME,
        can_publish=True,
        can_subscribe=True,
    )) \
    .with_ttl(timedelta(hours=VALIDITY_HOURS))

jwt_token = token.to_jwt()

print("\n" + "="*60)
print("LiveKit Token Generated Successfully!")
print("="*60)
print(f"\nRoom: {ROOM_NAME}")
print(f"Identity: {IDENTITY}")
print(f"Valid for: {VALIDITY_HOURS} hours (~10 years)")
print(f"\nYour Token:\n{jwt_token}")
print("\n" + "="*60)
print("\nCopy this token to your Flutter app settings!")
print("="*60 + "\n")