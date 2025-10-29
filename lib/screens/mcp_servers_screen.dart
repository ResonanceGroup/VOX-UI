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
                  const SizedBox(height: 20.0),

                  // Network Timeout section
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      border: Border.all(
                        color: isDark ? const Color(0xFF444444) : const Color(0xFFEEEEEE),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Network Timeout',
                          style: AppTheme.labelStyle.copyWith(
                            color: isDark ? const Color(0xFFE0E0E0) : null,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC),
                            ),
                          ),
                          child: DropdownButton<String>(
                            value: '1 minute',
                            isExpanded: true,
                            underline: const SizedBox(),
                            dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                            style: AppTheme.bodyTextStyle.copyWith(
                              color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
                            ),
                            items: const [
                              DropdownMenuItem(value: '15 seconds', child: Text('15 seconds')),
                              DropdownMenuItem(value: '30 seconds', child: Text('30 seconds')),
                              DropdownMenuItem(value: '1 minute', child: Text('1 minute')),
                              DropdownMenuItem(value: '2 minutes', child: Text('2 minutes')),
                              DropdownMenuItem(value: '5 minutes', child: Text('5 minutes')),
                              DropdownMenuItem(value: '10 minutes', child: Text('10 minutes')),
                              DropdownMenuItem(value: '15 minutes', child: Text('15 minutes')),
                              DropdownMenuItem(value: '30 minutes', child: Text('30 minutes')),
                              DropdownMenuItem(value: '60 minutes', child: Text('60 minutes')),
                            ],
                            onChanged: (value) {
                              // TODO: Implement timeout selection
                            },
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Maximum time to wait for server responses',
                          style: AppTheme.bodyTextStyle.copyWith(
                            color: AppTheme.textLightColor,
                            fontSize: 12.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20.0),

                  // Server list header
                  Text(
                    'Connected Servers',
                    style: AppTheme.sectionHeaderStyle.copyWith(
                      color: isDark ? const Color(0xFFE0E0E0) : null,
                    ),
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
  bool _isEnabled = true;
  int _selectedTab = 0; // 0 = Tools, 1 = Resources

  Widget _buildTab(String title, int count, int index, bool isDark) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.only(bottom: 8.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF347AB8) : Colors.transparent,
              width: 2.0,
            ),
          ),
        ),
        child: Text(
          '$title ($count)',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? (isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333))
                : (isDark ? const Color(0xFF999999) : const Color(0xFF666666)),
          ),
        ),
      ),
    );
  }

  Widget _buildToolCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tool header with icon and checkbox
          Row(
            children: [
              const Icon(Icons.search, size: 18.0),
              const SizedBox(width: 8.0),
              Text(
                '${widget.name}_web_search',
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
                ),
              ),
              const Spacer(),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: true,
                  onChanged: (value) {},
                  activeColor: const Color(0xFF347AB8),
                ),
              ),
              const SizedBox(width: 4.0),
              Text(
                'Always allow',
                style: TextStyle(
                  fontSize: 13.0,
                  color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF666666),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // PARAMETERS section header
          Text(
            'PARAMETERS',
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: isDark ? const Color(0xFF999999) : const Color(0xFF888888),
            ),
          ),
          const SizedBox(height: 12.0),

          // Parameter list
          _buildParameter('page', 'Page number (default 1)', isDark),
          const SizedBox(height: 8.0),
          _buildParameter('per_page', 'Items per page (default 10, max 100)', isDark),
          const SizedBox(height: 8.0),
          _buildParameter('search', 'Search term for post content or title', isDark),
          const SizedBox(height: 8.0),
          _buildParameter('after', 'ISO8601 date string to get posts published after this date', isDark),
        ],
      ),
    );
  }

  Widget _buildParameter(String name, String description, bool isDark) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: name,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFDDA0DD) : const Color(0xFF9B59B6),
              fontFamily: 'monospace',
            ),
          ),
          TextSpan(
            text: '  $description',
            style: TextStyle(
              fontSize: 13.0,
              color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

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
                    // Blue server icon
                    Container(
                      padding: const EdgeInsets.all(6.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF347AB8).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: const Icon(
                        Icons.dns,
                        size: 18.0,
                        color: Color(0xFF347AB8),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Text(
                      widget.name,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFEEEEEE) : const Color(0xFF333333),
                      ),
                    ),
                    const Spacer(),
                    // Status dot
                    Container(
                      width: 10.0,
                      height: 10.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.statusColor,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    // Toggle switch
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _isEnabled,
                        onChanged: (value) {
                          setState(() {
                            _isEnabled = value;
                          });
                        },
                        activeColor: const Color(0xFF347AB8),
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
                  // Tools and Resources tabs - Roo Code style
                  Row(
                    children: [
                      _buildTab('Tools', widget.tools, 0, isDark),
                      const SizedBox(width: 24.0),
                      _buildTab('Resources', widget.resources, 1, isDark),
                    ],
                  ),
                  const SizedBox(height: 16.0),

                  // Tool details - Roo Code style
                  _buildToolCard(isDark),
                ],
              ),
            ),
        ],
      ),
    );

}
}
