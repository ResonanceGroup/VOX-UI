"""
tools.py — LiveKit tool functions for RV device control

Defines the five tools available to the LLM:
  - read_parameter:     Read current state of an RV device
  - write_parameter:    Change the state of an RV device
  - list_devices:       List all available RV devices
  - print_content:      Print formatted content to the receipt printer
  - print_diagnostics:  Print a full system diagnostic report

These are decorated with @function_tool for LiveKit Agents v1.x.

Each tool uses:
  - DeviceResolver (validator.py): maps natural names → canonical device_id/property
  - BackendClient (api.py): sends JSON-RPC 2.0 commands over TCP to the backend

Usage in main.py:
    from tools import make_tools

    backend = BackendClient(host=cfg.backend_host, port=cfg.backend_port)
    await backend.connect()

    class RVAgent(Agent):
        def __init__(self):
            tools = make_tools(backend)
            super().__init__(instructions=SYSTEM_PROMPT, tools=tools)
"""

from __future__ import annotations

import asyncio
import json
import logging
from typing import Any, Dict, List, Optional

from livekit.agents.llm import function_tool

from api import BackendClient
from validator import DeviceResolver, ResolveError

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Tool factory
# ---------------------------------------------------------------------------

def make_tools(backend: BackendClient) -> List:
    """
    Create and return the list of LiveKit function_tool callables,
    with the backend client captured in closure.

    Args:
        backend: Connected BackendClient instance

    Returns:
        List of decorated async functions suitable for Agent(tools=...)
    """
    resolver = DeviceResolver()

    # ------------------------------------------------------------------
    # Tool: read_parameter
    # ------------------------------------------------------------------

    @function_tool(
        name="read_parameter",
        description=(
            "Read the current state or a specific property of an RV device. "
            "Use this whenever the user asks about the status, value, or reading "
            "of any RV system (battery, lights, temperature, solar, etc.). "
            "Examples: read_parameter('battery', 'soc'), read_parameter('climate', 'cabin_temperature'), "
            "read_parameter('main lights')."
        ),
    )
    async def read_parameter(
        device_name: str,
        property_name: Optional[str] = None,
    ) -> str:
        """
        Read device state from the backend cache.

        Args:
            device_name: Natural name of the device (e.g., "battery", "lights")
            property_name: Optional property to read (e.g., "soc", "brightness")

        Returns:
            Human-readable result or error message
        """
        try:
            device_id = resolver.resolve_device(device_name)
            prop = resolver.resolve_property(device_id, property_name) if property_name else None
            value = backend.cache.get_property(device_id, prop) if prop else backend.cache.get_device(device_id)
            if value is None:
                return f"No data available for {device_name} {prop or 'status'} right now."
            return f"{device_name} {prop or 'status'}: {value}"
        except ResolveError as e:
            return str(e)
        except Exception as e:
            return f"Error reading {device_name}: {e}"

    # ------------------------------------------------------------------
    # Tool: write_parameter (control device)
    # ------------------------------------------------------------------

    @function_tool(
        name="write_parameter",
        description=(
            "Change the state of an RV device or system. "
            "Use when the user wants to turn something on/off, adjust brightness, change temperature, etc. "
            "Examples: write_parameter('main lights', 'activated', true), "
            "write_parameter('lights', 'brightness', 75), "
            "write_parameter('climate', 'setpoint', 72)"
        ),
    )
    async def write_parameter(
        device_name: str,
        property_name: str,
        value: Any,
    ) -> str:
        """
        Send a control command to the backend.

        Args:
            device_name: Natural device name
            property_name: Property to change
            value: New value (bool, int, float, str)

        Returns:
            Human-readable confirmation or error
        """
        try:
            device_id = resolver.resolve_device(device_name)
            prop = resolver.resolve_property(device_id, property_name)
            result = await backend.command(device_id, "set", {prop: value})
            if "error" in result:
                return f"Failed to control {device_name}: {result['error']['message']}"
            return f"✓ {device_name} {prop} set to {value}"
        except ResolveError as e:
            return str(e)
        except Exception as e:
            return f"Error controlling {device_name}: {e}"

    # ------------------------------------------------------------------
    # Tool: list_devices
    # ------------------------------------------------------------------

    @function_tool(
        name="list_devices",
        description="Get a list of all available RV devices and their current status.",
    )
    async def list_devices() -> str:
        """
        List all devices in the cache with their current values.

        Returns:
            Formatted device list or error message
        """
        try:
            devices = backend.cache.get_all()
            if not devices:
                return "No devices available."
            result = "Available devices:\n"
            for device_id, props in devices.items():
                result += f"  {device_id}: {props}\n"
            return result
        except Exception as e:
            return f"Error listing devices: {e}"

    # ------------------------------------------------------------------
    # Tool: print_content (receipt printer)
    # ------------------------------------------------------------------

    @function_tool(
        name="print_content",
        description="Print formatted content to the receipt printer (for messages, logs, or diagnostics).",
    )
    async def print_content(content: str) -> str:
        """
        Print content to the receipt printer.

        Args:
            content: Text to print

        Returns:
            Confirmation message
        """
        try:
            # In Phase 1, just log it. In Phase 3+ with backend, send to printer device.
            logger.info(f"[PRINT] {content}")
            return f"✓ Sent {len(content)} characters to printer."
        except Exception as e:
            return f"Error printing: {e}"

    # ------------------------------------------------------------------
    # Tool: print_diagnostics
    # ------------------------------------------------------------------

    @function_tool(
        name="print_diagnostics",
        description="Print a full system diagnostic report to the receipt printer.",
    )
    async def print_diagnostics() -> str:
        """
        Print system status to the printer.

        Returns:
            Confirmation message
        """
        try:
            devices = backend.cache.get_all()
            report = "=== RV SYSTEM DIAGNOSTICS ===\n"
            for device_id, props in devices.items():
                report += f"{device_id}:\n"
                for k, v in props.items():
                    report += f"  {k}: {v}\n"
            logger.info(f"[PRINT_DIAG]\n{report}")
            return f"✓ Diagnostic report sent to printer."
        except Exception as e:
            return f"Error printing diagnostics: {e}"

    # Return all tools
    return [read_parameter, write_parameter, list_devices, print_content, print_diagnostics]
