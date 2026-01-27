# System Patterns

## Architecture Overview
Frontend-only Flutter application that replicates the VOX UI design and interactions with 95% visual fidelity to the original web UI.

## Key Technical Decisions

### State Management
- **Riverpod** for centralized theme state management
- Theme mode (system/light/dark) state with reactive updates
- Accordion expansion states managed locally in StatefulWidgets
- Navigation state handled by GoRouter

### Routing
- **GoRouter** for declarative routing
- Named routes: `/` (chat), `/mcp-servers`, `/settings`
- Deep linking support with proper route configuration
- Context-based navigation with `context.go()`

### UI Architecture
- **Material 3** design system for Flutter theming
- Custom widgets for complex UI components (OrbWidget, NavigationDrawer)
- Separation of concerns between UI and business logic
- Responsive design patterns with MediaQuery
- Theme-aware components using `Theme.of(context)`

## Widget Architecture Patterns

### Project Structure
```
lib/
├── main.dart                       # App entry, GoRouter, theme setup
├── providers/
│   └── theme_provider.dart         # Riverpod theme state management
├── theme/
│   └── app_theme.dart              # Light/dark theme definitions
├── widgets/
│   ├── navigation_drawer.dart      # Custom drawer with blur overlay
│   └── orb_widget.dart            # Placeholder orb (solid circle)
└── screens/
    ├── chat_screen.dart            # Chat UI with orb and input
    ├── mcp_servers_screen.dart     # MCP server accordion list
    └── settings_screen.dart        # Settings with grouped accordions
```

### Component Patterns

#### OrbWidget (lib/widgets/orb_widget.dart)
- Custom widget with simple circular Container
- Solid color placeholder for Phase 1
- Controller interface documented for future state integration
- Positioned centrally on chat screen

#### NavigationDrawer (lib/widgets/navigation_drawer.dart)
- Custom Drawer widget with BackdropFilter blur effect
- Width: 250px, no border radius
- Menu items only (no header title)
- Active route highlighting with primary color
- Blur overlay: `ImageFilter.blur(sigmaX: 10, sigmaY: 10)`

#### Accordion Components (ExpansionTile)
- Used in both Settings and MCP Servers screens
- Custom styling to remove default borders
- Scrollable content with SingleChildScrollView
- Chevron icon rotation on expand/collapse
- Theme-aware colors for headers and content

#### Theme Selector (SegmentedButton)
- Three-way slider: System / Light / Dark
- No rounded corners on individual segments
- Proper selected/unselected states
- Instant theme switching on selection
- Located in Settings > General UI section

## State Management Patterns

### Theme Management (Riverpod)
```dart
// providers/theme_provider.dart
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system);
  
  void setTheme(ThemeMode mode) {
    state = mode;
  }
}

// Usage in widgets
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    // Widget builds with current theme
  }
}
```

### UI State Management
- Sidebar visibility: Handled by Scaffold drawer mechanism
- Accordion expansion: Local StatefulWidget state
- Current navigation: GoRouter's location state
- All state is in-memory (no persistence in Phase 1)

## Design Patterns Applied

### Factory Pattern
- Theme creation: `AppTheme.lightTheme` and `AppTheme.darkTheme`
- Widget factories for consistent styling across screens

### Observer Pattern
- Riverpod state changes trigger UI rebuilds
- Theme changes propagate to all consumer widgets
- GoRouter navigation updates all route-aware widgets

### Builder Pattern
- Complex widget construction with proper theme awareness
- Scaffold builders for consistent screen structure

## Visual Design System (As Implemented)

### Color Palette
```dart
// theme/app_theme.dart

// Light Mode
Primary: #347ab8 (Color(0xFF347AB8))
Background: #FFFFFF (Colors.white)
Surface: #FFFFFF (Colors.white)
Text: #333333 (Color(0xFF333333))
Border: #E5E5E5 (Color(0xFFE5E5E5))
Panel Background: #F5F5F5 (Color(0xFFF5F5F5))

// Dark Mode
Primary: #347ab8 (Color(0xFF347AB8))
Background: #1E1E1E (Color(0xFF1E1E1E))
Surface: #252526 (Color(0xFF252526))
Text: #CCCCCC (Color(0xFFCCCCCC))
Border: #333333 (Color(0xFF333333))
Panel Background: #252526 (Color(0xFF252526))
```

### Typography Scale
```dart
// Implemented via Material 3 TextTheme
titleLarge: 20px (1.25rem equivalent) - Navigation titles
titleMedium: 16px (1.0rem equivalent) - Section headers
bodyMedium: 14.4px (0.9rem equivalent) - Body text
bodySmall: 14.4px (0.9rem equivalent) - Status text
labelLarge: 14.4px (0.9rem equivalent) - Button labels
```

### Spacing System
```dart
// Applied throughout the app
Container Padding: 20px (EdgeInsets.all(20))
Section Spacing: 24px (SizedBox(height: 24))
Element Gaps: 12px (gap in Flex widgets)
Form Field Spacing: 16px (SizedBox(height: 16))

// Border Radius
Input Fields: 12px (BorderRadius.circular(12))
Buttons: 12px (BorderRadius.circular(12))
Drawer: 0px (BorderRadius.zero)
```

