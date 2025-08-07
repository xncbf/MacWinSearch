import Cocoa

/// Custom NSPanel for search window that properly handles keyboard input
class SearchPanel: NSPanel {
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        // Use panel-specific style mask that allows keyboard input
        var panelStyle = style
        panelStyle.remove(.nonactivatingPanel) // Critical: allow panel to become key
        
        super.init(contentRect: contentRect, styleMask: panelStyle, backing: backingStoreType, defer: flag)
        setupPanel()
    }
    
    private func setupPanel() {
        // Panel configuration for Spotlight-like behavior
        self.isFloatingPanel = true
        self.level = .floating
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Visual setup
        self.isOpaque = true
        self.backgroundColor = NSColor.windowBackgroundColor
        self.hasShadow = true
        
        // Window buttons
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Make borderless but still able to receive input
        if styleMask.contains(.borderless) {
            self.isMovableByWindowBackground = false
        }
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
    
    // MARK: - Window Ordering
    
    override func makeKeyAndOrderFront(_ sender: Any?) {
        // First make the app active
        NSApp.activate(ignoringOtherApps: true)
        
        // Then make window key
        super.makeKeyAndOrderFront(sender)
        
        // Force key window status
        self.makeKey()
        
        // Schedule focus attempt
        DispatchQueue.main.async { [weak self] in
            self?.focusSearchField()
        }
    }
    
    private func focusSearchField() {
        // Try to find and focus the text field
        if let contentView = self.contentView {
            // Make content view first responder first
            self.makeFirstResponder(contentView)
            
            // Then find TextField
            if let textField = findTextField(in: contentView) {
                self.makeFirstResponder(textField)
                textField.selectText(nil)
            }
        }
    }
    
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