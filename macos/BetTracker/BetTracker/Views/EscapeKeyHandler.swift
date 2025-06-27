import SwiftUI
import AppKit

// View modifier to handle Escape key for closing windows
struct EscapeKeyHandler: ViewModifier {
    let onEscape: () -> Void
    
    func body(content: Content) -> some View {
        content
            .background(
                // Use a background NSView to monitor key events
                WindowKeyMonitor(onEscape: onEscape)
            )
    }
}

// NSViewRepresentable to monitor key events at the window level
struct WindowKeyMonitor: NSViewRepresentable {
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyMonitorView()
        view.onEscape = onEscape
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class KeyMonitorView: NSView {
        var onEscape: (() -> Void)?
        private var localMonitor: Any?
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            
            if window != nil {
                // Start monitoring key events for this window
                localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    if event.keyCode == 53 { // Escape key
                        self?.onEscape?()
                        return nil // Consume the event
                    }
                    return event // Let other keys pass through
                }
            } else {
                // Remove monitor when view is removed from window
                if let monitor = localMonitor {
                    NSEvent.removeMonitor(monitor)
                    localMonitor = nil
                }
            }
        }
        
        deinit {
            // Clean up monitor
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

// Convenience extension
extension View {
    func onEscapeKey(perform action: @escaping () -> Void) -> some View {
        self.modifier(EscapeKeyHandler(onEscape: action))
    }
}