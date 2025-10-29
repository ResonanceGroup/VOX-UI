import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/navigation_drawer.dart';
import '../theme/app_theme.dart';

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
                        color: isDark ? const Color(0xFF444444) : const Color(0xFFEEEEEE),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: false,
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
                                style: AppTheme.labelStyle,
                              ),
                              Text(
                                'When enabled, VOX will be able to interact with connected MCP servers for advanced functionality.',
                                style: AppTheme.bodyTextStyle.copyWith(
                                  color: AppTheme.textLightColor,
                                  fontSize: 12.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20.0),

                  // Server list header
                  Text(
                    'Connected Servers',
                    style: AppTheme.sectionHeaderStyle,
                  ),
                  const SizedBox(height: 12.0),

                  // Server items with custom accordion
                  _McpServerAccordion(
                    name: 'brave-search',
                    status: 'Connected',
                    statusColor: AppTheme.statusOkColor,
                    tools: 2,
                    resources: 0,
                  ),
                  const SizedBox(height: 16.0),

                  _McpServerAccordion(
                    name: 'webresearch',
                    status: 'Disconnected',
                    statusColor: AppTheme.statusErrorColor,
                    tools: 2,
                    resources: 0,
                  ),
                  const SizedBox(height: 16.0),

                  _McpServerAccordion(
                    name: 'mcp-openai',
                    status: 'Connected',
                    statusColor: AppTheme.statusOkColor,
                    tools: 1,
                    resources: 0,
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

// Custom accordion widget for MCP servers
class _McpServerAccordion extends StatefulWidget {
  final String name;
  final String status;
  final Color statusColor;
  final int tools;
  final int resources;

  const _McpServerAccordion({
    required this.name,
    required this.status,
    required this.statusColor,
    required this.tools,
    required this.resources,
  });

  @override
  State<_McpServerAccordion> createState() => _McpServerAccordionState();
}

class _McpServerAccordionState extends State<_McpServerAccordion> {
  bool _isExpanded = false;
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
        ),
      ),
      child: Column(
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _isHovering
                      ? (isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF0F0F0))
                      : Colors.transparent,
                  borderRadius: _isExpanded
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(8.0),
                          topRight: Radius.circular(8.0),
                        )
                      : BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    // Chevron icon on the LEFT
                    AnimatedRotation(
                      turns: _isExpanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.chevron_right,
                        size: 24.0,
                        color: isDark
                            ? const Color(0xFFEEEEEE).withOpacity(0.8)
                            : const Color(0xFF999999),
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Text(
                      widget.name,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFEEEEEE) : const Color(0xFF333333),
                      ),
                    ),
                    const Spacer(),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: widget.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8.0,
                            color: widget.statusColor,
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            widget.status,
                            style: TextStyle(
                              color: widget.statusColor,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Separator line when expanded
          if (_isExpanded)
            Container(
              height: 1.0,
              color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
            ),
          // Content
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tools and Resources tabs
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        ),
                        child: Text(
                          'Tools (${widget.tools})',
                          style: const TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        ),
                        child: Text(
                          'Resources (${widget.resources})',
                          style: const TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),

                  // Tool details
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF383838) : const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: isDark ? const Color(0xFF555555) : const Color(0xFFDDDDDD),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.search, size: 16.0),
                            const SizedBox(width: 8.0),
                            Text(
                              '${widget.name}_web_search',
                              style: const TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Checkbox(
                                  value: true,
                                  onChanged: (value) {},
                                ),
                                Text(
                                  'Always allow',
                                  style: AppTheme.bodyTextStyle.copyWith(fontSize: 12.0),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Performs a web search using the ${widget.name} API.',
                          style: AppTheme.bodyTextStyle.copyWith(
                            color: AppTheme.textLightColor,
                            fontSize: 12.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
