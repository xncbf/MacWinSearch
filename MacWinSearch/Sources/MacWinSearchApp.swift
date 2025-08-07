import SwiftUI
import AppKit

@main
struct MacWinSearchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var windowManager = WindowManager()
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var searchWindow: NSWindow!
    var windowManager: WindowManager!
    var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        windowManager = WindowManager()
        
        // Create a custom floating window for better keyboard handling
        searchWindow = CustomSearchWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        searchWindow.isMovableByWindowBackground = false
        searchWindow.level = .floating
        searchWindow.isReleasedWhenClosed = false
        searchWindow.hidesOnDeactivate = false
        searchWindow.backgroundColor = NSColor.windowBackgroundColor
        searchWindow.isOpaque = true
        searchWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        if #available(macOS 14.0, *) {
            searchWindow.contentViewController = NSHostingController(rootView: SearchView(windowManager: windowManager))
        }
        
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 48 {
                self?.toggleSearchWindow()
                return
            }
        }
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Option+Tab to toggle window
            if event.modifierFlags.contains(.option) && event.keyCode == 48 {
                self?.toggleSearchWindow()
                return nil
            }
            
            // ESC key handling when window is key
            if event.keyCode == 53 && self?.searchWindow.isKeyWindow == true {
                self?.searchWindow.orderOut(nil)
                return nil
            }
            
            return event
        }
        
        requestAccessibilityPermission()
    }
    
    @objc func toggleSearchWindow() {
        if searchWindow.isVisible {
            searchWindow.orderOut(nil)
        } else {
            // Center the window on screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowFrame = searchWindow.frame
                let x = (screenFrame.width - windowFrame.width) / 2 + screenFrame.origin.x
                let y = (screenFrame.height - windowFrame.height) / 2 + screenFrame.origin.y
                searchWindow.setFrameOrigin(NSPoint(x: x, y: y))
            }
            
            // Reset search
            windowManager.searchText = ""
            
            // Make window key and visible immediately
            NSApp.activate(ignoringOtherApps: true)
            searchWindow.makeKeyAndOrderFront(nil)
            
            // Refresh windows and focus asynchronously for speed
            DispatchQueue.main.async { [weak self] in
                self?.windowManager.refreshWindows()
                self?.windowManager.needsFocus = true
            }
        }
    }
    
    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "MacWinSearch needs accessibility permissions to read window titles and switch between windows."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Later")
            
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }
}