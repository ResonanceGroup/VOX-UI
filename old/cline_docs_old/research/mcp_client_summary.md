# MCP Client Implementation Research Summary

**Date:** 2025-04-08

**Objective:** Understand Model Context Protocol (MCP) client best practices relevant for the VOX UI backend, focusing on connection, tool/resource usage, status updates, and error handling.

**Sources:**

* MCP Specification (2025-03-26): <https://spec.modelcontextprotocol.io/specification/2025-03-26/>
* Architecture: <https://spec.modelcontextprotocol.io/specification/2025-03-26/architecture>
* Base Protocol: <https://spec.modelcontextprotocol.io/specification/2025-03-26/basic>
* Server Features: <https://spec.modelcontextprotocol.io/specification/2025-03-26/server/>
* Tools: <https://spec.modelcontextprotocol.io/specification/2025-03-26/server/tools>
* Resources: <https://spec.modelcontextprotocol.io/specification/2025-03-26/server/resources>
* Pagination: <https://spec.modelcontextprotocol.io/specification/2025-03-26/server/utilities/pagination/>
* Logging: <https://spec.modelcontextprotocol.io/specification/2025-03-26/server/utilities/logging/>

*(Note: Specific documentation pages for "Progress" and "Cancellation" utilities were not located during this research.)*

---

## 1. Client-Server Connection & Configuration

* **Architecture:** MCP uses a Host-Client-Server model. The Host application (e.g., VOX UI backend) manages multiple Client instances. Each Client maintains a single, stateful connection to one Server.
* **Protocol:** Communication uses JSON-RPC 2.0 over a transport (like STDIO or HTTP/WebSockets).
* **Initialization:** When a client connects, a capability negotiation occurs. The client and server declare supported features (e.g., `tools`, `resources`, `subscribe`, `logging`). The client must respect the server's declared capabilities.
* **Configuration/Auth:**
  * Authentication depends on the transport. STDIO servers typically get credentials from the environment. HTTP servers use a specified Authorization framework (e.g., Bearer tokens).
  * Configuration files themselves aren't explicitly defined in the core spec sections reviewed, but the Host is responsible for managing client connections and permissions, implying configuration is handled at the Host level.

## 2. Invoking Tools (`use_mcp_tool`)

* **Discovery:** Clients discover available tools using the `tools/list` JSON-RPC request (supports pagination). Servers respond with a list of tools, including name, description, and input schema (JSON Schema).
* **Invocation:** Clients invoke a tool using the `tools/call` JSON-RPC request, providing the tool `name` and `arguments` matching the tool's input schema.
* **Response:** The server replies with a JSON-RPC response.
  * **Success:** Contains a `result` object with `content` (an array of text, image, audio, or embedded resource objects) and `isError: false`.
  * **Tool Execution Error:** Contains a `result` object with `content` (usually text describing the error) and `isError: true`. This indicates the tool ran but failed (e.g., API error).
  * **Protocol Error:** Contains an `error` object (standard JSON-RPC format) for issues like unknown tool, invalid arguments, etc.
* **Updates:** If the server declared the `listChanged` capability for tools, it SHOULD send a `notifications/tools/list_changed` notification when the available tools change.
* **Node.js Client Considerations:** The client needs to manage JSON-RPC request IDs, send `tools/list` and `tools/call` requests, and parse the corresponding success/error responses, distinguishing between protocol errors and tool execution errors (`isError` flag). User confirmation before invoking tools is strongly recommended for security.

## 3. Accessing Resources (`access_mcp_resource`)

* **Discovery:** Clients discover resources using the `resources/list` JSON-RPC request (supports pagination). Servers respond with a list of resources, including `uri`, `name`, `description`, `mimeType`.
* **Access:** Clients retrieve resource content using the `resources/read` JSON-RPC request, providing the resource `uri`.
* **Response:**
  * **Success:** Contains a `result` object with `contents` (an array containing the resource content as text or base64 blob, along with URI and mimeType).
  * **Error:** Contains an `error` object (standard JSON-RPC format) for issues like resource not found (`-32002`).
* **Updates/Subscriptions:**
  * If the server declared `listChanged` capability for resources, it SHOULD send `notifications/resources/list_changed` when the list changes.
  * If the server declared `subscribe` capability, the client can send `resources/subscribe` requests for specific URIs. The server SHOULD then send `notifications/resources/updated` when that resource changes. The client would then need to re-`read` the resource.
* **Node.js Client Considerations:** The client needs to manage JSON-RPC requests for listing and reading, handle potential errors (like not found), and optionally manage subscriptions and update notifications if the server supports them.

## 4. Server-to-Client Status Updates

* **Logging:** Servers with the `logging` capability can send `notifications/message` notifications. These include a severity `level` (debug, info, warning, error, etc.) and arbitrary `data`. Clients can optionally set the minimum level using `logging/setLevel`. This is the primary mechanism found for general status/progress updates.
* **Resource Updates:** As mentioned above, `notifications/resources/updated` signals a change to a subscribed resource.
* **List Changes:** `notifications/tools/list_changed` and `notifications/resources/list_changed` signal changes in available items.
* **Progress Utility:** A dedicated "Progress" utility was mentioned in overviews but its specific documentation page was not located. Status might be inferred via logging messages.
* **Node.js Client Considerations:** The client needs to handle incoming JSON-RPC notifications and route them appropriately (e.g., display logs, trigger resource re-fetch, update tool lists).

## 5. Error Handling Patterns

* **JSON-RPC Standard:** MCP relies heavily on standard JSON-RPC error responses (`error` object with `code`, `message`, `data`).
* **Protocol Errors:** Defined codes exist for common issues (e.g., `-32602` Invalid params, `-32603` Internal error).
* **Resource Errors:** Specific code for resource not found (`-32002`).
* **Tool Execution Errors:** Distinguished from protocol errors by being returned in the `result` field with `isError: true`. The `content` field typically contains the error description.
* **Logging:** Servers can proactively push error-level log messages via `notifications/message`.
* **Node.js Client Considerations:** Robust error handling should check for the `error` field in responses first. If `result` exists, check the `isError` flag for tool calls. Handle specific error codes where appropriate. Log received error notifications.
