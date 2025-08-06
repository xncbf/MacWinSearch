import Foundation
import AppKit
import ApplicationServices

class WindowManager: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var filteredWindows: [WindowInfo] = []
    
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
        
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }
        
        for app in runningApps {
            guard let appName = app.localizedName else { continue }
            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            
            var windowRefs: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowRefs)
            
            if result == .success, let windows = windowRefs as? [AXUIElement] {
                for window in windows {
                    var titleRef: CFTypeRef?
                    let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
                    
                    if titleResult == .success, let title = titleRef as? String, !title.isEmpty {
                        let windowInfo = WindowInfo(
                            title: title,
                            appName: appName,
                            appIcon: app.icon,
                            windowRef: window,
                            pid: pid
                        )
                        windowList.append(windowInfo)
                    }
                }
            }
        }
        
        return windowList
    }
    
    func switchToWindow(_ window: WindowInfo) {
        let app = NSRunningApplication(processIdentifier: window.pid)
        app?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        
        AXUIElementSetAttributeValue(window.windowRef, kAXMainAttribute as CFString, true as CFTypeRef)
        AXUIElementSetAttributeValue(window.windowRef, kAXFocusedAttribute as CFString, true as CFTypeRef)
        
        var positionRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window.windowRef, kAXPositionAttribute as CFString, &positionRef) == .success {
            if let position = positionRef as? AXValue {
                var point = CGPoint.zero
                AXValueGetValue(position, .cgPoint, &point)
                
                let mouseLocation = CGPoint(x: point.x + 100, y: point.y + 20)
                let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                       mouseCursorPosition: mouseLocation, mouseButton: .left)
                moveEvent?.post(tap: .cghidEventTap)
            }
        }
    }
}