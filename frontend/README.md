# RG Smart Control

A Flutter application for monitoring and controlling RG Smart Control systems.

## App Rename — rv_demo → RG Smart Control (Mar 5, 2026)

The app was renamed from `rv_demo` to **RG Smart Control** (`rg_smart_control`). The following files were updated:

### Dart / Package
| File | Change |
|------|--------|
| `pubspec.yaml` | `name: rv_demo` → `name: rg_smart_control`; description updated |
| All `lib/` + `test/` `.dart` files | `package:rv_demo/` → `package:rg_smart_control/` (bulk replace) |
| `lib/main.dart` | `MaterialApp.router` `title:` → `'RG Smart Control'` |
| `lib/Views/main_view.dart` | Splash screen heading → `'RG Smart Control'` |
| `lib/Views/SignInScreen.dart` | Welcome + sign-in success dialog strings updated |

### Android
| File | Change |
|------|--------|
| `android/app/build.gradle.kts` | `namespace` + `applicationId` → `com.rgsmartcontrol.app` |
| `android/app/src/main/AndroidManifest.xml` | `android:label` → `RG Smart Control` |
| `android/app/src/main/kotlin/.../MainActivity.kt` | `package` → `com.rgsmartcontrol.app` |
| `android/app/google-services.json` | Regenerated via `flutterfire configure` |

### iOS
| File | Change |
|------|--------|
| `ios/Runner/Info.plist` | `CFBundleDisplayName` → `RG Smart Control`; `CFBundleName` → `rg_smart_control` |
| `ios/Runner.xcodeproj/project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER` → `com.rgsmartcontrol.app` |
| `ios/Runner/GoogleService-Info.plist` | Regenerated via `flutterfire configure` |

### macOS
| File | Change |
|------|--------|
| `macos/Runner/Configs/AppInfo.xcconfig` | `PRODUCT_NAME`, `PRODUCT_BUNDLE_IDENTIFIER` → `com.rgsmartcontrol.app`; copyright updated |
| `macos/Runner.xcodeproj/project.pbxproj` | Bundle IDs and product references updated |

### Windows
| File | Change |
|------|--------|
| `windows/CMakeLists.txt` | `project` + `BINARY_NAME` → `rg_smart_control` |
| `windows/runner/Runner.rc` | `FileDescription`, `InternalName`, `ProductName`, `OriginalFilename`, company/copyright strings |

### Linux
| File | Change |
|------|--------|
| `linux/CMakeLists.txt` | `BINARY_NAME` + `APPLICATION_ID` → `com.rgsmartcontrol.app` |

### Web
| File | Change |
|------|--------|
| `web/manifest.json` | `name`, `short_name`, `description` updated |
| `web/index.html` | `<title>`, `apple-mobile-web-app-title`, meta description updated |

### Firebase
| File | Change |
|------|--------|
| `lib/firebase_options.dart` | Regenerated via `flutterfire configure` |
| `android/app/google-services.json` | Regenerated via `flutterfire configure` |
| `ios/Runner/GoogleService-Info.plist` | Regenerated via `flutterfire configure` |

Firebase project (`rg-smart-control-system`) was unchanged; only the registered app entries (Android package + iOS/macOS bundle ID) were updated in the Firebase Console.

## Getting Started

- [Flutter documentation](https://docs.flutter.dev/)
- [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup)
