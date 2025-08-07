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
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = true
        self.canHide = false
        self.isReleasedWhenClosed = false
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
        
        // Immediately try to focus
        DispatchQueue.main.async { [weak self] in
            // Find and focus the text field
            if let contentView = self?.contentView {
                self?.makeFirstResponder(contentView)
                
                // Try to find the TextField and make it first responder
                if let textField = self?.findTextField(in: contentView) {
                    self?.makeFirstResponder(textField)
                }
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