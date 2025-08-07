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
        
        // Check accessibility permissions first
        guard AXIsProcessTrusted() else {
            print("Accessibility permissions not granted")
            return []
        }
        
        // Get all running applications
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            // Skip apps without a name
            guard let appName = app.localizedName else { continue }
            
            // Skip certain system processes that never have windows
            if app.bundleIdentifier == "com.apple.loginwindow" ||
               app.bundleIdentifier == "com.apple.Spotlight" {
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
                    
                    // Check if window is minimized
                    AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef)
                    if let minimized = minimizedRef as? Bool, minimized {
                        continue // Skip minimized windows
                    }
                    
                    // Get window title
                    let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
                    let title = (titleResult == .success ? titleRef as? String : nil) ?? ""
                    
                    // Use app name if title is empty
                    let displayTitle = title.isEmpty ? appName : title
                    
                    let windowInfo = WindowInfo(
                        title: displayTitle,
                        appName: appName,
                        appIcon: app.icon,
                        windowRef: window,
                        pid: pid
                    )
                    windowList.append(windowInfo)
                }
            }
        }
        
        print("Found \(windowList.count) windows from \(runningApps.count) apps")
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