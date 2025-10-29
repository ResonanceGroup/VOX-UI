import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../widgets/navigation_drawer.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF252526)
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('Settings'),
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
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF333333)
                : const Color(0xFFE5E5E5),
          ),
        ),
      ),
      drawer: const VOXNavigationDrawer(currentRoute: '/settings'),
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
                  // Voice Agent accordion (expanded by default)
                  _SettingsAccordion(
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
                        value: 'english',
                        onChanged: (value) {},
                        items: const ['english', 'chinese'],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16.0),

                  // MCP accordion (collapsed by default)
                  _SettingsAccordion(
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
                                _buildButton(
                                  label: 'Save',
                                  isPrimary: true,
                                  onPressed: () {},
                                ),
                                const SizedBox(width: 8.0),
                                _buildButton(
                                  label: 'Revert',
                                  isPrimary: false,
                                  onPressed: () {},
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
                  _SettingsAccordion(
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
                  _SettingsAccordion(
                    title: 'General UI',
                    initiallyExpanded: false,
                    children: [
                      _buildThemeSelector(),
                    ],
                  ),

                  const SizedBox(height: 32.0),

                  // Action buttons - not full width, aligned right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildButton(
                        label: 'Cancel',
                        isPrimary: false,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: 12.0),
                      _buildButton(
                        label: 'Save Changes',
                        isPrimary: true,
                        onPressed: () {
                          // TODO: Save all settings
                          Navigator.of(context).pop();
                        },
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

  Widget _buildButton({
    required String label,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? const Color(0xFF347AB7)
            : (isDark ? const Color(0xFF444444) : const Color(0xFFF0F0F0)),
        foregroundColor: isPrimary
            ? Colors.white
            : (isDark ? const Color(0xFFCCCCCC) : const Color(0xFF555555)),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6.0),
          side: BorderSide(
            color: isPrimary
                ? Colors.transparent
                : (isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC)),
            width: 1.0,
          ),
        ),
        elevation: 0,
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15.0,
          fontWeight: FontWeight.w500,
        ),
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
            style: TextStyle(
              fontSize: 14.4,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFE0E0E0)
                  : const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: TextEditingController(text: value)
              ..selection = TextSelection.collapsed(offset: value.length),
            onChanged: onChanged,
            maxLines: maxLines,
            minLines: maxLines > 1 ? maxLines : 1,
            decoration: InputDecoration(
              hintText: placeholder,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF555555)
                      : const Color(0xFFCCCCCC),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF555555)
                      : const Color(0xFFCCCCCC),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: const BorderSide(
                  color: Color(0xFF347AB7),
                  width: 2.0,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            ),
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFE0E0E0)
                  : const Color(0xFF333333),
              fontSize: 14.0,
            ),
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
            style: TextStyle(
              fontSize: 14.4,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFE0E0E0)
                  : const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8.0),
          DropdownButtonFormField<String>(
            value: value,
            onChanged: onChanged,
            items: items.map<DropdownMenuItem<String>>((item) {
              return DropdownMenuItem<String>(
                value: item.toLowerCase(),
                child: Text(item),
              );
            }).toList(),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF555555)
                      : const Color(0xFFCCCCCC),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF555555)
                      : const Color(0xFFCCCCCC),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: const BorderSide(
                  color: Color(0xFF347AB7),
                  width: 2.0,
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14.0,
            color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8.0),
        _ThemeToggle(
          currentTheme: currentTheme,
          onChanged: (mode) {
            ThemeService.updateTheme(ref, mode);
          },
        ),
      ],
    );
  }
}

// Custom accordion widget for settings
class _SettingsAccordion extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _SettingsAccordion({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  State<_SettingsAccordion> createState() => _SettingsAccordionState();
}

class _SettingsAccordionState extends State<_SettingsAccordion> {
  late bool _isExpanded;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
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
                    turns: _isExpanded ? 0.25 : 0.0, // 0.25 turns = 90 degrees
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
                      widget.title,
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFEEEEEE) : const Color(0xFF333333),
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
                children: widget.children,
              ),
            ),
        ],
      ),
    );
  }
}

// Three-way toggle button widget for theme selection
class _ThemeToggle extends StatelessWidget {
  final ThemeMode currentTheme;
  final Function(ThemeMode) onChanged;

  const _ThemeToggle({
    required this.currentTheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC),
        ),
        borderRadius: BorderRadius.circular(6.0),
        color: isDark ? const Color(0xFF3A3A3A) : Colors.white,
      ),
      padding: const EdgeInsets.all(4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeToggleButton(
            label: 'System',
            isSelected: currentTheme == ThemeMode.system,
            onTap: () => onChanged(ThemeMode.system),
          ),
          const SizedBox(width: 10.0),
          _ThemeToggleButton(
            label: 'Light',
            isSelected: currentTheme == ThemeMode.light,
            onTap: () => onChanged(ThemeMode.light),
          ),
          const SizedBox(width: 10.0),
          _ThemeToggleButton(
            label: 'Dark',
            isSelected: currentTheme == ThemeMode.dark,
            onTap: () => onChanged(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

// Individual toggle button within the three-way toggle
class _ThemeToggleButton extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<_ThemeToggleButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color backgroundColor;
    Color textColor;

    if (widget.isSelected) {
      backgroundColor = const Color(0xFF347AB7); // Primary color
      textColor = Colors.white;
    } else if (_isHovering) {
      backgroundColor = isDark
          ? const Color(0x26529EDA) // rgba(82, 158, 218, 0.15)
          : const Color(0x1A347AB8); // rgba(52, 122, 184, 0.1)
      textColor = isDark
          ? const Color(0xFF999999)
          : const Color(0xFF666666);
    } else {
      backgroundColor = Colors.transparent;
      textColor = isDark
          ? const Color(0xFF999999)
          : const Color(0xFF666666);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: widget.isSelected ? FontWeight.w500 : FontWeight.normal,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
