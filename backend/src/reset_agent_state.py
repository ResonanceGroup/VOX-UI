#!/usr/bin/env python3
"""
Reset RV Voice Agent to clean state.

Resets both message history AND memory blocks to default values.
Run this before important test sessions to ensure consistent behavior.

Usage:
    python3 src/reset_agent_state.py [--agent-id ID]

Default agent: rv-agent-main (production)
"""

import argparse
from letta_client import Letta

# Default memory block values for rv-agent-main
DEFAULT_MEMORY_BLOCKS = {
    "system": {
        "description": "System-level rules, tool governance, and safety constraints.",
        "value": """You are Milo, the RV voice assistant for Resonance Group. Be warm, concise, and reliable. Keep responses brief for text-to-speech.

## Tool Usage Rules

- ALWAYS use tools when the user asks about RV status or wants to control something.
- NEVER guess or make up device values. Always call read_parameter or list_devices to get real data.
- When in doubt, use a tool. It's better to check than to guess.

## Available Tools

- `read_parameter` — Read current device state (battery, lights, temperature, etc.)
- `write_parameter` — Control a device (turn on/off, adjust brightness, etc.)
- `list_devices` — List all available devices and their status
- `print_content` — Print to receipt printer
- `print_diagnostics` — Print full system diagnostic report

## Safety

- Never control safety-critical systems without explicit user confirmation.
- If unsure about a request, ask for clarification.
- Be honest about limitations.

## Response Style

- Natural, conversational tone for voice output.
- No markdown, bullet points, or special characters.
- Keep answers brief and actionable.
"""
    },
    "persona": {
        "description": "Assistant personality and communication style.",
        "value": """Voice style: friendly concierge. Tone: calm, practical, encouraging. Output style: plain spoken text, no markdown or special characters.

Always use tools when the user asks about RV status. Never guess device values.
"""
    },
    "human": {
        "description": "Key user identity and stable profile traits.",
        "value": """Primary user: Jason Owens. Location/timezone: Toledo, OH (Eastern). Context: RV Smart Control project for Resonance Group. Voice assistant for RV power management and device control.
"""
    },
    "reminders": {
        "description": "Near-term reminders and follow-ups relevant to ongoing RV work.",
        "value": """Active reminders:

- Always use tools when user asks about RV status
- Never guess device values - always call read_parameter or list_devices
- Keep responses brief for TTS compatibility
"""
    },
    "user_preferences": {
        "description": "User preferences for communication and implementation workflow.",
        "value": """Communication style: straightforward, minimal jargon, concrete next actions. During live testing: prefer quick iterative changes over extensive planning. Tool usage: always check real device state before answering questions.
"""
    },
    "chat_history": {
        "description": "Rolling short-form summary for immediate context handoff.",
        "value": """No prior conversation history. This is a fresh session.

Remember: Always use tools when the user asks about RV status. Never guess device values.
"""
    }
}


def reset_agent(agent_id: str, base_url: str = "http://localhost:8283") -> None:
    """Reset agent to clean state."""
    client = Letta(base_url=base_url)
    
    print(f"Resetting agent {agent_id}...")
    
    # 1. Reset message history
    print("\n1. Resetting message history...")
    client.agents.messages.reset(agent_id=agent_id)
    print("   ✓ Message history cleared")

    # 2. Reset memory blocks
    print("\n2. Resetting memory blocks...")
    existing_blocks = {b.label: b for b in client.agents.blocks.list(agent_id=agent_id)}

    for label, defaults in DEFAULT_MEMORY_BLOCKS.items():
        if label in existing_blocks:
            print(f"   Updating '{label}'...")
            client.agents.blocks.update(
                block_label=label,
                agent_id=agent_id,
                description=defaults["description"],
                value=defaults["value"]
            )
        else:
            print(f"   Creating '{label}'...")
            client.agents.blocks.create(
                agent_id=agent_id,
                label=label,
                description=defaults["description"],
                value=defaults["value"]
            )
    
    print("   ✓ Memory blocks reset to defaults")
    
    # 3. Verify
    print("\n3. Verifying reset...")
    messages = list(client.agents.messages.list(agent_id=agent_id, limit=10))
    print(f"   Message count: {len(messages)}")
    
    blocks = list(client.agents.blocks.list(agent_id=agent_id))
    print(f"   Block count: {len(blocks)}")
    
    print("\n✓ Agent reset complete!")
    print(f"  Agent ID: {agent_id}")
    print(f"  Status: Ready for testing")


def main():
    parser = argparse.ArgumentParser(description="Reset RV Voice Agent to clean state")
    parser.add_argument(
        "--agent-id",
        default="agent-87c9def4-a70f-40cf-86f1-7ac37023c24b",
        help="Agent ID to reset (default: rv-agent-main)"
    )
    parser.add_argument(
        "--base-url",
        default="http://localhost:8283",
        help="Letta server URL"
    )
    
    args = parser.parse_args()
    reset_agent(args.agent_id, args.base_url)


if __name__ == "__main__":
    main()
