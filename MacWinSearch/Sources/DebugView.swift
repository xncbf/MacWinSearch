import SwiftUI
import AppKit

// 디버깅용 간단한 뷰
@available(macOS 14.0, *)
struct DebugSearchView: View {
    @ObservedObject var windowManager: WindowManager
    @State private var testText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Debug Search View")
                .font(.title)
            
            // SwiftUI TextField 테스트
            TextField("SwiftUI TextField Test", text: $testText)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onAppear {
                    print("🟢 SwiftUI TextField appeared")
                    isFocused = true
                }
                .onChange(of: isFocused) { newValue in
                    print("🟢 Focus state changed: \(newValue)")
                }
            
            // NSViewRepresentable TextField 테스트
            DebugNSTextField(text: $testText)
                .frame(height: 30)
            
            Text("입력된 텍스트: \(testText)")
            
            Button("Focus Test") {
                isFocused = true
                print("🟢 Button clicked, isFocused = \(isFocused)")
            }
            
            Button("Print Window State") {
                if let window = NSApp.keyWindow {
                    printWindowState(window)
                }
            }
        }
        .padding()
        .frame(width: 600, height: 400)
        .onAppear {
            print("🟢 DebugSearchView appeared")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🟢 Delayed focus attempt")
                isFocused = true
            }
        }
    }
    
    func printWindowState(_ window: NSWindow) {
        print("\n📊 Window State:")
        print("  - isVisible: \(window.isVisible)")
        print("  - isKeyWindow: \(window.isKeyWindow)")
        print("  - isMainWindow: \(window.isMainWindow)")
        print("  - canBecomeKey: \(window.canBecomeKey)")
        print("  - canBecomeMain: \(window.canBecomeMain)")
        print("  - firstResponder: \(String(describing: window.firstResponder))")
        print("  - level: \(window.level.rawValue)")
        print("  - styleMask: \(window.styleMask.rawValue)")
        print("  - app.isActive: \(NSApp.isActive)")
    }
}

// 순수 NSTextField 테스트
struct DebugNSTextField: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = "NSTextField Test"
        textField.isEditable = true
        textField.isSelectable = true
        textField.isBordered = true
        textField.delegate = context.coordinator
        
        print("🔵 NSTextField created:")
        print("  - isEditable: \(textField.isEditable)")
        print("  - isEnabled: \(textField.isEnabled)")
        print("  - acceptsFirstResponder: \(textField.acceptsFirstResponder)")
        print("  - refusesFirstResponder: \(textField.refusesFirstResponder)")
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        
        // 강제 포커스 테스트
        if nsView.window?.isKeyWindow == true {
            print("🔵 NSTextField update - window is key, attempting focus")
            DispatchQueue.main.async {
                if let window = nsView.window {
                    let result = window.makeFirstResponder(nsView)
                    print("  - makeFirstResponder result: \(result)")
                    if !result {
                        print("  - Current first responder: \(String(describing: window.firstResponder))")
                    }
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: DebugNSTextField
        
        init(_ parent: DebugNSTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
                print("🔵 Text changed: \(textField.stringValue)")
            }
        }
        
        func controlTextDidBeginEditing(_ obj: Notification) {
            print("🔵 TextField did begin editing")
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            print("🔵 TextField did end editing")
        }
    }
}