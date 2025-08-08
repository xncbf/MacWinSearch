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
        var processedPIDs = Set<pid_t>()
        
        // Check accessibility permissions first
        guard AXIsProcessTrusted() else {
            print("Accessibility permissions not granted")
            return []
        }
        
        // Method 1: Use CGWindowListCopyWindowInfo to get ALL windows including fullscreen ones
        let options = CGWindowListOption(arrayLiteral: [.excludeDesktopElements])
        let windowListRef = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
        
        if let windowInfoList = windowListRef as? [[String: Any]] {
            print("\n📊 CGWindowList found \(windowInfoList.count) total windows")
            
            for windowDict in windowInfoList {
                guard let ownerPID = windowDict[kCGWindowOwnerPID as String] as? Int32,
                      let layer = windowDict[kCGWindowLayer as String] as? Int,
                      layer == 0, // Normal window layer
                      let app = NSRunningApplication(processIdentifier: ownerPID),
                      let appName = app.localizedName else { continue }
                
                // Skip certain system processes
                if app.bundleIdentifier == "com.apple.loginwindow" ||
                   app.bundleIdentifier == "com.apple.Spotlight" ||
                   app.bundleIdentifier == "MacWinSearch" {
                    continue
                }
                
                let windowTitle = windowDict[kCGWindowName as String] as? String ?? ""
                let displayTitle = windowTitle.isEmpty ? appName : windowTitle
                
                // Get the AXUIElement for this window
                let appElement = AXUIElementCreateApplication(ownerPID)
                var windowRefs: CFTypeRef?
                
                if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowRefs) == .success,
                   let axWindows = windowRefs as? [AXUIElement] {
                    
                    // Try to find the matching AX window
                    for axWindow in axWindows {
                        var axTitleRef: CFTypeRef?
                        AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &axTitleRef)
                        let axTitle = (axTitleRef as? String) ?? ""
                        
                        // Match by title or use first window if title is empty
                        if axTitle == windowTitle || (windowTitle.isEmpty && axWindows.count == 1) {
                            var minimizedRef: CFTypeRef?
                            AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minimizedRef)
                            if let minimized = minimizedRef as? Bool, minimized {
                                continue
                            }
                            
                            let windowInfo = WindowInfo(
                                title: displayTitle,
                                appName: appName,
                                appIcon: app.icon,
                                windowRef: axWindow,
                                pid: ownerPID
                            )
                            windowList.append(windowInfo)
                            processedPIDs.insert(ownerPID)
                            
                            print("  ✅ Added: '\(displayTitle)' from \(appName)")
                            break
                        }
                    }
                }
            }
        }
        
        // Method 2: Fallback to traditional AX API for any apps we might have missed
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            guard let appName = app.localizedName,
                  !processedPIDs.contains(app.processIdentifier) else { continue }
            
            // Skip certain system processes
            if app.bundleIdentifier == "com.apple.loginwindow" ||
               app.bundleIdentifier == "com.apple.Spotlight" ||
               app.bundleIdentifier == "MacWinSearch" {
                continue
            }
            
            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            
            var windowRefs: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowRefs)
            
            if result == .success, let windows = windowRefs as? [AXUIElement], !windows.isEmpty {
                for window in windows {
                    var titleRef: CFTypeRef?
                    var minimizedRef: CFTypeRef?
                    
                    AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef)
                    if let minimized = minimizedRef as? Bool, minimized {
                        continue
                    }
                    
                    let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
                    let title = (titleResult == .success ? titleRef as? String : nil) ?? ""
                    let displayTitle = title.isEmpty ? appName : title
                    
                    let windowInfo = WindowInfo(
                        title: displayTitle,
                        appName: appName,
                        appIcon: app.icon,
                        windowRef: window,
                        pid: pid
                    )
                    windowList.append(windowInfo)
                    print("  ✅ Added from AX fallback: '\(displayTitle)' from \(appName)")
                }
            }
        }
        
        print("\n📊 Total: Found \(windowList.count) windows")
        return windowList
    }
    
    func switchToWindow(_ window: WindowInfo) {
        let app = NSRunningApplication(processIdentifier: window.pid)
        app?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        
        AXUIElementSetAttributeValue(window.windowRef, kAXMainAttribute as CFString, true as CFTypeRef)
        AXUIElementSetAttributeValue(window.windowRef, kAXFocusedAttribute as CFString, true as CFTypeRef)
        
        var positionRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window.windowRef, kAXPositionAttribute as CFString, &positionRef) == .success,
           let position = positionRef {
                var point = CGPoint.zero
                AXValueGetValue(position as! AXValue, .cgPoint, &point)
                
                let mouseLocation = CGPoint(x: point.x + 100, y: point.y + 20)
                let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                       mouseCursorPosition: mouseLocation, mouseButton: .left)
                moveEvent?.post(tap: .cghidEventTap)
        }
    }
}