### Component Specifications

#### Navigation Bar (AppBar)
- Height: Default Material AppBar height (~56px)
- Background: Theme-based (white/dark)
- Border: Bottom divider
- Leading: Hamburger menu icon
- No trailing actions (settings icon removed)

#### Sidebar Drawer
```dart
width: 250
borderRadius: BorderRadius.zero  // No rounded corners
BackdropFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10)
```

#### Main Content Area
- Background: Theme-based background color
- Flex layout: Column with centered content
- Padding: 20px horizontal
- Scrollable: SingleChildScrollView where needed

#### Input Controls (Chat Screen)
```dart
TextField(
  decoration: InputDecoration(
    border: InputBorder.none,  // No border
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
  ),
)

Send Button:
  - IconButton with arrow icon
  - Primary blue color
  - No circular background
  - Size: 24x24 icon
```

#### Orb Widget
```dart
Container(
  width: 200,
  height: 200,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: Theme.of(context).colorScheme.primary,
  ),
)
```

#### Accordion Components (ExpansionTile)
```dart
ExpansionTile(
  tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  childrenPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  // Custom decoration to remove borders
  decoration: BoxDecoration(border: Border.all(width: 0)),
)
```

#### Form Elements
```dart
Button Heights: 42px (minHeight in ButtonStyle)
Border Radius: 12px for inputs and buttons
DropdownButton: Custom styling with theme colors
TextField: Outlined with focus states
```

### Animation & Transitions
```dart
// Drawer Animation (built-in)
Duration: ~300ms
Curve: easeInOut

// Theme Switching
Duration: Instant (no animation needed)

// Accordion Expansion
Duration: Built-in ExpansionTile animation
Curve: Default Material curve
```

## Code Organization Principles

### Separation of Concerns
- Screens handle layout and composition
- Widgets focus on single responsibilities
- Theme logic centralized in app_theme.dart
- State management isolated in providers/

### Single Responsibility
- Each widget has one clear purpose
- OrbWidget: Display circular orb
- NavigationDrawer: Handle sidebar navigation
- Each screen: Manage one page's layout

### DRY (Don't Repeat Yourself)
- Shared theme definitions in AppTheme
- Reusable accordion patterns
- Common button styles extracted
- Consistent spacing using theme values

### SOLID Principles
- Open/Closed: Easy to extend with new screens
- Dependency Inversion: Depend on abstractions (ThemeMode)
- Single Responsibility: Each file has one purpose

## Implementation Details

### Theme Switching Implementation
```dart
// main.dart
MaterialApp.router(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ref.watch(themeProvider),
  routerConfig: router,
)

// User selects theme
onPressed: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.light),
```

### Navigation Implementation
```dart
// main.dart - GoRouter setup
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => ChatScreen()),
    GoRoute(path: '/mcp-servers', builder: (context, state) => McpServersScreen()),
    GoRoute(path: '/settings', builder: (context, state) => SettingsScreen()),
  ],
);

// Navigation usage
onTap: () => context.go('/settings'),
```

### Blur Overlay Implementation
```dart
// navigation_drawer.dart
Stack(
  children: [
    // Blur overlay
    Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(color: Colors.black.withOpacity(0.3)),
      ),
    ),
    // Drawer content
    SafeArea(
      child: Container(
        width: 250,
        color: Theme.of(context).colorScheme.surface,
        // ... drawer content
      ),
    ),
  ],
)
```

### Scrollable Accordion Implementation
```dart
// mcp_servers_screen.dart & settings_screen.dart
SingleChildScrollView(
  child: Column(
    children: [
      ExpansionTile(
        // Scrollable content inside accordion
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Accordion content
              ],
            ),
          ),
        ],
      ),
    ],
  ),
)
```

## Current Implementation Status

### Fully Implemented ✅
- Theme system with three modes
- Navigation between all screens
- Custom drawer with blur overlay
- Accordion components with scrolling
- Form controls with proper styling
- Button heights at 42px
- Borderless text input
- Light/dark mode color schemes
- SegmentedButton theme selector

### Pending Investigation 🔍
- 3-server stacked icon verification
- Drawer fade animation (vs slide)

## Future Integration Points (Phase 2)

### Backend Integration
- Real MCP server connections
- WebSocket communication
- API endpoints for data
- Settings persistence

### Enhanced Features
- OrbWidget LiveKit integration
- Real-time state updates
- Audio input/output
- Voice agent selection
- n8n workflow integration

### Advanced UI
- Animated orb states
- Connection status indicators
- Progress indicators
- Toast notifications
- Error handling UI

## Testing Strategy (Future)

### Unit Tests
- Theme provider logic
- State management
- Navigation routing

### Widget Tests
- Individual widget rendering
- Theme switching
- Accordion behavior
- Form validation

### Integration Tests
- Full user flows
- Screen navigation
- Theme persistence
- Settings management

## Performance Considerations

### Current Optimizations
- Minimal rebuilds with Riverpod
- Efficient theme switching
- Lazy loading of screens
- Proper widget keys

### Future Optimizations
- Image caching
- Network request optimization
- State persistence
- Memory management