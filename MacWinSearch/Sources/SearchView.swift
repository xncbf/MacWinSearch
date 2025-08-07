import SwiftUI

@available(macOS 14.0, *)
struct SearchView: View {
    @ObservedObject var windowManager: WindowManager
    @State private var selectedIndex = 0
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search windows...", text: $windowManager.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        if !windowManager.filteredWindows.isEmpty {
                            selectWindow(at: selectedIndex)
                        }
                    }
                    .onChange(of: windowManager.searchText) { newValue in
                        windowManager.searchWindows(query: newValue)
                        selectedIndex = 0
                    }
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
            isSearchFieldFocused = true
        }
        .onChange(of: windowManager.needsFocus) { needsFocus in
            if needsFocus {
                isSearchFieldFocused = true
                windowManager.needsFocus = false
            }
        }
        .background(
            Color.clear
                .onKeyPress(.downArrow) {
                    if selectedIndex < windowManager.filteredWindows.count - 1 {
                        selectedIndex += 1
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    if selectedIndex > 0 {
                        selectedIndex -= 1
                    }
                    return .handled
                }
                .onKeyPress(.escape) {
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.searchWindow.orderOut(nil)
                    }
                    return .handled
                }
                .onKeyPress(.return) {
                    if !windowManager.filteredWindows.isEmpty {
                        selectWindow(at: selectedIndex)
                    }
                    return .handled
                }
        )
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