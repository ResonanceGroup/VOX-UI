import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:monaco_editor/monaco_editor.dart';

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
  
  // MCP Config state
  final _monacoController = MonacoEditorController();
  final _mcpEditorFocusNode = FocusNode();
  bool _mcpEditorFocused = false;
  String _originalMcpConfig = '';
  String _currentMcpConfig = '';
  bool _mcpConfigModified = false;

  @override
  void initState() {
    super.initState();
    _loadMcpConfig();
    // Listen for focus changes to detect when editor loses focus
    _mcpEditorFocusNode.addListener(() {
      if (!_mcpEditorFocusNode.hasFocus && _mcpEditorFocused) {
        setState(() {
          _mcpEditorFocused = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _mcpEditorFocusNode.dispose();
    super.dispose();
  }

  void _loadMcpConfig() {
    // TODO: Load actual config from backend
    const sampleConfig = '''{
  "mcpServers": {
    "brave-search": {
      "command": "node",
      "args": [
        "C:\\\\Users\\\\Jason\\\\AppData\\\\Roaming\\\\npm\\\\node_modules\\\\@modelcontextprotocol\\\\server-brave-search\\\\dist\\\\index.js"
      ],
      "env": {
        "BRAVE_API_KEY": "your-api-key-here"
      }
    }
  }
}''';
    _originalMcpConfig = sampleConfig;
    _currentMcpConfig = sampleConfig;
    _monacoController.setText(sampleConfig);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update Monaco theme when app theme changes
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _monacoController.initialize(
      MonacoEditorOptions(
        language: MonacoLanguage.json,
        theme: isDark ? MonacoTheme.vsDark : MonacoTheme.vs,
      ),
    );
  }

  void _saveMcpConfig() async {
    // Get current text from editor
    final text = await _monacoController.getText();
    // TODO: Implement actual save to backend
    setState(() {
      _originalMcpConfig = text;
      _currentMcpConfig = text;
      _mcpConfigModified = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('MCP config saved successfully!')),
    );
  }

  void _revertMcpConfig() {
    _monacoController.setText(_originalMcpConfig);
    setState(() {
      _currentMcpConfig = _originalMcpConfig;
      _mcpConfigModified = false;
    });
  }

  void _copyMcpConfig() async {
    final text = await _monacoController.getText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Config copied to clipboard!')),
    );
  }

  Future<void> _checkForChanges() async {
    final text = await _monacoController.getText();
    setState(() {
      _currentMcpConfig = text;
      _mcpConfigModified = _currentMcpConfig != _originalMcpConfig;
    });
  }

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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MCP Config (JSON)',
                            style: TextStyle(
                              fontSize: 14.4,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFFE0E0E0)
                                  : const Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          // Monaco Editor - rounded on all corners with focus indication
                          Focus(
                            focusNode: _mcpEditorFocusNode,
                            descendantsAreFocusable: false,
                            child: Listener(
                              onPointerDown: (_) {
                                setState(() {
                                  _mcpEditorFocused = true;
                                });
                                _mcpEditorFocusNode.requestFocus();
                              },
                              child: Container(
                                height: 400.0,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  border: Border.all(
                                    color: _mcpEditorFocused
                                        ? const Color(0xFF347AB7)
                                        : (isDark
                                            ? const Color(0xFF555555)
                                            : const Color(0xFFCCCCCC)),
                                    width: _mcpEditorFocused ? 2.0 : 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6.0),
                                  child: MonacoEditorWidget(
                                    controller: _monacoController,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Action buttons bar - adjusted spacing
                          const SizedBox(height: 16.0),
                          Row(
                            children: [
                              // Copy button on the left
                              IconButton(
                                icon: const Icon(Icons.content_copy, size: 18.0),
                                onPressed: _copyMcpConfig,
                                color: isDark
                                    ? const Color(0xFFCCCCCC)
                                    : const Color(0xFF666666),
                                tooltip: 'Copy to clipboard',
                                padding: const EdgeInsets.all(8.0),
                                constraints: const BoxConstraints(),
                              ),
                              const Spacer(),
                              // Save and Revert buttons on the right
                              _buildButton(
                                label: 'Save',
                                isPrimary: true,
                                onPressed: () async {
                                  await _checkForChanges();
                                  if (_mcpConfigModified) {
                                    _saveMcpConfig();
                                  }
                                },
                              ),
                              const SizedBox(width: 12.0),
                              _buildButton(
                                label: 'Revert',
                                isPrimary: false,
                                onPressed: () async {
                                  await _checkForChanges();
                                  if (_mcpConfigModified) {
                                    _revertMcpConfig();
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
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
    required VoidCallback? onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = onPressed == null;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled
            ? (isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0))
            : (isPrimary
                ? const Color(0xFF347AB7)
                : (isDark ? const Color(0xFF444444) : const Color(0xFFF0F0F0))),
        foregroundColor: isDisabled
            ? (isDark ? const Color(0xFF666666) : const Color(0xFF999999))
            : (isPrimary
                ? Colors.white
                : (isDark ? const Color(0xFFCCCCCC) : const Color(0xFF555555))),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6.0),
          side: BorderSide(
            color: isDisabled
                ? Colors.transparent
                : (isPrimary
                    ? Colors.transparent
                    : (isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC))),
            width: 1.0,
          ),
        ),
        elevation: 0,
        disabledBackgroundColor: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0),
        disabledForegroundColor: isDark ? const Color(0xFF666666) : const Color(0xFF999999),
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

class _SettingsAccordionState extends State<_SettingsAccordion>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  bool _isHovering = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: isDark ? AppTheme.accordionBorderDarkColor : AppTheme.accordionBorderColor,
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
                  if (_isExpanded) {
                    _animationController.forward();
                  } else {
                    _animationController.reverse();
                  }
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
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
              color: isDark ? AppTheme.accordionBorderDarkColor : AppTheme.accordionBorderColor,
            ),
          // Animated expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
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
