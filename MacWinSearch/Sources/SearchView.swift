import SwiftUI
import AppKit

// Custom NSTextField wrapper that properly handles focus
struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var onChange: (String) -> Void
    var onArrowKey: (Bool) -> Void // true for down, false for up
    @Binding var shouldFocus: Bool
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 16)
        
        // Important: Make sure it can become first responder
        textField.refusesFirstResponder = false
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        
        if shouldFocus {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                nsView.selectText(nil)
                self.shouldFocus = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FocusableTextField
        
        init(_ parent: FocusableTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
                parent.onChange(textField.stringValue)
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onArrowKey(true)
                return true
            } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onArrowKey(false)
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // ESC key
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.searchWindow.orderOut(nil)
                }
                return true
            }
            return false
        }
    }
}

@available(macOS 14.0, *)
struct SearchView: View {
    @ObservedObject var windowManager: WindowManager
    @State private var selectedIndex = 0
    @State private var shouldFocusTextField = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                FocusableTextField(
                    text: $windowManager.searchText,
                    placeholder: "Search windows...",
                    onSubmit: {
                        if !windowManager.filteredWindows.isEmpty {
                            selectWindow(at: selectedIndex)
                        }
                    },
                    onChange: { newValue in
                        windowManager.searchWindows(query: newValue)
                        selectedIndex = 0
                    },
                    onArrowKey: { isDown in
                        if isDown {
                            if selectedIndex < windowManager.filteredWindows.count - 1 {
                                selectedIndex += 1
                            }
                        } else {
                            if selectedIndex > 0 {
                                selectedIndex -= 1
                            }
                        }
                    },
                    shouldFocus: $shouldFocusTextField
                )
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(windowManager.filteredWindows.enumerated()), id: \.element.id) { index, window in
                            WindowRow(window: window, isSelected: index == selectedIndex)
                                .id(index)
                                .onTapGesture {
                                    selectWindow(at: index)
                                }
                                .onHover { isHovered in
                                    if isHovered {
                                        selectedIndex = index
                                    }
                                }
                        }
                    }
                }
                .onChange(of: selectedIndex) { newIndex in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            .frame(maxHeight: 350)
        }
        .frame(width: 600, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            windowManager.refreshWindows()
            // Delay focus to ensure view is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                shouldFocusTextField = true
            }
        }
        .onChange(of: windowManager.needsFocus) { needsFocus in
            if needsFocus {
                shouldFocusTextField = true
                windowManager.needsFocus = false
            }
        }
        // Key handling is now done in FocusableTextField delegate
    }
    
    private func selectWindow(at index: Int) {
        guard index < windowManager.filteredWindows.count else { return }
        let window = windowManager.filteredWindows[index]
        windowManager.switchToWindow(window)
        
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.searchWindow.orderOut(nil)
        }
        
        windowManager.searchText = ""
        selectedIndex = 0
    }
}

@available(macOS 14.0, *)
struct WindowRow: View {
    let window: WindowManager.WindowInfo
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = window.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app")
                    .frame(width: 24, height: 24)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(window.title)
                    .lineLimit(1)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(window.appName)
                    .lineLimit(1)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? Color.white.opacity(0.8) : .secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(4)
    }
}