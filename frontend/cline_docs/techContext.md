# Technical Context

## Technologies Used

### Core Framework
- **Flutter**: Main UI framework for building the cross-platform application
- **Dart**: Programming language for Flutter development

### State Management (Decision Required)
- **Riverpod** (Recommended): Type-safe, reactive state management
  - Alternative: **Provider** (Simpler but less powerful)
- **flutter_riverpod** package for dependency injection and state management

### Routing & Navigation
- **GoRouter** (Recommended): Declarative routing with deep linking
  - Alternative: **Navigator 2.0** (Built-in but more complex)
- **go_router** package for advanced routing features

### UI & Theming
- **Material 3**: Modern Material Design system
- **flutter/material.dart**: Core Material widgets
- **ThemeData**: Centralized theming system

### Development Tools
- **VS Code**: Primary development environment
- **Flutter Extension**: VS Code Flutter tools and debugger
- **Dart Extension**: Dart language support and analysis

## Development Setup

### Prerequisites
- **Flutter SDK**: Latest stable version (3.0+ recommended)
- **Dart SDK**: Comes with Flutter installation
- **VS Code**: With Flutter and Dart extensions
- **Android Studio** (for Android emulation) or **Xcode** (for iOS)

### Installation Commands
```bash
# Install Flutter SDK (if not already installed)
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor
flutter --version

# Enable web support (for development)
flutter config --enable-web
```

### Project Creation
1. **VS Code Command Palette**: `Ctrl+Shift+P`
2. **Flutter: New Project** → **Application**
3. Project name: `vox_ui_flutter`
4. Use default template structure

### Development Workflow
```bash
# Get dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Run on web with FIXED PORT (REQUIRED for localStorage persistence)
# IMPORTANT: Always use --web-port=8080 to ensure settings persist
flutter run -d chrome --web-port=8080

# Hot reload during development
# Changes are reflected instantly in running app

# Build for production
flutter build apk  # Android
flutter build ios  # iOS
flutter build web  # Web
```

### Web Development Important Note
**CRITICAL**: When running the web app in Chrome for development, **always use a fixed port number** (`--web-port=8080`).

**Why?** Flutter's default behavior uses random ports (e.g., `localhost:2026`, then `localhost:5234` on the next run), which causes localStorage to be isolated per port. This means settings saved on one port won't be available on another port, making it appear as if localStorage is being cleared.

**Solution**: Using `--web-port=8080` ensures:
- Settings save to `localhost:8080`
- Settings load from `localhost:8080` on every run
- localStorage persists across app restarts
- Consistent development experience

**Default Port**: `8080` (documented standard for this project)

## Technical Constraints

### Phase 1 Limitations
- **Frontend-only**: No backend integration, no WebSocket connections
- **No audio**: No sound input/output or audio processing
- **No LiveKit**: No real-time communication features
- **No MCP integration**: No Model Context Protocol server connections
- **No persistence**: All state is in-memory only

### Flutter-Specific Constraints
- **Platform compatibility**: Target Android, iOS, and Web platforms
- **Material Design**: Use Material 3 design system for consistency
- **Performance**: Optimize for smooth animations and transitions
- **Responsive design**: Handle different screen sizes appropriately

### Visual Fidelity Requirements
- **Match existing web UI**: Colors, spacing, typography, and animations
- **Approximations allowed**: Use closest Material Design values when exact matches aren't available
- **Comment approximations**: Add `// approx` comments for design decisions
- **Theme consistency**: Implement system/light/dark theme matching

## Package Dependencies (Planned)

### Core Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  riverpod: ^2.4.9  # State management
  go_router: ^12.1.3  # Routing
  flutter_riverpod: ^2.4.9  # Riverpod for Flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1  # Code linting
```

### Optional Future Dependencies (Phase 2)
```yaml
# Audio processing (future)
# flutter_sound: ^9.2.13

# WebSocket connections (future)
# web_socket_channel: ^2.4.0

# HTTP client (future)
# dio: ^5.3.2

# Local storage (future)
# shared_preferences: ^2.2.2
```

## Development Environment

### VS Code Configuration
- **Flutter Extension**: Provides code completion, debugging, and device management
- **Dart Extension**: Language server for Dart analysis and refactoring
- **Settings**: Configure for Flutter development best practices

### Device Testing
- **Android Emulator**: For Android development and testing
- **iOS Simulator**: For iOS development (macOS only)
- **Web Browser**: Chrome for web development and design reference
- **Physical Devices**: For final testing and optimization

### Code Quality
- **Dart Analysis**: Built-in static analysis for code quality
- **Flutter Lints**: Consistent code style and best practices
- **Testing**: Unit tests for business logic, widget tests for UI components

## Build and Deployment

### Development Builds
```bash
# Run in debug mode
flutter run

# Enable performance overlay
flutter run --profile
```

### Release Builds
```bash
# Build optimized APK
flutter build apk --release

# Build App Bundle (preferred for Play Store)
flutter build appbundle --release

# Build for iOS
flutter build ios --release
```

### Web Builds (for reference)
```bash
# Build optimized web app
flutter build web --release

# Serve locally for testing
flutter run -d chrome --release