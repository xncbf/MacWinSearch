import Foundation
import AppKit
import ApplicationServices

class WindowManager: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var filteredWindows: [WindowInfo] = []
    @Published var searchText: String = ""
    @Published var needsFocus: Bool = false
    
    struct WindowInfo: Identifiable {
        let id = UUID()
        let title: String
        let appName: String
        let appIcon: NSImage?
        let windowRef: AXUIElement
        let pid: pid_t
    }
    
    func refreshWindows() {
        windows = getAllWindows()
        filteredWindows = windows
    }
    
    func searchWindows(query: String) {
        if query.isEmpty {
            filteredWindows = windows
        } else {
            filteredWindows = windows.filter { window in
                window.title.localizedCaseInsensitiveContains(query) ||
                window.appName.localizedCaseInsensitiveContains(query)
            }
        }
    }
    
    private func getAllWindows() -> [WindowInfo] {
        var windowList: [WindowInfo] = []
        var processedWindows = Set<String>() // Track processed windows to avoid duplicates
        
        // Check accessibility permissions first
        guard AXIsProcessTrusted() else {
            print("Accessibility permissions not granted")
            return []
        }
        
        // Step 1: Get ALL windows from CGWindowList (includes fullscreen windows in other spaces)
        let options = CGWindowListOption(arrayLiteral: [.excludeDesktopElements])
        let windowListRef = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
        
        if let windowInfoList = windowListRef as? [[String: Any]] {
            print("\n📊 CGWindowList found \(windowInfoList.count) total windows")
            
            // Group windows by PID
            var windowsByPID: [pid_t: [(dict: [String: Any], index: Int)]] = [:]
            
            for (index, windowDict) in windowInfoList.enumerated() {
                // Get basic window info first
                let ownerPID = windowDict[kCGWindowOwnerPID as String] as? Int32 ?? -1
                let layer = windowDict[kCGWindowLayer as String] as? Int ?? -1
                let windowName = windowDict[kCGWindowName as String] as? String ?? ""
                let windowNumber = windowDict[kCGWindowNumber as String] as? Int ?? 0
                
                // Get all attributes
                let isOnScreen = windowDict[kCGWindowIsOnscreen as String] as? Bool ?? false
                let alpha = windowDict[kCGWindowAlpha as String] as? CGFloat ?? 1.0
                let storeType = windowDict[kCGWindowStoreType as String] as? Int ?? 0
                let bounds = windowDict[kCGWindowBounds as String] as? [String: Any]
                let width = bounds?["Width"] as? CGFloat ?? 0
                let height = bounds?["Height"] as? CGFloat ?? 0
                
                // Get app name for debugging
                var appName = "Unknown"
                if let app = NSRunningApplication(processIdentifier: ownerPID) {
                    appName = app.localizedName ?? "Unknown"
                }
                
                // Debug: Print ALL window info with exclusion reasons
                var excludeReasons: [String] = []
                
                if ownerPID == -1 {
                    excludeReasons.append("no PID")
                }
                if layer != 0 {
                    excludeReasons.append("layer=\(layer)")
                }
                if !isOnScreen {
                    // excludeReasons.append("not onScreen")
                }
                if alpha <= 0 {
                    excludeReasons.append("alpha=\(alpha)")
                }
                if width <= 0 || height <= 0 {
                    excludeReasons.append("zero size")
                }
                if width < 50 && height < 50 {
                    excludeReasons.append("too small (\(width)x\(height))")
                }
                
                let emoji = excludeReasons.isEmpty ? "✅" : "❌"
                let status = excludeReasons.isEmpty ? "INCLUDED" : "EXCLUDED: \(excludeReasons.joined(separator: ", "))"
                print("  \(emoji) Window #\(windowNumber): '\(windowName)' [\(appName)] (Size: \(width)x\(height), OnScreen: \(isOnScreen), Alpha: \(alpha)) - \(status)")
                
                // Now apply filters
                guard ownerPID != -1,
                      layer == 0 else { continue }
                
                // For now, comment out onScreen check to see all windows
                // if !isOnScreen {
                //     continue
                // }
                
                if alpha <= 0 {
                    continue
                }
                
                if width <= 0 || height <= 0 {
                    continue
                }
                
                if width < 50 && height < 50 {
                    continue
                }
                
                if windowsByPID[ownerPID] == nil {
                    windowsByPID[ownerPID] = []
                }
                windowsByPID[ownerPID]?.append((dict: windowDict, index: index))
            }
            
            // Process each app's windows
            for (pid, cgWindows) in windowsByPID {
                guard let app = NSRunningApplication(processIdentifier: pid),
                      let appName = app.localizedName else { continue }
                
                // Skip certain system processes
                if app.bundleIdentifier == "com.apple.loginwindow" ||
                   app.bundleIdentifier == "com.apple.Spotlight" ||
                   app.bundleIdentifier == "MacWinSearch" {
                    continue
                }
                
                // Try to get AX windows for this app
                let appElement = AXUIElementCreateApplication(pid)
                var windowRefs: CFTypeRef?
                let axResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowRefs)
                let axWindows = (axResult == .success ? windowRefs as? [AXUIElement] : nil) ?? []
                
                print("  App: \(appName) - CGWindows: \(cgWindows.count), AXWindows: \(axWindows.count)")
                
                // If we have AX windows, use them (they have better interaction capabilities)
                if !axWindows.isEmpty {
                    var windowIndex = 0
                    
                    // Match CGWindows with AXWindows
                    for axWindow in axWindows {
                        var minimizedRef: CFTypeRef?
                        AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minimizedRef)
                        if let minimized = minimizedRef as? Bool, minimized {
                            continue
                        }
                        
                        windowIndex += 1
                        
                        // Get window title and other attributes
                        var titleRef: CFTypeRef?
                        var documentRef: CFTypeRef?
                        var fullscreenRef: CFTypeRef?
                        
                        AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
                        AXUIElementCopyAttributeValue(axWindow, "AXDocument" as CFString, &documentRef)
                        AXUIElementCopyAttributeValue(axWindow, "AXFullScreen" as CFString, &fullscreenRef)
                        
                        let axTitle = (titleRef as? String) ?? ""
                        let axDocument = (documentRef as? String) ?? ""
                        let isFullscreen = (fullscreenRef as? Bool) ?? false
                        
                        // Build display title
                        var displayTitle: String
                        
                        // For Cursor/VSCode, parse the title
                        if appName == "Cursor" || appName.contains("Code") {
                            if axTitle.contains(" — ") {
                                let parts = axTitle.components(separatedBy: " — ")
                                if parts.count >= 2 {
                                    displayTitle = "\(parts[0]) (\(parts[1]))"
                                } else {
                                    displayTitle = axTitle
                                }
                            } else if !axTitle.isEmpty {
                                displayTitle = axTitle
                            } else if !axDocument.isEmpty {
                                displayTitle = (axDocument as NSString).lastPathComponent
                            } else {
                                // Try to get title from corresponding CGWindow
                                let cgTitle = cgWindows.first?.dict[kCGWindowName as String] as? String ?? ""
                                displayTitle = !cgTitle.isEmpty ? cgTitle : "\(appName) - Window \(windowIndex)"
                            }
                        } else {
                            displayTitle = !axTitle.isEmpty ? axTitle : "\(appName) - Window \(windowIndex)"
                        }
                        
                        let windowID = "\(pid)_\(windowIndex)_\(displayTitle)"
                        
                        if !processedWindows.contains(windowID) {
                            processedWindows.insert(windowID)
                            
                            let windowInfo = WindowInfo(
                                title: displayTitle,
                                appName: appName,
                                appIcon: app.icon,
                                windowRef: axWindow,
                                pid: pid
                            )
                            windowList.append(windowInfo)
                            print("    ✅ Added via AX: '\(displayTitle)' (fullscreen: \(isFullscreen))")
                        }
                    }
                }
                
                // Add any CGWindows that weren't found in AXWindows (e.g., windows in other spaces)
                if !cgWindows.isEmpty {
                    print("    🔍 Checking for CGWindows not in AXWindows...")
                    
                    for (index, cgWindow) in cgWindows.enumerated() {
                        let windowTitle = cgWindow.dict[kCGWindowName as String] as? String ?? ""
                        let windowNumber = cgWindow.dict[kCGWindowNumber as String] as? Int ?? 0
                        
                        // Build a more descriptive title
                        let displayTitle: String
                        if !windowTitle.isEmpty {
                            displayTitle = windowTitle
                        } else {
                            displayTitle = "\(appName) - Window \(index + 1)"
                        }
                        
                        // Use window number for unique ID to avoid duplicates
                        let windowID = "\(pid)_cg_\(windowNumber)_\(displayTitle)"
                        
                        // Check if this window was already added via AX
                        if !processedWindows.contains(windowID) {
                            processedWindows.insert(windowID)
                            
                            // Create a dummy AXUIElement for this window
                            let dummyWindow = AXUIElementCreateApplication(pid)
                            
                            let windowInfo = WindowInfo(
                                title: displayTitle,
                                appName: appName,
                                appIcon: app.icon,
                                windowRef: dummyWindow,
                                pid: pid
                            )
                            windowList.append(windowInfo)
                            print("    ⚠️ Added CGWindow #\(windowNumber): '\(displayTitle)' (not in AXWindows - likely in another space)")
                        }
                    }
                }
            }
        }
        
        print("\n📊 Total: Found \(windowList.count) windows")
        return windowList
    }
    
    func switchToWindow(_ window: WindowInfo) {
        let app = NSRunningApplication(processIdentifier: window.pid)
        app?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        
        // Try to set window attributes (might fail for CGWindow-only windows)
        AXUIElementSetAttributeValue(window.windowRef, kAXMainAttribute as CFString, true as CFTypeRef)
        AXUIElementSetAttributeValue(window.windowRef, kAXFocusedAttribute as CFString, true as CFTypeRef)
    }
}
