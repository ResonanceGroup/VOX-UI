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
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP Servers'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            padding: const EdgeInsets.all(8.0), // 8px padding to match original
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        // Add bottom border to match original
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            height: 1.0,
            color: AppTheme.borderColor,
          ),
        ),
      ),
      drawer: const VOXNavigationDrawer(currentRoute: '/mcp-servers'),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView( // Add scrolling
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configure Model Context Protocol (MCP) server connections to extend functionality.',
              style: AppTheme.bodyTextStyle,
            ),
            const SizedBox(height: AppTheme.sectionSpacing),

            // Enable MCP Servers toggle
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: false, // TODO: Connect to state management
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
            const SizedBox(height: AppTheme.sectionSpacing),

            // Server list (placeholder)
            Text(
              'Connected Servers',
              style: AppTheme.sectionHeaderStyle,
            ),
            const SizedBox(height: 12.0),

            // Placeholder server items (matching web UI accordion structure)
            _buildServerItem(
              name: 'brave-search',
              status: 'Connected',
              statusColor: AppTheme.statusOkColor,
              tools: 2,
              resources: 0,
            ),

            _buildServerItem(
              name: 'webresearch',
              status: 'Disconnected',
              statusColor: AppTheme.statusErrorColor,
              tools: 2,
              resources: 0,
            ),

            _buildServerItem(
              name: 'mcp-openai',
              status: 'Connected',
              statusColor: AppTheme.statusOkColor,
              tools: 1,
              resources: 0,
            ),

            const SizedBox(height: AppTheme.sectionSpacing),

            // Action buttons (matching original dimensions)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    onPressed: () {
                      // TODO: Implement edit servers functionality
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit MCP Servers'),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildServerItem({
    required String name,
    required String status,
    required Color statusColor,
    required int tools,
    required int resources,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent), // Remove black border lines
        child: ExpansionTile(
        leading: Icon(
          Icons.arrow_forward_ios,
          size: 16.0,
          color: AppTheme.textLightColor,
        ),
        title: Row(
          children: [
            Text(name, style: AppTheme.labelStyle),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 8.0,
                    color: statusColor,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Tools and Resources tabs (placeholder)
                Row(
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: Text('Tools ($tools)'),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text('Resources ($resources)'),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),

                // Placeholder tool details (matching web UI structure)
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.search, size: 16.0),
                          const SizedBox(width: 8.0),
                          Text(
                            '${name}_web_search',
                            style: AppTheme.labelStyle,
                          ),
                          const Spacer(),
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
                      Text(
                        'Performs a web search using the $name API.',
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
      ),
    );
  }
}
