import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/navigation_drawer.dart';
import '../theme/app_theme.dart';
import '../widgets/mcp/mcp_server_widget.dart';
import '../widgets/mcp/mcp_tool_widget.dart';

class McpServersScreen extends StatefulWidget {
  const McpServersScreen({super.key});

  @override
  State<McpServersScreen> createState() => _McpServersScreenState();
}

class _McpServersScreenState extends State<McpServersScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF252526) : Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('MCP Servers'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            padding: const EdgeInsets.all(8.0),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            height: 1.0,
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5),
          ),
        ),
      ),
      drawer: const VOXNavigationDrawer(currentRoute: '/mcp-servers'),
      body: Container(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252526) : const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 10.0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configure Model Context Protocol (MCP) server connections to extend functionality.',
                    style: AppTheme.bodyTextStyle.copyWith(
                      color: AppTheme.textLightColor,
                    ),
                  ),
                  const SizedBox(height: 20.0),

                  // Enable MCP Servers toggle
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      border: Border.all(
                        color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: true,
                          onChanged: (value) {
                            // TODO: Implement toggle functionality
                          },
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable MCP Servers',
                                style: AppTheme.labelStyle.copyWith(
                                  color: isDark ? const Color(0xFFE0E0E0) : null,
                                ),
                              ),
                              Text(
                                'When enabled, VOX will be able to interact with connected MCP servers for advanced functionality.',
                                style: AppTheme.bodyTextStyle.copyWith(
                                  color: isDark ? const Color(0xFFE0E0E0) : AppTheme.textLightColor,
                                  fontSize: 12.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // Server list header
                  Text(
                    'Connected Servers',
                    style: AppTheme.sectionHeaderStyle.copyWith(
                      color: isDark ? const Color(0xFFE0E0E0) : null,
                    ),
                  ),
                  const SizedBox(height: 12.0),

                  // Server items with new custom widgets
                  McpServerWidget(
                    name: 'brave-search',
                    status: 'Connected',
                    statusColor: AppTheme.statusOkColor,
                    isEnabled: true,
                    onEnabledChanged: (value) {
                      // TODO: Implement enable/disable functionality
                      setState(() {});
                    },
                    networkTimeout: '1 minute',
                    onTimeoutChanged: (value) {
                      // TODO: Implement timeout change functionality
                      setState(() {});
                    },
                    tools: [
                      ToolData(
                        name: 'brave_web_search',
                        description: 'Performs a web search using the Brave Search API',
                        parameters: [
                          ToolParameter(name: 'query', description: 'Search query (max 400 chars, 50 words)'),
                          ToolParameter(name: 'count', description: 'Number of results (1-20, default 10)'),
                          ToolParameter(name: 'offset', description: 'Pagination offset (max 9, default 0)'),
                        ],
                        isAlwaysAllowed: true,
                        onAlwaysAllowChanged: (value) {
                          // TODO: Implement always allow toggle
                          setState(() {});
                        },
                      ),
                      ToolData(
                        name: 'brave_local_search',
                        description: 'Searches for local businesses and places',
                        parameters: [
                          ToolParameter(name: 'query', description: 'Local search query (e.g. \'pizza near Central Park\')'),
                          ToolParameter(name: 'count', description: 'Number of results (1-20, default 5)'),
                        ],
                        isAlwaysAllowed: true,
                        onAlwaysAllowChanged: (value) {
                          // TODO: Implement always allow toggle
                          setState(() {});
                        },
                      ),
                    ],
                    resources: [],
                  ),
                  const SizedBox(height: 16.0),

                  McpServerWidget(
                    name: 'webresearch',
                    status: 'Disconnected',
                    statusColor: AppTheme.statusErrorColor,
                    isEnabled: false,
                    onEnabledChanged: (value) {
                      // TODO: Implement enable/disable functionality
                      setState(() {});
                    },
                    networkTimeout: '1 minute',
                    onTimeoutChanged: (value) {
                      // TODO: Implement timeout change functionality
                      setState(() {});
                    },
                    tools: [
                      ToolData(
                        name: 'search_google',
                        description: 'Search Google for a query',
                        parameters: [
                          ToolParameter(name: 'query', description: 'Search query'),
                        ],
                        isAlwaysAllowed: false,
                        onAlwaysAllowChanged: (value) {
                          // TODO: Implement always allow toggle
                          setState(() {});
                        },
                      ),
                      ToolData(
                        name: 'visit_page',
                        description: 'Visit a webpage and extract its content',
                        parameters: [
                          ToolParameter(name: 'url', description: 'URL to visit'),
                          ToolParameter(name: 'takeScreenshot', description: 'Whether to take a screenshot'),
                        ],
                        isAlwaysAllowed: false,
                        onAlwaysAllowChanged: (value) {
                          // TODO: Implement always allow toggle
                          setState(() {});
                        },
                      ),
                    ],
                    resources: [],
                  ),
                  const SizedBox(height: 16.0),

                  McpServerWidget(
                    name: 'mcp-openai',
                    status: 'Connected',
                    statusColor: AppTheme.statusOkColor,
                    isEnabled: true,
                    onEnabledChanged: (value) {
                      // TODO: Implement enable/disable functionality
                      setState(() {});
                    },
                    networkTimeout: '5 minutes',
                    onTimeoutChanged: (value) {
                      // TODO: Implement timeout change functionality
                      setState(() {});
                    },
                    tools: [
                      ToolData(
                        name: 'generate_text',
                        description: 'Generate text using OpenAI models',
                        parameters: [
                          ToolParameter(name: 'prompt', description: 'The prompt to generate from'),
                          ToolParameter(name: 'model', description: 'Model to use (default: gpt-4)'),
                          ToolParameter(name: 'max_tokens', description: 'Maximum tokens to generate'),
                        ],
                        isAlwaysAllowed: true,
                        onAlwaysAllowChanged: (value) {
                          // TODO: Implement always allow toggle
                          setState(() {});
                        },
                      ),
                    ],
                    resources: [],
                  ),

                  const SizedBox(height: 32.0),

                  // Action button - aligned right, proper sizing
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF347AB7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          // TODO: Implement edit servers functionality
                        },
                        icon: const Icon(Icons.edit, size: 18.0),
                        label: const Text(
                          'Edit MCP Servers',
                          style: TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

