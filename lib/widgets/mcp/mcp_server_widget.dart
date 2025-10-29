import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'mcp_tool_widget.dart';

class McpServerWidget extends StatefulWidget {
  final String name;
  final String status;
  final Color statusColor;
  final List<ToolData> tools;
  final List<ResourceData> resources;
  final bool isEnabled;
  final ValueChanged<bool>? onEnabledChanged;
  final String networkTimeout;
  final ValueChanged<String?>? onTimeoutChanged;

  const McpServerWidget({
    super.key,
    required this.name,
    required this.status,
    required this.statusColor,
    required this.tools,
    required this.resources,
    this.isEnabled = true,
    this.onEnabledChanged,
    this.networkTimeout = '1 minute',
    this.onTimeoutChanged,
  });

  @override
  State<McpServerWidget> createState() => _McpServerWidgetState();
}

class _McpServerWidgetState extends State<McpServerWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isHovering = false;
  int _selectedTab = 0; // 0 = Tools, 1 = Resources
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
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
          // Server header
          MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: GestureDetector(
              onTap: _toggleExpanded,
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    // Animated chevron icon
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
                    // Toggle switch with custom inactive colors and no border
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: widget.isEnabled,
                        onChanged: widget.onEnabledChanged,
                        activeColor: const Color(0xFF347AB8),
                        inactiveThumbColor: isDark ? const Color(0xFF888888) : const Color(0xFFBBBBBB),
                        inactiveTrackColor: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
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
                children: [
                  // Tools and Resources tabs - Roo Code style
                  Row(
                    children: [
                      _buildTab('Tools', widget.tools.length, 0, isDark),
                      const SizedBox(width: 24.0),
                      _buildTab('Resources', widget.resources.length, 1, isDark),
                    ],
                  ),
                  const SizedBox(height: 16.0),

                  // Tool/Resource list
                  if (_selectedTab == 0 && widget.tools.isNotEmpty)
                    ...widget.tools.map((tool) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: McpToolWidget(
                        name: tool.name,
                        description: tool.description,
                        parameters: tool.parameters,
                        isAlwaysAllowed: tool.isAlwaysAllowed,
                        onAlwaysAllowChanged: tool.onAlwaysAllowChanged,
                      ),
                    ))
                  else if (_selectedTab == 1 && widget.resources.isNotEmpty)
                    Text(
                      'No resources available',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF999999) : const Color(0xFF666666),
                      ),
                    )
                  else
                    Text(
                      'No items available',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF999999) : const Color(0xFF666666),
                      ),
                    ),

                  const SizedBox(height: 16.0),

                  // Network Timeout dropdown at the end
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Network Timeout',
                          style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          height: 36.0, // Fixed height to prevent tall dropdown
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                            borderRadius: BorderRadius.circular(6.0),
                            border: Border.all(
                              color: isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: widget.networkTimeout,
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                              style: TextStyle(
                                fontSize: 13.0,
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
                              onChanged: widget.onTimeoutChanged,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Maximum time to wait for server responses',
                          style: TextStyle(
                            fontSize: 12.0,
                            color: isDark ? const Color(0xFF888888) : const Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
}

// Data models
class ToolData {
  final String name;
  final String? description;
  final List<ToolParameter> parameters;
  final bool isAlwaysAllowed;
  final ValueChanged<bool>? onAlwaysAllowChanged;

  const ToolData({
    required this.name,
    this.description,
    required this.parameters,
    this.isAlwaysAllowed = true,
    this.onAlwaysAllowChanged,
  });
}

class ResourceData {
  final String name;
  final String? description;

  const ResourceData({
    required this.name,
    this.description,
  });
}