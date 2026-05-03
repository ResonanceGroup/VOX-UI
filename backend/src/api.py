"""
backend.py — RG Smart Control Backend TCP Client

Maintains a persistent TCP connection to the Controller Backend (port 9001).
Provides:
  - BackendCache: populated from .update push notifications (real-time device state)
  - BackendClient: async JSON-RPC 2.0 command dispatch over NDJSON TCP

Protocol:
  - Transport: TCP, NDJSON framing (one JSON object per line)
  - Format: JSON-RPC 2.0
  - Port: FRONTEND_AI_PORT = 9001

Typical usage (in tools.py):
    backend = BackendClient(host="10.0.0.153", port=9001)
    await backend.connect()

    # Read (from cache, populated by push stream)
    soc = backend.cache.get("bank2", "soc")         # → 72.3 or None

    # Control (send command, await correlated response)
    result = await backend.command("main_lights", "set", {"activated": True, "brightness": 75.0})
    if "error" in result:
        print(result["error"]["message"])   # "Cannot connect to host..."
    else:
        print(result["result"])             # "ok"

    await backend.disconnect()
"""

from __future__ import annotations

import asyncio
import json
import logging
import threading
import uuid
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

# Matches backend READ_TIMEOUT_SECONDS in config.json
COMMAND_TIMEOUT_S: float = 12.0

# Delay between reconnect attempts
RECONNECT_DELAY_S: float = 5.0

# Time to wait for initial .update burst on connect (backend sends all devices immediately)
INITIAL_BURST_WAIT_S: float = 2.0


# ---------------------------------------------------------------------------
# BackendCache
# ---------------------------------------------------------------------------

class BackendCache:
    """
    In-memory cache of device state, populated from .update push notifications.

    The backend pushes <device_id>.update notifications continuously.
    This cache stores the latest known value for every device property.
    """

    def __init__(self) -> None:
        self._data: Dict[str, Dict[str, Any]] = {}

    # ------------------------------------------------------------------
    # Write (called by BackendClient._dispatch on .update notifications)
    # ------------------------------------------------------------------

    def update(self, device_id: str, props: Dict[str, Any]) -> None:
        """Overwrite cached state for a device from an .update notification."""
        self._data[device_id] = props

    # ------------------------------------------------------------------
    # Read (called by tools.py for read_device)
    # ------------------------------------------------------------------

    def get_property(self, device_id: str, property_name: str) -> Any:
        """
        Get a single property value for a device.
        Returns None if the device or property is not in cache.
        """
        device = self._data.get(device_id)
        if device is None:
            return None
        return device.get(property_name)

    def get_device(self, device_id: str) -> Optional[Dict[str, Any]]:
        """Get all cached properties for a device. Returns None if not cached."""
        return self._data.get(device_id)

    def get_all(self) -> Dict[str, Dict[str, Any]]:
        """Return snapshot of all cached device states."""
        return dict(self._data)

    def device_ids(self) -> List[str]:
        """Return list of device IDs seen so far."""
        return list(self._data.keys())

    def has_device(self, device_id: str) -> bool:
        return device_id in self._data

    def __repr__(self) -> str:
        return f"BackendCache({len(self._data)} devices)"


# ---------------------------------------------------------------------------
# BackendClient
# ---------------------------------------------------------------------------

