"""
mcp_server.py — MCP Server for RV Tool Calling

Exposes RV device control tools via the Model Context Protocol (MCP).
This allows Letta agents to call tools directly without going through
the LiveKit proxy pattern.

The server runs as part of the AI backend process and calls the existing
tools.py implementation.

Tools exposed:
  - read_parameter: Read device state
  - write_parameter: Control device  
  - list_devices: List all devices
  - print_content: Print to receipt printer
  - print_diagnostics: Print diagnostic report

Usage:
    # The server is started automatically by main.py
    # It runs on the configured MCP_PORT (default: 8284)
"""

from __future__ import annotations

import asyncio
import logging
import uvicorn
from typing import Any, Optional, Union

from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings

from api import BackendClient
from validator import DeviceResolver, ResolveError

logger = logging.getLogger(__name__)


class RVMCPServer:
    """
    MCP Server that exposes RV device control tools.
    
    The server wraps the existing tools.py implementation, calling
    the same BackendClient and DeviceResolver.
    """
    
    def __init__(self, backend: BackendClient, port: int = 8284):
        """
        Initialize the MCP server.
        
        Args:
            backend: Connected BackendClient instance
            port: Port to run the MCP server on
        """
        self.backend = backend
        self.resolver = DeviceResolver()
        self.port = port
        
        # Create FastMCP server
        # Allow connections from localhost and the Jetson's LAN IP (needed for Letta in Docker)
        self.mcp = FastMCP(
            "RV Tools",
            stateless_http=True,
            json_response=True,
            transport_security=TransportSecuritySettings(
                allowed_hosts=["127.0.0.1:*", "localhost:*", "[::1]:*", "10.0.0.200:*"],
            ),
        )
        
        # Register tools
        self._register_tools()

    def _log_tool_invocation(self, tool_name: str, **kwargs: Any) -> None:
        """Log an MCP tool invocation with its arguments."""
        arg_text = ", ".join(f"{key}={value!r}" for key, value in kwargs.items())
        logger.info(f"[MCP] {tool_name} called ({arg_text})")

    def _log_tool_result(self, tool_name: str, result: str) -> str:
        """Log and return an MCP tool result."""
        logger.info(f"[MCP] {tool_name} returned: {result}")
        return result
    
    def _register_tools(self) -> None:
        """Register all RV tools with the MCP server."""
        
        @self.mcp.tool(
            name="read_parameter",
            description=(
                "Read the current state or a specific property of an RV device. "
                "Use this when the user asks about the status, value, or reading "
                "of any RV system (battery, lights, temperature, solar, etc.). "
                "\n\n"
                "Device names: bank1, bank2, solar, shore_power, inverter1, inverter2, "
                "climate, fan, furnace, main_lights, galley_lights, water, obd_reader. "
                "\n\n"
                "Common properties: soc (battery charge %), voltage, current, power, "
                "temperature, cabin_temperature, brightness, activated, etc. "
                "\n\n"
                "Examples: read_parameter(device_name='bank1', property_name='soc'), "
                "read_parameter(device_name='climate', property_name='cabin_temperature')."
            ),
        )
        async def read_parameter(
            device_name: str,
            property_name: Optional[str] = None,
        ) -> str:
            """
            Read device state from the backend cache.

            Args:
                device_name: Natural name of the device (e.g., "bank1", "bank2", "solar", "climate")
                property_name: Property to read (e.g., "soc", "voltage", "cabin_temperature"). 
                               If None, returns all properties for the device.

            Returns:
                Human-readable result or error message
            """
            self._log_tool_invocation(
                "read_parameter",
                device_name=device_name,
                property_name=property_name,
            )
            try:
                device_id = self.resolver.resolve_device(device_name)
                prop = self.resolver.resolve_property(device_id, property_name) if property_name else None
                value = self.backend.cache.get_property(device_id, prop) if prop else self.backend.cache.get_device(device_id)
                if value is None:
                    return self._log_tool_result(
                        "read_parameter",
                        f"No data available for {device_name} {prop or 'status'} right now.",
                    )
                return self._log_tool_result(
                    "read_parameter",
                    f"{device_name} {prop or 'status'}: {value}",
                )
            except ResolveError as e:
                return self._log_tool_result("read_parameter", str(e))
            except Exception as e:
                logger.error(f"Error in read_parameter: {e}")
                return self._log_tool_result("read_parameter", f"Error reading {device_name}: {e}")

        @self.mcp.tool(
            name="write_parameter",
            description=(
                "Change the state of an RV device or system. "
                "Use when the user wants to turn something on/off, adjust brightness, change temperature, etc. "
                "\n\n"
                "Controllable devices: inverter1, inverter2, climate, fan, furnace, "
                "main_lights, galley_lights, water. "
                "\n\n"
                "Common properties: activated (true/false), brightness (0-100), "
                "set_temperature, mode (climate: off/heating/cooling/auto/fan_only), pump_activated. "
                "To turn climate off, set mode to 'off' — do not use the enabled property. "
                "\n\n"
                "Examples: write_parameter(device_name='main_lights', property_name='activated', value=True), "
                "write_parameter(device_name='main_lights', property_name='brightness', value=75)."
            ),
        )
        async def write_parameter(
            device_name: str,
            property_name: str,
            value: Union[bool, int, float, str],
        ) -> str:
            """
            Send a control command to the backend.

            Args:
                device_name: Natural device name (e.g., "main_lights", "climate", "fan")
                property_name: Property to change (e.g., "activated", "brightness", "set_temperature")
                value: New value (bool, int, float, or str)

            Returns:
                Human-readable confirmation or error
            """
            self._log_tool_invocation(
                "write_parameter",
                device_name=device_name,
                property_name=property_name,
                value=value,
            )
            try:
                device_id = self.resolver.resolve_device(device_name)
                prop = self.resolver.resolve_property(device_id, property_name)
                future = self.backend.send_command(device_id, "set", {prop: value})
                result = await asyncio.wrap_future(future)
                if "error" in result:
                    return self._log_tool_result(
                        "write_parameter",
                        f"Failed to control {device_name}: {result['error']['message']}",
                    )
                return self._log_tool_result(
                    "write_parameter",
                    f"✓ {device_name} {prop} set to {value}",
                )
            except ResolveError as e:
                return self._log_tool_result("write_parameter", str(e))
            except Exception as e:
                logger.error(f"Error in write_parameter: {e}")
                return self._log_tool_result("write_parameter", f"Error controlling {device_name}: {e}")

        @self.mcp.tool(
            name="list_devices",
            description=(
                "Get a list of all available RV devices and their current status. "
                "Use when the user asks what devices are available or wants a general "
                "overview of all systems."
            ),
        )
        async def list_devices() -> str:
            """
            List all devices in the cache with their current values.

            Returns:
                Formatted device list or error message
            """
            self._log_tool_invocation("list_devices")
            try:
                devices = self.backend.cache.get_all()
                if not devices:
                    return self._log_tool_result("list_devices", "No devices available.")
                result = "Available devices:\n"
                for device_id, props in devices.items():
                    result += f"  {device_id}: {props}\n"
                return self._log_tool_result("list_devices", result)
            except Exception as e:
                logger.error(f"Error in list_devices: {e}")
                return self._log_tool_result("list_devices", f"Error listing devices: {e}")

        @self.mcp.tool(
            name="print_content",
            description=(
                "Print a titled note to the receipt printer. "
                "Use when the user wants to print a message, instructions, or any freeform text."
            ),
        )
        async def print_content(title: str, body: str) -> str:
            """
            Print a titled note to the receipt printer via the Pi backend.

            Args:
                title: Heading for the note (e.g. "REMINDER", "INSTRUCTIONS")
                body:  Body text to print

            Returns:
                Confirmation or error message
            """
            try:
                future = self.backend.send_command("printer", "print_note", {"title": title, "body": body})
                result = future.result(timeout=8)
                if result.get("error"):
                    return f"Printer error: {result['error']['message']}"
                logger.info(f"[PRINT] {title}: {body[:60]}")
                return "✓ Note sent to printer."
            except Exception as e:
                logger.error(f"Error in print_content: {e}")
                return f"Error printing: {e}"

        @self.mcp.tool(
            name="print_diagnostics",
            description=(
                "Print a full system diagnostic report to the receipt printer. "
                "The backend collects all device data and formats the report automatically. "
                "Use when the user wants a printed summary of all RV system status."
            ),
        )
        async def print_diagnostics() -> str:
            """
            Trigger the backend to print a full system diagnostic report.
            The Pi backend collects all telemetry and formats the receipt — no data needed from the AI.

            Returns:
                Confirmation or error message
            """
            try:
                future = self.backend.send_command("system", "print", {})
                result = future.result(timeout=8)
                if result.get("error"):
                    return f"Printer error: {result['error']['message']}"
                logger.info("[PRINT_DIAG] system.print dispatched to backend")
                return "✓ Diagnostic report sent to printer."
            except Exception as e:
                logger.error(f"Error in print_diagnostics: {e}")
                return f"Error printing diagnostics: {e}"

        @self.mcp.tool(
            name="print_alert",
            description=(
                "Print an urgent notice to the receipt printer. "
                "Use for important notifications: low battery, system faults, safety warnings, or informational updates. "
                "severity must be 'info' (normal), 'warning' (bold), or 'critical' (largest, bold — use sparingly). "
                "Example: low battery warning, inverter fault, shore power disconnected."
            ),
        )
        async def print_alert(severity: str, title: str, message: str) -> str:
            """
            Print a severity-styled alert to the receipt printer.

            Args:
                severity: 'info', 'warning', or 'critical'
                title:    Alert heading (e.g. "BATTERY LOW")
                message:  Alert body text (may include newlines for paragraphs)

            Returns:
                Confirmation or error message
            """
            try:
                future = self.backend.send_command("printer", "print_alert", {
                    "severity": severity, "title": title, "message": message
                })
                result = future.result(timeout=8)
                if result.get("error"):
                    return f"Printer error: {result['error']['message']}"
                logger.info(f"[PRINT_ALERT] {severity}: {title}")
                return "✓ Alert printed."
            except Exception as e:
                logger.error(f"Error in print_alert: {e}")
                return f"Error printing alert: {e}"

        @self.mcp.tool(
            name="print_status_report",
            description=(
                "Print a custom formatted key-value status table to the receipt printer. "
                "Use when the user asks for a printed snapshot of specific data — e.g. just power, "
                "just climate, or a custom AI-composed summary. "
                "Provide a title and a list of {\"label\": str, \"value\": str} items. "
                "For a full system diagnostic, use print_diagnostics instead."
            ),
        )
        async def print_status_report(title: str, items: list[dict]) -> str:
            """
            Print a formatted key-value status table.

            Args:
                title: Report heading (e.g. "POWER STATUS")
                items: List of {"label": str, "value": str} dicts in display order.
                       Example: [{"label": "Battery SOC", "value": "82%"}, ...]

            Returns:
                Confirmation or error message
            """
            try:
                future = self.backend.send_command("printer", "print_status_report", {
                    "title": title, "items": items
                })
                result = future.result(timeout=8)
                if result.get("error"):
                    return f"Printer error: {result['error']['message']}"
                logger.info(f"[PRINT_STATUS] {title} — {len(items)} rows")
                return "✓ Status report printed."
            except Exception as e:
                logger.error(f"Error in print_status_report: {e}")
                return f"Error printing status report: {e}"

        @self.mcp.tool(
            name="print_welcome",
            description=(
                "Print a personalized welcome greeting to the receipt printer. "
                "Use when greeting a new occupant or after an NFC check-in event. "
                "Optionally include a QR code URL (e.g. link to the control app or a welcome guide)."
            ),
        )
        async def print_welcome(name: str, message: str, qr_data: str = "") -> str:
            """
            Print a personalized welcome greeting.

            Args:
                name:    Occupant's display name (e.g. "Jason")
                message: Greeting body — include current RV status, temp, etc.
                qr_data: Optional URL for QR code (leave empty to omit)

            Returns:
                Confirmation or error message
            """
            try:
                params: dict = {"name": name, "message": message}
                if qr_data:
                    params["qr_data"] = qr_data
                future = self.backend.send_command("printer", "print_welcome", params)
                result = future.result(timeout=8)
                if result.get("error"):
                    return f"Printer error: {result['error']['message']}"
                logger.info(f"[PRINT_WELCOME] Welcome, {name}")
                return "✓ Welcome message printed."
            except Exception as e:
                logger.error(f"Error in print_welcome: {e}")
                return f"Error printing welcome: {e}"

        @self.mcp.tool(
            name="print_daily_briefing",
            description=(
                "Print a morning daily briefing with grouped sections to the receipt printer. "
                "Use when the user asks for a morning summary, daily briefing, or start-of-day overview. "
                "Compose sections from live device data — e.g. POWER (battery SOC, solar), "
                "CLIMATE (cabin temp, humidity), ENGINE (RPM, coolant), TODAY (reminders). "
                "Each section has a title and a list of label/value rows."
            ),
        )
        async def print_daily_briefing(date: str, sections: list[dict]) -> str:
            """
            Print a morning briefing with grouped sections.

            Args:
                date:     Human-readable date (e.g. "Monday, April 6, 2026")
                sections: List of section dicts:
                          [{"title": "POWER", "items": [{"label": "Battery", "value": "82%"}, ...]}, ...]

            Returns:
                Confirmation or error message
            """
            try:
                future = self.backend.send_command("printer", "print_daily_briefing", {
                    "date": date, "sections": sections
                })
                result = future.result(timeout=8)
                if result.get("error"):
                    return f"Printer error: {result['error']['message']}"
                logger.info(f"[PRINT_BRIEFING] {date} — {len(sections)} sections")
                return "✓ Daily briefing printed."
            except Exception as e:
                logger.error(f"Error in print_daily_briefing: {e}")
                return f"Error printing briefing: {e}"

        @self.mcp.tool(
            name="print_sequence_confirmation",
            description=(
                "Print a confirmation slip after completing a multi-step sequence of actions. "
                "Use after executing a series of commands (e.g. activating climate + fan + setting temp). "
                "Lists each action with its outcome status. "
                "status values: 'success', 'warning', 'error', 'info'."
            ),
        )
        async def print_sequence_confirmation(sequence_name: str, actions: list[dict]) -> str:
            """
            Print a post-sequence confirmation receipt.

            Args:
                sequence_name: Name of the completed sequence (e.g. "COOL DOWN")
                actions:       List of action dicts:
                               [{"text": "AC turned ON", "status": "success"}, ...]
                               status: 'success', 'warning', 'error', 'info'

            Returns:
                Confirmation or error message
            """
            try:
                future = self.backend.send_command("printer", "print_sequence_confirmation", {
                    "sequence_name": sequence_name, "actions": actions
                })
                result = future.result(timeout=8)
                if result.get("error"):
                    return f"Printer error: {result['error']['message']}"
                logger.info(f"[PRINT_SEQ_CONFIRM] {sequence_name} — {len(actions)} actions")
                return "✓ Sequence confirmation printed."
            except Exception as e:
                logger.error(f"Error in print_sequence_confirmation: {e}")
                return f"Error printing sequence confirmation: {e}"

        @self.mcp.tool(
            name="print_begin_process",
            description=(
                "Start a live process session on the receipt printer — prints a header and leaves paper open. "
                "Use at the start of a multi-step operation where you want the occupant to see each step "
                "printed in real time as it happens. Must call print_append_step and print_finish_process to complete. "
                "Example: beginning a battery balancing procedure, an NFC sequence, or a system check."
            ),
        )
        async def print_begin_process(title: str, subtitle: str = "") -> str:
            """
            Open a live process session on the printer (prints header, no cut).

            Args:
                title:    Process name (e.g. "BATTERY CHECK")
                subtitle: Optional secondary description line

            Returns:
                Confirmation or error message
            """
            try:
                params: dict = {"title": title}
                if subtitle:
                    params["subtitle"] = subtitle
                future = self.backend.send_command("printer", "begin_process", params)
                result = future.result(timeout=8)
                if result.get("error"):
                    return f"Printer error: {result['error']['message']}"
                logger.info(f"[PRINT_PROCESS_BEGIN] {title}")
                return "✓ Process session started on printer."
            except Exception as e:
                logger.error(f"Error in print_begin_process: {e}")
                return f"Error starting process: {e}"

        @self.mcp.tool(
            name="print_append_step",
            description=(
                "Append one step line to the currently open process receipt session. "
                "Must call print_begin_process first. Call this once per step as you complete each action. "
                "status: 'pending' (starting), 'success' (done OK), 'warning' (done with caveat), "
                "'error' (failed), 'info' (note)."
            ),
        )
        async def print_append_step(text: str, status: str) -> str:
            """
            Feed one step line to the open process receipt session.

            Args:
                text:   Step description (e.g. "Bank 1 voltage: 55.0V OK")
                status: 'pending', 'success', 'warning', 'error', or 'info'

            Returns:
                Confirmation or error message
            """
            try:
                future = self.backend.send_command("printer", "append_step", {
                    "text": text, "status": status
                })
                result = future.result(timeout=8)
                if result.get("error"):
                    return f"Printer error: {result['error']['message']}"
                logger.info(f"[PRINT_PROCESS_STEP] [{status}] {text}")
                return "✓ Step appended."
            except Exception as e:
                logger.error(f"Error in print_append_step: {e}")
                return f"Error appending step: {e}"

        @self.mcp.tool(
            name="print_finish_process",
            description=(
                "Close the active process receipt session — prints the outcome footer and cuts the paper. "
                "Must call print_begin_process first. Call this once all steps are complete. "
                "outcome: 'success', 'warning', or 'error'."
            ),
        )
        async def print_finish_process(summary: str, outcome: str) -> str:
            """
            Close the active process session and cut the paper.

            Args:
                summary: One-line summary of the overall result (e.g. "All checks passed")
                outcome: 'success', 'warning', or 'error'

            Returns:
                Confirmation or error message
            """
            try:
                future = self.backend.send_command("printer", "finish_process", {
                    "summary": summary, "outcome": outcome
                })
                result = future.result(timeout=8)
                if result.get("error"):
                    return f"Printer error: {result['error']['message']}"
                logger.info(f"[PRINT_PROCESS_FINISH] {outcome}: {summary}")
                return "✓ Process session closed and receipt cut."
            except Exception as e:
                logger.error(f"Error in print_finish_process: {e}")
                return f"Error finishing process: {e}"

        logger.info(
            "MCP tools registered: read_parameter, write_parameter, list_devices, "
            "print_content, print_diagnostics, print_alert, print_status_report, "
            "print_welcome, print_daily_briefing, print_sequence_confirmation, "
            "print_begin_process, print_append_step, print_finish_process"
        )
    
    def run(self) -> None:
        """Start the MCP server with uvicorn."""
        logger.info(f"Starting MCP server on port {self.port}")
        app = self.mcp.streamable_http_app()
        uvicorn.run(app, host="0.0.0.0", port=self.port, log_level="warning")
