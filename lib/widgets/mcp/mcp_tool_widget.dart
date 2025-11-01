import 'package:flutter/material.dart';

class McpToolWidget extends StatelessWidget {
  final String name;
  final String? description;
  final List<ToolParameter> parameters;
  final bool isAlwaysAllowed;
  final ValueChanged<bool>? onAlwaysAllowChanged;

  const McpToolWidget({
    super.key,
    required this.name,
    this.description,
    required this.parameters,
    this.isAlwaysAllowed = true,
    this.onAlwaysAllowChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        // Distinct background color from parent server card
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tool header with icon and toggle
          Row(
            children: [
              const Icon(Icons.build, size: 18.0, color: Color(0xFF888888)),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 4.0),
                      Text(
                        description!,
                        style: TextStyle(
                          fontSize: 13.0,
                          color: isDark ? const Color(0xFF999999) : const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: isAlwaysAllowed,
                  onChanged: onAlwaysAllowChanged,
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
          
          if (parameters.isNotEmpty) ...[
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
            ...parameters.map((param) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildParameter(param.name, param.description, isDark),
            )),
          ],
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
}

class ToolParameter {
  final String name;
  final String description;

  const ToolParameter({
    required this.name,
    required this.description,
  });
}