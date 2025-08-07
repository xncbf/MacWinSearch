# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MacWinSearch is a macOS window switcher utility that provides Spotlight-like search functionality for quickly finding and switching between application windows. It's built with Swift/SwiftUI and requires macOS 12.0+.

## Development Commands

### Building and Running
```bash
# Build the project
swift build

# Run the application
swift run

# Build for release
swift build -c release

# Open in Xcode (if needed)
open Package.swift
```

### Testing
No test suite currently exists. When adding tests, follow Swift Package Manager conventions by placing them in `Tests/MacWinSearchTests/`.

## Architecture Overview

The application follows an MVVM pattern with three core components that require understanding their interactions:

### Component Interaction Flow
1. **MacWinSearchApp** (App Entry) → Sets up system integration (status bar, global hotkey)
2. **WindowManager** (Business Logic) → Discovers windows via Accessibility API, manages search state
3. **SearchView** (UI) → Presents searchable window list, handles user interaction

### Key Architectural Decisions

**System Integration via AppDelegate**: The app uses `NSApplicationDelegateAdaptor` to bridge SwiftUI with AppKit for system-level features. The AppDelegate manages:
- Global hotkey registration (Option+Tab)
- Status bar item lifecycle
- Popover presentation
- Accessibility permission requests

**Accessibility API Usage**: Window discovery relies heavily on the AX (Accessibility) framework. Key patterns:
- All AX calls are wrapped in permission checks
- Window information is cached and refreshed on popover show
- Error handling for inaccessible windows (system apps, permission issues)

**State Management**: Uses Combine/SwiftUI reactive patterns:
- `WindowManager` is an `ObservableObject` with `@Published` properties
- UI updates automatically when window list or search results change
- Single source of truth for window state

### Critical Implementation Details

**Accessibility Permissions**: The app MUST have accessibility permissions to function. When modifying:
- Always check `AXIsProcessTrusted()` before AX API calls
- Handle permission denial gracefully with user guidance
- The app auto-prompts for permissions on first launch

**Window Switching Logic**: The window activation sequence in `WindowManager.switchToWindow()` is order-dependent:
1. First activate the target application
2. Then raise the specific window
3. This two-step process ensures reliable window focusing across all apps

**Popover Behavior**: The search popover has specific UX requirements:
- Dismisses on escape key or clicking outside
- Maintains focus in search field
- Resets search state when hidden
- 400x300px fixed size for consistent experience

## Common Development Tasks

### Adding New Window Metadata
When extending `WindowInfo` struct, ensure you:
1. Add corresponding AX attribute fetching in `WindowManager.refreshWindows()`
2. Update search logic if the field should be searchable
3. Modify `SearchView` if the field should be displayed

### Modifying Keyboard Shortcuts
Global hotkey is registered in `AppDelegate.applicationDidFinishLaunching()`. To change:
1. Update the `KeyboardShortcuts.Name` extension
2. Modify the default shortcut in registration
3. Consider adding user preferences for customization

### Improving Search Algorithm
Current search is basic substring matching. When enhancing:
- Maintain performance for large window counts (100+ windows)
- Consider fuzzy matching libraries compatible with Swift Package Manager
- Update both title and app name search paths in `WindowManager.searchWindows()`