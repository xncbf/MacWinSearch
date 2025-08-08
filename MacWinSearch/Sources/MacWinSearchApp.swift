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

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var searchWindow: NSWindow!
    var windowManager: WindowManager!
    var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        windowManager = WindowManager()
        
        // Test with debug mode first
        let useDebugView = false  // Toggle this to switch between debug and production view
        
        if useDebugView {
            // Simple window for debugging
            searchWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            searchWindow.title = "Debug Search Window"
            searchWindow.level = .floating
            searchWindow.isReleasedWhenClosed = false
            searchWindow.delegate = self
            
            if #available(macOS 14.0, *) {
                searchWindow.contentViewController = NSHostingController(rootView: DebugSearchView(windowManager: windowManager))
            }
        } else {
            // Production panel with borderless style
            searchWindow = SearchPanel(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            searchWindow.delegate = self
            
            if #available(macOS 14.0, *) {
                searchWindow.contentViewController = NSHostingController(rootView: SearchView(windowManager: windowManager))
            }
        }
        
        print("🚀 Application launched with \(useDebugView ? "DEBUG" : "PRODUCTION") view")
        
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            print("🔴 Global Key: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags.rawValue)")
            if event.modifierFlags.contains(.option) && event.keyCode == 48 {
                print("🔴 Global: Option+Tab detected")
                self?.toggleSearchWindow()
                return
            }
        }
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            print("🔵 Local Key: keyCode=\(event.keyCode), window=\(String(describing: event.window))")
            
            // Option+Tab to toggle window
            if event.modifierFlags.contains(.option) && event.keyCode == 48 {
                print("🔵 Local: Option+Tab detected")
                self?.toggleSearchWindow()
                return nil
            }
            
            // ESC key handling when window is key
            if event.keyCode == 53 && self?.searchWindow.isKeyWindow == true {
                print("🔵 ESC pressed, closing window")
                self?.searchWindow.orderOut(nil)
                return nil
            }
            
            return event
        }
        
        requestAccessibilityPermission()
    }
    
    @objc func toggleSearchWindow() {
        print("\n========== TOGGLE WINDOW ==========")
        printWindowState()
        
        if searchWindow.isVisible {
            print("Window is visible, hiding it")
            searchWindow.orderOut(nil)
            // Return to accessory mode when hiding
            NSApp.setActivationPolicy(.accessory)
        } else {
            print("Window is hidden, showing it")
            
            // Reset search
            windowManager.searchText = ""
            
            // CRITICAL: The order of operations matters for borderless windows
            
            print("\n🟡 Before showing window:")
            printWindowState()
            
            // 1. First position the window on current screen BEFORE any activation
            // Center the window on the screen where the mouse cursor is
            let mouseLocation = NSEvent.mouseLocation
            if let currentScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
                print("  - Positioning on screen: \(currentScreen.localizedName)")
                let screenFrame = currentScreen.visibleFrame
                let windowFrame = searchWindow.frame
                let x = (screenFrame.width - windowFrame.width) / 2 + screenFrame.origin.x
                let y = (screenFrame.height - windowFrame.height) / 2 + screenFrame.origin.y
                searchWindow.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                // Fallback to main screen if can't detect current screen
                if let screen = NSScreen.main {
                    let screenFrame = screen.visibleFrame
                    let windowFrame = searchWindow.frame
                    let x = (screenFrame.width - windowFrame.width) / 2 + screenFrame.origin.x
                    let y = (screenFrame.height - windowFrame.height) / 2 + screenFrame.origin.y
                    searchWindow.setFrameOrigin(NSPoint(x: x, y: y))
                }
            }
            
            // 2. Temporarily move window to current space for fullscreen apps
            searchWindow.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            
            // 3. Show the window 
            searchWindow.orderFrontRegardless()  // Use orderFrontRegardless for borderless
            print("  - Window ordered front")
            
            // 4. Activate app without changing policy initially
            NSApp.activate(ignoringOtherApps: true)
            NSApp.unhide(nil)
            print("  - App activated")
            
            // 5. Make it key and main
            searchWindow.makeMain()
            searchWindow.makeKey()
            print("  - Window made key and main")
            
            // 6. Force window to front again
            searchWindow.level = .modalPanel
            searchWindow.makeKeyAndOrderFront(nil)
            print("  - Window level set to modalPanel")
            
            // 7. Reset first responder
            searchWindow.makeFirstResponder(nil)
            print("  - First responder reset")
            
            print("\n🟢 After showing window:")
            printWindowState()
            
            // 8. Refresh windows and trigger focus with multiple attempts
            DispatchQueue.main.async { [weak self] in
                self?.windowManager.refreshWindows()
                self?.windowManager.needsFocus = true
                
                // Try to focus immediately
                print("\n🔷 First focus attempt:")
                self?.forceTextFieldFocus()
                
                // Activate as regular app AFTER window is positioned and shown
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    // Restore collection behavior for all spaces
                    self?.searchWindow.collectionBehavior = [
                        .canJoinAllSpaces,
                        .transient,
                        .ignoresCycle,
                        .fullScreenAuxiliary
                    ]
                    
                    NSApp.setActivationPolicy(.regular)
                    print("  - Changed to regular app policy (delayed)")
                    
                    // Try focus again after policy change
                    print("\n🔷 Second focus attempt (0.05s):")
                    self?.forceTextFieldFocus()
                }
                
                // Try again after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("\n🔷 Third focus attempt (0.1s):")
                    self?.forceTextFieldFocus()
                }
                
                // One more attempt
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    print("\n🔷 Fourth focus attempt (0.2s):")
                    self?.forceTextFieldFocus()
                }
            }
        }
    }
    
    private func forceTextFieldFocus() {
        guard let window = searchWindow else {
            print("❌ No search window")
            return
        }
        
        // Make sure window is key
        if !window.isKeyWindow {
            print("  - Window not key, making it key...")
            NSApp.activate(ignoringOtherApps: true)
            window.makeKey()
        }
        
        // Try to find and focus text field
        if let contentView = window.contentView {
            print("  - Content view: \(type(of: contentView))")
            print("  - View hierarchy:")
            printViewHierarchy(contentView, indent: 2)
            findAndFocusTextField(in: contentView)
        } else {
            print("❌ No content view")
        }
    }
    
    private func findAndFocusTextField(in view: NSView) {
        if let textField = view as? NSTextField {
            print("✅ Found TextField: \(textField)")
            print("  - acceptsFirstResponder: \(textField.acceptsFirstResponder)")
            print("  - isEditable: \(textField.isEditable)")
            print("  - isEnabled: \(textField.isEnabled)")
            
            let result = searchWindow.makeFirstResponder(textField)
            print("  - makeFirstResponder result: \(result)")
            
            if !result {
                print("  ❌ Failed to make first responder")
                print("  - Current first responder: \(String(describing: searchWindow.firstResponder))")
                // Try alternative methods
                textField.becomeFirstResponder()
                textField.selectText(nil)
            } else {
                print("  ✅ Successfully made first responder")
            }
            return
        }
        
        for subview in view.subviews {
            findAndFocusTextField(in: subview)
        }
    }
    
    private func printViewHierarchy(_ view: NSView, indent: Int) {
        let prefix = String(repeating: "  ", count: indent)
        print("\(prefix)- \(type(of: view)): frame=\(view.frame)")
        
        if let textField = view as? NSTextField {
            print("\(prefix)  📝 TextField found!")
            print("\(prefix)     - isEditable: \(textField.isEditable)")
            print("\(prefix)     - isEnabled: \(textField.isEnabled)")
            print("\(prefix)     - acceptsFirstResponder: \(textField.acceptsFirstResponder)")
        }
        
        for subview in view.subviews {
            printViewHierarchy(subview, indent: indent + 1)
        }
    }
    
    private func printWindowState() {
        print("Window State:")
        print("  - isVisible: \(searchWindow.isVisible)")
        print("  - isKeyWindow: \(searchWindow.isKeyWindow)")
        print("  - isMainWindow: \(searchWindow.isMainWindow)")
        print("  - canBecomeKey: \(searchWindow.canBecomeKey)")
        print("  - canBecomeMain: \(searchWindow.canBecomeMain)")
        print("  - firstResponder: \(String(describing: searchWindow.firstResponder))")
        print("  - level: \(searchWindow.level.rawValue)")
        print("  - styleMask: \(searchWindow.styleMask.rawValue)")
        print("  - app.isActive: \(NSApp.isActive)")
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidBecomeKey(_ notification: Notification) {
        print("\n📗 Window DID become key")
        printWindowState()
    }
    
    func windowDidResignKey(_ notification: Notification) {
        print("\n📕 Window DID resign key")
    }
    
    func windowDidBecomeMain(_ notification: Notification) {
        print("\n📘 Window DID become main")
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