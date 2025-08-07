import Cocoa

/// Custom NSPanel for search window that properly handles keyboard input
class SearchPanel: NSPanel {
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        // CRITICAL: For borderless windows, we need special handling
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupPanel()
    }
    
    private func setupPanel() {
        // Panel configuration for Spotlight-like behavior
        self.isFloatingPanel = true
        self.level = .modalPanel  // Changed from .floating to .modalPanel for better focus
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .managed, .participatesInCycle]
        
        // Visual setup
        self.isOpaque = true
        self.backgroundColor = NSColor.windowBackgroundColor
        self.hasShadow = true
        
        // Window buttons
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Make borderless but still able to receive input
        self.isMovableByWindowBackground = false
        
        // IMPORTANT: For borderless windows
        self.acceptsMouseMovedEvents = true
        self.ignoresMouseEvents = false
    }
    
    // MARK: - Key Window Handling
    
    override var canBecomeKey: Bool {
        return true // Must return true for keyboard input
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    // MARK: - Event Handling
    
    override func keyDown(with event: NSEvent) {
        // Handle ESC key
        if event.keyCode == 53 {
            self.orderOut(nil)
            return
        }
        super.keyDown(with: event)
    }
    
    // Override to properly handle borderless window events
    override func sendEvent(_ event: NSEvent) {
        // For borderless windows, we need to handle events specially
        if event.type == .keyDown || event.type == .keyUp {
            if !self.isKeyWindow {
                self.makeKey()
            }
        }
        super.sendEvent(event)
    }
    
    // MARK: - Window Ordering
    
    override func makeKeyAndOrderFront(_ sender: Any?) {
        // First make the app active with more aggressive options
        NSApp.activate(ignoringOtherApps: true)
        NSApp.unhide(nil)
        
        // Ensure we're the main window
        self.makeMain()
        
        // Then make window key
        super.makeKeyAndOrderFront(sender)
        
        // Force key window status
        self.makeKey()
        
        // Reset first responder to nil first
        self.makeFirstResponder(nil)
        
        // Schedule multiple focus attempts with increasing delays
        let delays: [Double] = [0.0, 0.05, 0.1, 0.2]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.focusSearchField()
            }
        }
    }
    
    private func focusSearchField() {
        guard self.isKeyWindow else {
            self.makeKey()
            return
        }
        
        // Try to find and focus the text field
        if let contentView = self.contentView {
            // Find the NSTextField in the view hierarchy
            if let textField = findTextField(in: contentView) {
                // Force focus
                textField.window?.makeFirstResponder(textField)
                textField.becomeFirstResponder()
                textField.selectText(nil)
                
                // Double-check that it worked
                if self.firstResponder != textField {
                    self.makeFirstResponder(textField)
                }
            }
        }
    }
    
    private func findTextField(in view: NSView) -> NSTextField? {
        // Check if this view is a text field
        if let textField = view as? NSTextField {
            return textField
        }
        
        // Recursively search subviews
        for subview in view.subviews {
            if let found = findTextField(in: subview) {
                return found
            }
        }
        
        // Special handling for NSHostingView (SwiftUI views)
        if String(describing: type(of: view)).contains("NSHostingView") {
            // SwiftUI view detected, need to dig deeper
            for subview in view.subviews {
                if let found = findTextFieldDeep(in: subview) {
                    return found
                }
            }
        }
        
        return nil
    }
    
    private func findTextFieldDeep(in view: NSView) -> NSTextField? {
        // More aggressive search for deeply nested text fields
        if let textField = view as? NSTextField {
            return textField
        }
        
        // Check all subviews recursively
        for subview in view.subviews {
            if let found = findTextFieldDeep(in: subview) {
                return found
            }
        }
        
        // Check if view has any text input related classes
        let className = String(describing: type(of: view))
        if className.contains("TextField") || className.contains("NSText") {
            if let textField = view as? NSTextField {
                return textField
            }
        }
        
        return nil
    }
    
    // Override responder chain to ensure proper keyboard handling
    override func resignKey() {
        // Don't resign key status unless we're actually hiding
        if !self.isVisible {
            super.resignKey()
        }
    }
}