# System Patterns

## Architecture Overview
Frontend-only Flutter application that replicates the VOX UI design and interactions.

## Key Technical Decisions

### State Management
- **Riverpod** or **Provider** for state management
- Theme mode (system/light/dark) state
- Sidebar open/close state
- Accordion expansion states
- Navigation state (current route)

### Routing
- **GoRouter** or **Navigator 2.0** for declarative routing
- Named routes: `/chat`, `/mcp-servers`, `/settings`
- Deep linking support for navigation

### UI Architecture
- **Material 3** design system for Flutter theming
- Custom widgets for complex UI components
- Separation of concerns between UI logic and business logic
- Responsive design patterns

## Widget Architecture Patterns

### Custom Widgets Structure
```
lib/
├── widgets/
│   ├── orb_widget.dart          # OrbWidget (solid circle placeholder)
│   ├── sidebar/
│   │   ├── sidebar_drawer.dart   # Main sidebar component
│   │   └── overlay_scrim.dart    # Blur overlay for sidebar
│   ├── accordions/
│   │   ├── accordion_group.dart  # Accordion container
│   │   └── accordion_item.dart   # Individual accordion item
│   ├── navigation/
│   │   └── nav_item.dart         # Navigation list items
│   └── theme/
│       └── theme_selector.dart   # Theme switcher widget
├── screens/
│   ├── chat_screen.dart          # Chat page with orb and input
│   ├── mcp_servers_screen.dart   # MCP Servers with accordion list
│   └── settings_screen.dart      # Settings with grouped accordions
├── models/
│   └── theme_model.dart          # Theme state model
└── providers/
    └── theme_provider.dart       # State management
```

### Component Patterns
- **OrbWidget**: Custom widget with controller interface (placeholder for future state)
- **SidebarDrawer**: Slide-in navigation drawer with backdrop
- **AccordionGroup**: Vertical stack of expandable sections
- **ThemeSelector**: Radio buttons or toggle for theme switching

## State Management Patterns

### Theme Management
- Centralized theme state via Provider/Riverpod
- System theme detection
- Live theme switching without app restart
- Persistent theme preference (if needed in future)

### UI State
- Sidebar visibility state
- Accordion expansion states
- Current navigation route
- All state is in-memory (no persistence for Phase 1)

## Design Patterns Applied

### Factory Pattern
- Theme creation and management
- Widget factories for consistent styling

### Observer Pattern
- State changes trigger UI rebuilds
- Theme changes propagate to all widgets

### Singleton Pattern
- Theme service (if needed)
- Navigation service

### Builder Pattern
- Complex widget construction
- Theme-aware widget building

## Visual Design System

### Color Palette
```css
/* Primary Colors */
--primary-color: #347ab8;           /* Primary blue */
--primary-color-hover: #2a6194;     /* Darker blue for hover */

/* Theme Colors */
--bg-color: #ffffff;                /* Main background */
--text-color: #333333;              /* Primary text */
--text-color-light: #666666;        /* Secondary text */
--text-color-dark: #cccccc;         /* Disabled text */

/* UI Elements */
--border-color: #eeeeee;            /* Borders */
--border-color-dark: #444444;       /* Dark theme borders */
--header-bg: #ffffff;               /* Navigation background */
--header-bg-dark: #252526;          /* Dark navigation */
--sidebar-bg: #ffffff;              /* Sidebar background */
--sidebar-bg-dark: #252526;         /* Dark sidebar */
--input-controls-bg: #ffffff;       /* Input area background */
--input-controls-bg-dark: #1e1e1e;  /* Dark input area */
```

### Typography Scale
- **Navigation Title**: 1.25rem, font-weight: 500
- **Section Headers**: 1.0rem, font-weight: 500
- **Body Text**: 0.9rem, font-weight: 400
- **Status Text**: 0.9rem, font-weight: 400, opacity: 0.9
- **Labels**: 0.9rem, font-weight: 500

### Spacing System
- **Container Padding**: 20px horizontal
- **Section Spacing**: 24px
- **Element Gaps**: 12px (buttons), 16px (form fields)
- **Border Radius**: 12px (inputs/buttons), 6px (icons)
- **Nav Height**: 60px
- **Sidebar Width**: 160px

### Animation & Transitions
- **Duration**: 0.2s - 0.3s for most interactions
- **Easing**: ease (smooth transitions)
- **Sidebar Animation**: translateX with 0.3s duration
- **Overlay Animation**: opacity + backdrop-filter blur
- **Hover Effects**: opacity changes (0.6 → 0.8 → 1.0)

### Component Specifications

#### Navigation Bar
- **Height**: 60px fixed
- **Background**: var(--header-bg)
- **Border**: 1px solid var(--border-color)
- **Padding**: 0 20px
- **Hamburger Menu**: 8px padding, hover background

#### Sidebar
- **Width**: 160px fixed
- **Background**: var(--sidebar-bg)
- **Border**: 1px solid var(--sidebar-border)
- **Animation**: translateX(-100%) → translateX(0)
- **Item Spacing**: 2px gap, 14px vertical padding
- **Active State**: 3px left border in primary color

#### Main Content Area
- **Background**: var(--bg-color)
- **Flex Layout**: Centered content with padding
- **Overflow**: Hidden for proper scrolling

#### Input Controls (Bottom)
- **Height**: 60px fixed
- **Background**: var(--input-controls-bg)
- **Border**: 1px solid var(--input-controls-border)
- **Padding**: 0 32px
- **Button Size**: 36px diameter, 8px padding

#### Orb Widget
- **Shape**: Perfect circle (solid color for Phase 1)
- **Size**: Variable (based on screen size)
- **Background**: Sophisticated gradient or solid color
- **Border**: Subtle border/shadow for depth
- **Status Effects**: Positioned absolutely for animations

#### Accordion Components
- **Header**: Clickable with hover states
- **Icon**: Chevron rotation animation
- **Content**: Slide down/up animation
- **Spacing**: Consistent padding and margins
- **Borders**: Subtle separators between sections

#### Form Elements
- **Input Fields**: 12px border radius, consistent padding
- **Focus States**: Primary color border/highlight
- **Dropdowns**: Native styling with custom arrows
- **Labels**: Proper spacing and typography

## Code Organization Principles
- **Separation of concerns**: UI logic separate from business logic
- **Single responsibility**: Each widget has one clear purpose
- **DRY (Don't Repeat Yourself)**: Common patterns extracted to reusable components
- **SOLID principles**: Maintainable and extensible code structure

## Future Integration Points (Phase 2)
- OrbWidget controller integration with LiveKit/MCP
- WebSocket connections for real-time data
- Backend API integration
- Persistent storage for settings