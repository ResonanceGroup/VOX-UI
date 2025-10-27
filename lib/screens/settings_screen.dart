import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Form state
  String serverUrl = 'ws://localhost:5005';
  String systemPrompt = 'Test Prompt';
  String model = 'ultravox';
  String voice = 'en-US/amy';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // TODO: Open sidebar - will be handled by parent ShellRoute
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sidebar will be implemented with ShellRoute')),
            );
          },
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // Navigate back to chat using GoRouter
              context.go('/chat');
            },
            child: const Text('Done'),
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Voice Agent accordion (expanded by default)
              _buildAccordionGroup(
                title: 'Voice Agent',
                initiallyExpanded: true,
                children: [
                  _buildTextField(
                    label: 'Server URL',
                    value: serverUrl,
                    onChanged: (value) => setState(() => serverUrl = value),
                    placeholder: 'Enter server URL',
                  ),
                  _buildTextField(
                    label: 'System Prompt',
                    value: systemPrompt,
                    onChanged: (value) => setState(() => systemPrompt = value),
                    placeholder: 'Enter system prompt...',
                    maxLines: 7,
                  ),
                  _buildDropdownField(
                    label: 'Model',
                    value: model,
                    onChanged: (value) => setState(() => model = value ?? model),
                    items: const ['UltraVOX'],
                  ),
                  _buildTextField(
                    label: 'Voice',
                    value: voice,
                    onChanged: (value) => setState(() => voice = value),
                    placeholder: 'Enter voice ID',
                  ),
                  _buildDropdownField(
                    label: 'Language',
                    value: 'en',
                    onChanged: (value) {},
                    items: const ['English', 'Chinese'],
                  ),
                ],
              ),

              const SizedBox(height: 16.0),

              // MCP accordion (collapsed by default)
              _buildAccordionGroup(
                title: 'MCP',
                initiallyExpanded: false,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'MCP Config (JSON)',
                          style: AppTheme.labelStyle,
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          height: 200.0,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                          ),
                          child: const Center(
                            child: Text(
                              '// MCP Configuration\n// TODO: Implement JSON editor',
                              style: TextStyle(
                                color: Color(0xFF666666),
                                fontFamily: 'monospace',
                                fontSize: 12.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () {},
                              child: const Text('Save'),
                            ),
                            const SizedBox(width: 8.0),
                            OutlinedButton(
                              onPressed: () {},
                              child: const Text('Revert'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16.0),

              // n8n Integration accordion (collapsed by default)
              _buildAccordionGroup(
                title: 'n8n Integration',
                initiallyExpanded: false,
                children: [
                  _buildTextField(
                    label: 'Webhook URL',
                    value: '',
                    onChanged: (value) {},
                    placeholder: 'https://your-n8n-webhook-url',
                  ),
                ],
              ),

              const SizedBox(height: 16.0),

              // General UI accordion (collapsed by default)
              _buildAccordionGroup(
                title: 'General UI',
                initiallyExpanded: false,
                children: [
                  _buildThemeSelector(),
                ],
              ),

              const SizedBox(height: 32.0),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Save all settings
                        Navigator.of(context).pop();
                      },
                      child: const Text('Save Changes'),
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

  Widget _buildAccordionGroup({
    required String title,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(
          title,
          style: AppTheme.sectionHeaderStyle,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required Function(String) onChanged,
    String? placeholder,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.labelStyle,
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
            onChanged: onChanged,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: placeholder,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            ),
            style: AppTheme.bodyTextStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required Function(String?) onChanged,
    required List<String> items,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.labelStyle,
          ),
          const SizedBox(height: 8.0),
          DropdownButtonFormField<String>(
            value: value,
            onChanged: onChanged,
            items: items.map((item) {
              return DropdownMenuItem(
                value: item.toLowerCase(),
                child: Text(item),
              );
            }).toList(),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    final currentTheme = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme',
          style: AppTheme.labelStyle,
        ),
        const SizedBox(height: 8.0),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderColor),
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          ),
          child: Column(
            children: [
              _buildThemeOption(
                title: 'System',
                value: ThemeMode.system,
                currentValue: currentTheme,
              ),
              Divider(height: 1.0, color: AppTheme.borderColor),
              _buildThemeOption(
                title: 'Light',
                value: ThemeMode.light,
                currentValue: currentTheme,
              ),
              Divider(height: 1.0, color: AppTheme.borderColor),
              _buildThemeOption(
                title: 'Dark',
                value: ThemeMode.dark,
                currentValue: currentTheme,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required String title,
    required ThemeMode value,
    required ThemeMode currentValue,
  }) {
    return ListTile(
      title: Text(title),
      leading: Radio<ThemeMode>(
        value: value,
        groupValue: currentValue,
        onChanged: (mode) {
          if (mode != null) {
            ThemeService.updateTheme(ref, mode);
          }
        },
      ),
      onTap: () {
        ThemeService.updateTheme(ref, value);
      },
    );
  }
}

class NavigationDrawer extends StatelessWidget {
  const NavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: AppTheme.sidebarWidth,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            Container(
              height: AppTheme.navHeight,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.borderColor,
                    width: 1.0,
                  ),
                ),
              ),
              child: const Center(
                child: Text(
                  'Navigation',
                  style: AppTheme.navTitleStyle,
                ),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Chat'),
              onTap: () {
                context.go('/chat');
              },
            ),

            ListTile(
              leading: const Icon(Icons.computer),
              title: const Text('MCP Servers'),
              onTap: () {
                context.go('/mcp-servers');
              },
            ),

            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              selected: true,
              selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
              selectedColor: AppTheme.primaryColor,
              onTap: () {
                // Already on this page
              },
            ),
          ],
        ),
      ),
    );
  }
}