class BackendClient:
    """
    Async TCP client for the RG Smart Control Backend.

    Responsibilities:
    - Open and maintain a TCP connection (NDJSON framing)
    - Run a background reader loop that:
        * Routes .update notifications → BackendCache
        * Routes correlated responses (id match) → pending asyncio.Future
    - Expose command() for sending JSON-RPC requests and awaiting responses
    """

    def __init__(
        self,
        host: str = "10.0.0.153",
        port: int = 9001,
        client_type: str = "ai_backend",
        auto_reconnect: bool = True,
        connect_timeout: float = 10.0,
        min_backoff: float = 0.5,
        max_backoff: float = 60.0,
    ) -> None:
        self.host = host
        self.port = port
        self.client_type = client_type
        self.auto_reconnect = auto_reconnect
        self.connect_timeout = connect_timeout
        self.min_backoff = min_backoff
        self.max_backoff = max_backoff

        self.cache = BackendCache()

        self._reader: Optional[asyncio.StreamReader] = None
        self._writer: Optional[asyncio.StreamWriter] = None
        self._read_task: Optional[asyncio.Task] = None
        self._connected: bool = False

        # Pending correlated futures: request_id → asyncio.Future
        self._pending: Dict[str, asyncio.Future] = {}
        
        # Reconnection state
        self._reconnect_attempt = 0

        # Background thread for persistent connection
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._thread: Optional[threading.Thread] = None

    # ------------------------------------------------------------------
    # Background thread management
    # ------------------------------------------------------------------

    def start_in_background(self) -> None:
        """Start the backend connection in a dedicated background thread.

        The thread runs its own event loop, maintaining the TCP connection
        and reader loop persistently. Reconnection is automatic.
        """
        self._thread = threading.Thread(
            target=self._run_loop,
            daemon=True,
            name="backend-client",
        )
        self._thread.start()
        logger.info("Backend client thread started.")

    def _run_loop(self) -> None:
        """Thread entry point: create event loop, connect, run forever."""
        self._loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self._loop)
        self._loop.run_until_complete(self.connect())
        # Keep loop alive — reader task and reconnections run here
        self._loop.run_forever()

    def send_command(
        self,
        device_id: str,
        verb: str = "set",
        params: Optional[Dict[str, Any]] = None,
    ) -> "concurrent.futures.Future":
        """Thread-safe command dispatch.

        Dispatches command() to the backend's dedicated event loop.
        Returns a concurrent.futures.Future.

        Usage from sync code:  result = backend.send_command(...).result(timeout=12)
        Usage from async code: result = await asyncio.wrap_future(backend.send_command(...))
        """
        if self._loop is None or self._loop.is_closed():
            raise ConnectionError("Backend not running — call start_in_background() first")
        return asyncio.run_coroutine_threadsafe(
            self.command(device_id, verb, params),
            self._loop,
        )

    # ------------------------------------------------------------------
    # Connection lifecycle
    # ------------------------------------------------------------------

    async def connect(self) -> None:
        """
        Open TCP connection to the backend with automatic retry and exponential backoff.
        
        Retries forever with exponential backoff until connection succeeds.
        Does not block — retries happen asynchronously in the background.
        
        After connect(), the cache will be populated with the latest state
        for all registered devices.
        """
        attempt = 0
        while True:
            try:
                logger.info(f"Connecting to backend at {self.host}:{self.port} ...")
                self._reader, self._writer = await asyncio.wait_for(
                    asyncio.open_connection(self.host, self.port),
                    timeout=self.connect_timeout
                )
                self._connected = True
                logger.info("Backend TCP connected.")
                break  # Success — exit retry loop
                
            except (asyncio.TimeoutError, OSError, ConnectionError) as e:
                attempt += 1
                # Calculate exponential backoff: min_backoff * 2^(attempt-1), capped at max_backoff
                backoff = min(self.min_backoff * (2 ** (attempt - 1)), self.max_backoff)
                logger.warning(
                    f"Connection failed (attempt {attempt}): {e}. "
                    f"Retrying in {backoff:.1f}s..."
                )
                await asyncio.sleep(backoff)
                # Loop continues — will retry forever

        # Start background reader
        self._read_task = asyncio.create_task(self._read_loop(), name="backend-reader")

        # Wait for the initial burst of .update notifications
        # (backend sends all device states immediately on connect)
        await asyncio.sleep(INITIAL_BURST_WAIT_S)
        logger.info(f"Cache ready: {len(self.cache.device_ids())} devices — {self.cache.device_ids()}")

    async def disconnect(self) -> None:
        """Cleanly close the connection."""
        logger.info("Disconnecting from backend...")
        self._connected = False

        if self._read_task and not self._read_task.done():
            self._read_task.cancel()
            try:
                await self._read_task
            except asyncio.CancelledError:
                pass

        # Cancel any pending futures
        for fut in self._pending.values():
            if not fut.done():
                fut.cancel()
        self._pending.clear()

        if self._writer:
            try:
                self._writer.close()
                await self._writer.wait_closed()
            except Exception:
                pass

        logger.info("Backend disconnected.")

    @property
    def connected(self) -> bool:
        return self._connected

    # ------------------------------------------------------------------
    # Command dispatch
    # ------------------------------------------------------------------

    async def command(
        self,
        device_id: str,
        verb: str = "set",
        params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Send a JSON-RPC command and await the correlated response.

        Args:
            device_id: Target device ID (e.g., "main_lights", "bank2")
            verb:      Operation — "set" for control (default). Note: reads use BackendCache, not queries.
            params:    Command parameters (e.g., {"activated": True, "brightness": 75.0})

        Returns:
            On success: {"jsonrpc": "2.0", "id": "...", "result": "ok"}
            On error:   {"jsonrpc": "2.0", "id": "...", "error": {"code": -32000, "message": "..."}}

        Raises:
            ConnectionError: Not connected
            asyncio.TimeoutError: No response within COMMAND_TIMEOUT_S
            
        Notes:
            - All reads (get device state) should use BackendCache, not command()
            - BackendCache is populated continuously by .update push notifications from backend
            - Only use command() for write operations (setting device state)
        """
        if not self._connected or self._writer is None:
            raise ConnectionError("BackendClient not connected")

        req_id = str(uuid.uuid4())
        method = f"{device_id}.{verb}"
        msg = {
            "jsonrpc": "2.0",
            "id": req_id,
            "method": method,
            "params": params or {},
        }

        # Register future before sending (avoids race if response is very fast)
        loop = asyncio.get_running_loop()
        fut: asyncio.Future = loop.create_future()
        self._pending[req_id] = fut

        # Send NDJSON line
        line = json.dumps(msg) + "\n"
        self._writer.write(line.encode())
        await self._writer.drain()

        logger.debug(f"→ {method} params={params} id={req_id[:8]}")

        try:
            response = await asyncio.wait_for(fut, timeout=COMMAND_TIMEOUT_S)
            logger.debug(f"← {method} response={response.get('result') or response.get('error')}")
            return response
        except asyncio.TimeoutError:
            self._pending.pop(req_id, None)
            logger.warning(f"Timeout waiting for response to {method}")
            raise asyncio.TimeoutError(
                f"Backend did not respond to {method} within {COMMAND_TIMEOUT_S}s"
            )

    # ------------------------------------------------------------------
    # Background reader loop
    # ------------------------------------------------------------------

    async def _read_loop(self) -> None:
        """
        Read NDJSON lines from the backend stream and dispatch each message
        to either the BackendCache (for .update notifications) or a pending
        correlated future (for command responses).
        
        Handles auto-reconnection if enabled.
        """
        try:
            while self._reader and self._connected:
                try:
                    raw = await self._reader.readline()
                except (asyncio.IncompleteReadError, ConnectionResetError, OSError) as e:
                    logger.warning(f"Backend connection lost: {e}")
                    self._connected = False
                    
                    # Attempt auto-reconnect if enabled
                    if self.auto_reconnect:
                        await self._attempt_reconnect()
                    break

                if not raw:
                    logger.warning("Backend closed connection (EOF).")
                    self._connected = False
                    
                    # Attempt auto-reconnect if enabled
                    if self.auto_reconnect:
                        await self._attempt_reconnect()
                    break

                line = raw.decode().strip()
                if not line:
                    continue

                try:
                    msg = json.loads(line)
                except json.JSONDecodeError:
                    logger.warning(f"Non-JSON from backend: {line[:120]}")
                    continue

                self._dispatch(msg)

        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"Backend read loop error: {e}", exc_info=True)
        finally:
            # Only fail pending futures if truly disconnected (not after reconnect)
            if not self._connected:
                for fut in self._pending.values():
                    if not fut.done():
                        fut.set_exception(ConnectionError("Backend connection closed"))
                self._pending.clear()
    
    async def _attempt_reconnect(self) -> None:
        """
        Attempt to reconnect to the backend with exponential backoff.
        
        Backoff: 1s, 2s, 4s, 8s, 16s, ..., up to max 60s
        """
        if not self.auto_reconnect:
            return
        
        # Calculate backoff: 2^(attempts) seconds, capped at max
        backoff = min(2 ** self._reconnect_attempt, self.max_backoff)
        self._reconnect_attempt += 1
        
        logger.info(f"Reconnecting to backend in {backoff}s (attempt {self._reconnect_attempt})...")
        await asyncio.sleep(backoff)
        
        try:
            await self.connect()
            self._reconnect_attempt = 0  # Reset on success
            logger.info("Backend reconnected successfully")
        except Exception as e:
            logger.warning(f"Reconnect failed: {e}")
            # Will be retried on next connection loss

    def _dispatch(self, msg: Dict[str, Any]) -> None:
        """
        Route an incoming message.

        Logic:
          1. Has "id" AND that id is in _pending → correlated command response
          2. No "id", method ends in ".update" → push notification → BackendCache
          3. Anything else → log and ignore
        """
        req_id = msg.get("id")
        method: str = msg.get("method", "")

        # --- Correlated response ---
        if req_id is not None:
            fut = self._pending.pop(req_id, None)
            if fut and not fut.done():
                fut.set_result(msg)
            # Note: .update notifications with the same id as a pending request
            # should not happen, but the pop(req_id, None) handles it gracefully.
            return

        # --- Push notification (.update) ---
        if method.endswith(".update"):
            device_id = method[: -len(".update")]
            params = msg.get("params") or {}
            self.cache.update(device_id, params)
            return

        # --- Other notifications (alert.new, system.error, etc.) ---
        logger.debug(f"Backend notification (unhandled): method={method!r}")
