import Cocoa

/// Custom NSWindow subclass for the search window that ensures proper keyboard input handling
/// This window can become key and accepts first responder status to reliably capture keyboard events
class CustomSearchWindow: NSWindow {
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupWindow()
    }
    
    private func setupWindow() {
        // Configure window properties for optimal keyboard handling
        self.level = .floating
        self.isOpaque = true
        self.backgroundColor = NSColor.windowBackgroundColor
        self.hasShadow = true
        self.canHide = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = false
        
        // Critical for borderless windows to receive keyboard input
        self.styleMask.insert(.nonactivatingPanel)
        self.styleMask.remove(.nonactivatingPanel)  // Add and remove to reset
    }
    
    // MARK: - Keyboard Input Handling
    
    /// Allow this window to become the key window so it can receive keyboard input
    override var canBecomeKey: Bool {
        return true
    }
    
    /// Allow this window to accept first responder status for keyboard events
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    /// Ensure the window can become main for full keyboard event handling
    override var canBecomeMain: Bool {
        return true
    }
    
    /// Override to ensure borderless windows can receive events
    override func resignKey() {
        super.resignKey()
        // Don't resign key status when clicked
    }
    
    /// Ensure window can receive keyboard events even when borderless
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown || event.type == .keyUp {
            // Make sure we're the key window for keyboard events
            if !self.isKeyWindow {
                self.makeKey()
            }
        }
        super.sendEvent(event)
    }
    
    // MARK: - Event Handling
    
    /// Handle key down events, allowing for custom keyboard shortcuts
    override func keyDown(with event: NSEvent) {
        // Check for escape key to close the window
        if event.keyCode == 53 { // Escape key
            self.orderOut(nil)
            return
        }
        
        // Pass other key events to the responder chain
        super.keyDown(with: event)
    }
    
    /// Properly handle window ordering to maintain focus
    override func orderFront(_ sender: Any?) {
        super.orderFront(sender)
        self.makeKey()
    }
    
    /// Override makeKeyAndOrderFront to ensure proper focus
    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        
        // Force window to be key
        self.makeKey()
        
        // Immediately try to focus with multiple attempts
        DispatchQueue.main.async { [weak self] in
            self?.forceFocusTextField()
        }
        
        // Retry after a short delay to ensure view is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.forceFocusTextField()
        }
    }
    
    private func forceFocusTextField() {
        // Find and focus the text field
        if let contentView = self.contentView {
            // First make content view first responder
            self.makeFirstResponder(contentView)
            
            // Then find and focus text field
            if let textField = self.findTextField(in: contentView) {
                textField.becomeFirstResponder()
                self.makeFirstResponder(textField)
                textField.selectText(nil)
            }
        }
    }
    
    /// Helper to find TextField in view hierarchy
    private func findTextField(in view: NSView) -> NSTextField? {
        if let textField = view as? NSTextField {
            return textField
        }
        for subview in view.subviews {
            if let found = findTextField(in: subview) {
                return found
            }
        }
        return nil
    }
}