import SwiftUI
import UniformTypeIdentifiers

// Notification names for keyboard shortcuts
extension Notification.Name {
    static let takeScreenshot = Notification.Name("takeScreenshot")
    static let loadScreenshot = Notification.Name("loadScreenshot")
    static let manualEntry = Notification.Name("manualEntry")
    static let openSettings = Notification.Name("openSettings")
    static let recordPayment = Notification.Name("recordPayment")
}

// Keyboard shortcut definitions
struct AppShortcut {
    let key: String
    let modifiers: [EventModifiers]
    let displayString: String
    let description: String
    
    static let takeScreenshot = AppShortcut(
        key: "4",
        modifiers: [.option, .shift],
        displayString: "⌥⇧4",
        description: "Take Screenshot"
    )
    
    static let manualEntry = AppShortcut(
        key: "n",
        modifiers: [.option, .shift],
        displayString: "⌥⇧N",
        description: "Manual Entry"
    )
    
    static let loadScreenshot = AppShortcut(
        key: "l",
        modifiers: [.option, .shift],
        displayString: "⌥⇧L",
        description: "Load Screenshot"
    )
    
    static let recordPayment = AppShortcut(
        key: "p",
        modifiers: [.option, .shift],
        displayString: "⌥⇧P",
        description: "Record Payment"
    )
    
    static let settings = AppShortcut(
        key: ",",
        modifiers: [.command],
        displayString: "⌘,",
        description: "Settings"
    )
    
    static let quit = AppShortcut(
        key: "q",
        modifiers: [.command],
        displayString: "⌘Q",
        description: "Quit"
    )
    
    static let allShortcuts = [takeScreenshot, manualEntry, loadScreenshot, recordPayment, settings, quit]
}

@main
struct BetTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("🎲", systemImage: "dice") {
            ContentView()
                .environmentObject(appDelegate)
        }
        .menuBarExtraStyle(.window)
        .commands {
            // Replace the default app info menu
            CommandGroup(replacing: .appInfo) {
                Button("About BetTracker") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            
            // Add custom Bet menu with keyboard shortcuts
            CommandMenu("Bet") {
                Button("Take Screenshot") {
                    NotificationCenter.default.post(name: .takeScreenshot, object: nil)
                }
                .keyboardShortcut(KeyEquivalent(Character(AppShortcut.takeScreenshot.key)), modifiers: [.option, .shift])
                
                Button("Manual Entry") {
                    NotificationCenter.default.post(name: .manualEntry, object: nil)
                }
                .keyboardShortcut(KeyEquivalent(Character(AppShortcut.manualEntry.key)), modifiers: [.option, .shift])
                
                Button("Load Screenshot...") {
                    NotificationCenter.default.post(name: .loadScreenshot, object: nil)
                }
                .keyboardShortcut(KeyEquivalent(Character(AppShortcut.loadScreenshot.key)), modifiers: [.option, .shift])
                
                Divider()
                
                Button("Record Payment") {
                    NotificationCenter.default.post(name: .recordPayment, object: nil)
                }
                .keyboardShortcut(KeyEquivalent(Character(AppShortcut.recordPayment.key)), modifiers: [.option, .shift])
                
                Divider()
                
                Button("Settings...") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(KeyEquivalent(Character(AppShortcut.settings.key)), modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var windowControllers: Set<NSWindowController> = []
    var parsingWindowController: NSWindowController?
    private var eventMonitor: Any?
    private var globalEventMonitor: Any?
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Set up notification observers for keyboard shortcuts
        setupNotificationObservers()
        
        // Register local event monitor for keyboard shortcuts
        setupKeyboardShortcuts()
        
        // Check and request accessibility permissions for global shortcuts
        checkAccessibilityPermissions()
        
        // Check authentication status on launch
        if !AuthenticationManager.shared.isAuthenticated {
            // Show authentication window after a slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showAuthenticationWindow()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up event monitors
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTakeScreenshot),
            name: .takeScreenshot,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLoadScreenshot),
            name: .loadScreenshot,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleManualEntry),
            name: .manualEntry,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: .openSettings,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecordPayment),
            name: .recordPayment,
            object: nil
        )
    }
    
    @objc private func handleTakeScreenshot() {
        Task { @MainActor in
            let screenshotManager = ScreenshotManager()
            if let path = await screenshotManager.captureScreenshot() {
                showBetDetailsWindow(for: path)
            }
        }
    }
    
    @MainActor
    @objc private func handleLoadScreenshot() {
        let screenshotManager = ScreenshotManager()
        if let path = screenshotManager.loadScreenshot() {
            showBetDetailsWindow(for: path)
        }
    }
    
    @objc private func handleManualEntry() {
        showManualEntryWindow()
    }
    
    @objc private func handleOpenSettings() {
        showSettingsWindow()
    }
    
    @objc private func handleRecordPayment() {
        showPaymentEntryWindow()
    }
    
    private func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            print("BetTracker: Accessibility permissions not granted. Global shortcuts will not work.")
        } else {
            print("BetTracker: Accessibility permissions granted. Global shortcuts enabled.")
        }
    }
    
    private func setupWindow(_ window: NSWindow, withController controller: NSWindowController) {
        windowControllers.insert(controller)
        controller.showWindow(nil)
        
        // Don't use floating level - it interferes with keyboard handling
        // window.level = .floating
        
        // Ensure app is active and window is key
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        
        // Make the content view first responder
        if let contentView = window.contentView {
            window.makeFirstResponder(contentView)
        }
        
        // Add observer for window close to prevent memory leak
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak controller] _ in
            if let strongController = controller {
                self?.windowControllers.remove(strongController)
            }
        }
    }
    
    private func isWindowOpen(withTitle title: String) -> NSWindow? {
        for controller in windowControllers {
            if let window = controller.window, window.title == title {
                return window
            }
        }
        return nil
    }
    
    private func setupKeyboardShortcuts() {
        print("Setting up keyboard shortcuts...")
        
        // Local event monitor for when the app is active
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Only process shortcuts when no modal windows are open
            if NSApp.modalWindow != nil {
                return event
            }
            
            // Debug: Log all key events when app is active
            print("Local key event: keyCode=\(event.keyCode), key=\(event.charactersIgnoringModifiers ?? "nil"), flags=\(event.modifierFlags)")
            
            // Check for Escape key (keyCode 53)
            if event.keyCode == 53 {
                print("Escape key pressed in local monitor")
                // Let SwiftUI handle the Escape key
                return event
            }
            
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // Option+Shift shortcuts
            if flags == [.option, .shift] {
                switch event.charactersIgnoringModifiers {
                case "$", "4":  // $ is what we get when Shift+4 is pressed
                    DispatchQueue.main.async { [weak self] in
                        self?.handleTakeScreenshot()
                    }
                    return nil
                case "N", "n":  // N is what we get when Shift+n is pressed
                    DispatchQueue.main.async { [weak self] in
                        self?.handleManualEntry()
                    }
                    return nil
                case "L", "l":  // L is what we get when Shift+l is pressed
                    DispatchQueue.main.async { [weak self] in
                        self?.handleLoadScreenshot()
                    }
                    return nil
                case "P", "p":  // P is what we get when Shift+p is pressed
                    DispatchQueue.main.async { [weak self] in
                        self?.handleRecordPayment()
                    }
                    return nil
                default:
                    break
                }
            }
            
            // Command only shortcuts
            if flags == .command {
                switch event.charactersIgnoringModifiers {
                case ",":
                    DispatchQueue.main.async { [weak self] in
                        self?.handleOpenSettings()
                    }
                    return nil
                case "q":
                    NSApp.terminate(nil)
                    return nil
                default:
                    break
                }
            }
            
            return event
        }
        
        // Global event monitor for system-wide shortcuts
        print("Setting up global event monitor...")
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // Debug logging
            print("Global key event: key=\(event.charactersIgnoringModifiers ?? "nil"), flags=\(flags)")
            
            // Only handle Option+Shift shortcuts globally
            if flags == [.option, .shift] {
                print("Option+Shift detected with key: \(event.charactersIgnoringModifiers ?? "nil")")
                DispatchQueue.main.async { [weak self] in
                    switch event.charactersIgnoringModifiers {
                    case "$", "4":  // $ is what we get when Shift+4 is pressed
                        print("Triggering screenshot from global shortcut")
                        self?.handleTakeScreenshot()
                    case "N", "n":  // N is what we get when Shift+n is pressed
                        print("Triggering manual entry from global shortcut")
                        self?.handleManualEntry()
                    case "L", "l":  // L is what we get when Shift+l is pressed
                        print("Triggering load screenshot from global shortcut")
                        self?.handleLoadScreenshot()
                    case "P", "p":  // P is what we get when Shift+p is pressed
                        print("Triggering record payment from global shortcut")
                        self?.handleRecordPayment()
                    default:
                        break
                    }
                }
            }
        }
        
        if globalEventMonitor != nil {
            print("Global event monitor successfully created")
        } else {
            print("Failed to create global event monitor")
        }
    }
    
    func showAuthenticationWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Sign In"
        window.center()
        window.isReleasedWhenClosed = false
        
        let windowController = NSWindowController(window: window)
        
        let hostingView = NSHostingView(
            rootView: AuthenticationView(
                onAuthenticated: { [weak windowController] token in
                    windowController?.close()
                },
                onDismiss: { [weak windowController] in
                    windowController?.close()
                }
            )
        )
        
        window.contentView = hostingView
        windowController.showWindow(nil)
        
        // Make sure window appears on top
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Add to window controllers and setup cleanup
        windowControllers.insert(windowController)
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak windowController] _ in
            if let controller = windowController {
                self?.windowControllers.remove(controller)
            }
        }
    }
    
    func showSettingsWindow() {
        // Check if settings window is already open
        if let existingWindow = isWindowOpen(withTitle: "BetTracker Settings") {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "BetTracker Settings"
        window.center()
        window.isReleasedWhenClosed = false
        
        let windowController = NSWindowController(window: window)
        
        let hostingView = NSHostingView(
            rootView: SettingsView()
        )
        
        window.contentView = hostingView
        
        setupWindow(window, withController: windowController)
    }
    
    func showManualEntryWindow() {
        // Check if manual entry window is already open
        if let existingWindow = isWindowOpen(withTitle: "Manual Bet Entry") {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Manual Bet Entry"
        window.center()
        window.isReleasedWhenClosed = false
        
        let windowController = NSWindowController(window: window)
        
        let hostingView = NSHostingView(
            rootView: ManualBetEntryView(
                onSubmit: { [weak self, weak windowController] participantsText, betData in
                    if let controller = windowController {
                        controller.close()
                    }
                    // Process manual bet entry
                    self?.processManualBetEntry(participantsText: participantsText, betData: betData)
                },
                onCancel: { [weak windowController] in
                    windowController?.close()
                }
            )
        )
        
        window.contentView = hostingView
        
        setupWindow(window, withController: windowController)
    }
    
    func showPaymentEntryWindow() {
        // Check if payment entry window is already open
        if let existingWindow = isWindowOpen(withTitle: "Record Payment") {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Record Payment"
        window.center()
        window.isReleasedWhenClosed = false
        
        let windowController = NSWindowController(window: window)
        
        let hostingView = NSHostingView(
            rootView: PaymentEntryView(
                onSubmit: { [weak self, weak windowController] fromPerson, toPerson, amount, method, note in
                    if let controller = windowController {
                        controller.close()
                    }
                    // Process payment recording
                    self?.processPaymentRecording(
                        from: fromPerson,
                        to: toPerson,
                        amount: amount,
                        method: method,
                        note: note
                    )
                },
                onCancel: { [weak windowController] in
                    windowController?.close()
                }
            )
        )
        
        window.contentView = hostingView
        
        setupWindow(window, withController: windowController)
    }
    
    func showBetDetailsWindow(for screenshotPath: String) {
        // Parse screenshot first to determine flow
        showParsingWindow()
        
        Task {
            do {
                let (betData, base64Screenshot) = try await parseScreenshotFirst(screenshotPath: screenshotPath)
                
                await MainActor.run { [weak self] in
                    self?.closeParsingWindow()
                }
                
                // Route based on bet status
                if betData.status.lowercased() != "pending" {
                    // This is a settled bet - handle settlement flow
                    await handleSettledBetFlow(
                        screenshotPath: screenshotPath,
                        betData: betData,
                        base64Screenshot: base64Screenshot
                    )
                } else {
                    // This is a pending bet - normal flow
                    await MainActor.run { [weak self] in
                        self?.showBetDetailsInputWindow(
                            screenshotPath: screenshotPath,
                            parsedBetData: betData,
                            base64Screenshot: base64Screenshot
                        )
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.closeParsingWindow()
                    self?.showError("Failed to parse screenshot: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func parseScreenshotFirst(screenshotPath: String) async throws -> (BetData, String) {
        // Convert screenshot to base64
        guard let imageData = NSImage(contentsOfFile: screenshotPath)?.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw SupabaseError.apiError("Failed to process screenshot")
        }
        
        let base64String = pngData.base64EncodedString()
        
        // Parse bet data from screenshot using vision API
        let betData = try await SupabaseClient.shared.parseBetScreenshot(base64String)
        
        return (betData, base64String)
    }
    
    private func handleSettledBetFlow(screenshotPath: String, betData: BetData, base64Screenshot: String) async {
        do {
            // Find matching pending bets
            let matches = try await SupabaseClient.shared.findMatchingBets(
                betData: betData,
                ticketNumber: betData.ticket_number
            )
            
            if matches.count == 1 && matches[0].confidence == 100 {
                // Auto-settle the bet
                await autoSettleBet(
                    betId: matches[0].id,
                    screenshot: base64Screenshot,
                    betData: betData
                )
            } else if matches.isEmpty {
                // No match found - ask for participants to create new settled bet
                await MainActor.run { [weak self] in
                    self?.showBetDetailsInputWindow(
                        screenshotPath: screenshotPath,
                        parsedBetData: betData,
                        base64Screenshot: base64Screenshot
                    )
                }
            } else {
                // Multiple matches or partial match - show selection UI
                await MainActor.run { [weak self] in
                    self?.showSettlementMatchingWindow(
                        screenshotPath: screenshotPath,
                        parsedBetData: betData,
                        matches: matches,
                        base64Screenshot: base64Screenshot,
                        participantsText: "" // Not needed for settlement matching
                    )
                }
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.showError("Failed to find matching bets: \(error.localizedDescription)")
            }
        }
    }
    
    private func autoSettleBet(betId: String, screenshot: String, betData: BetData) async {
        do {
            // Show progress
            await MainActor.run { [weak self] in
                self?.showParsingWindow(message: "Settling bet...")
            }
            
            let settlement = try await SupabaseClient.shared.settleBetWithScreenshot(
                betId: betId,
                screenshot: screenshot
            )
            
            await MainActor.run { [weak self] in
                self?.closeParsingWindow()
                self?.showSuccess("Bet #\(settlement.ticketNumber) has been settled as \(settlement.status.capitalized)")
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.closeParsingWindow()
                self?.showError("Failed to settle bet: \(error.localizedDescription)")
            }
        }
    }
    
    private func showBetDetailsInputWindow(screenshotPath: String, parsedBetData: BetData? = nil, base64Screenshot: String? = nil) {
        // Check if bet details window is already open
        if let existingWindow = isWindowOpen(withTitle: "Bet Details") {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Bet Details"
        window.center()
        window.isReleasedWhenClosed = false
        
        let windowController = NSWindowController(window: window)
        
        let hostingView = NSHostingView(
            rootView: BetDetailsInputView(
                screenshotPath: screenshotPath,
                parsedBetData: parsedBetData,
                onContinue: { [weak self, weak windowController] participantsText in
                    if let controller = windowController {
                        controller.close()
                    }
                    // If we already have parsed data, use it
                    if let betData = parsedBetData, let base64 = base64Screenshot {
                        self?.processWithParsedData(
                            screenshotPath: screenshotPath,
                            participantsText: participantsText,
                            betData: betData,
                            base64Screenshot: base64
                        )
                    } else {
                        // Otherwise, parse as before
                        self?.processScreenshotAndShowApproval(
                            screenshotPath: screenshotPath,
                            participantsText: participantsText
                        )
                    }
                },
                onCancel: { [weak windowController] in
                    windowController?.close()
                }
            )
        )
        
        window.contentView = hostingView
        
        setupWindow(window, withController: windowController)
    }
    
    private func showParsingWindow(message: String = "Parsing bet screenshot...") {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Processing Bet"
        window.center()
        window.isReleasedWhenClosed = false
        
        parsingWindowController = NSWindowController(window: window)
        
        let hostingView = NSHostingView(rootView: ParsingView(message: message))
        window.contentView = hostingView
        
        parsingWindowController?.showWindow(nil)
        window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func closeParsingWindow() {
        parsingWindowController?.close()
        parsingWindowController = nil
    }
    
    private func processWithParsedData(screenshotPath: String, participantsText: String, betData: BetData, base64Screenshot: String) {
        // Parse participants
        let parseResult = ParticipantParser.parse(participantsText, totalRisk: betData.risk)
        
        if !parseResult.errors.isEmpty {
            showError("Failed to parse participants: \(parseResult.errors.joined(separator: ", "))")
            return
        }
        
        if parseResult.participants.isEmpty {
            showError("No participants found")
            return
        }
        
        // Show approval window
        showApprovalWindow(
            screenshotPath: screenshotPath,
            betData: betData,
            participants: parseResult.participants,
            participantsText: participantsText,
            base64Screenshot: base64Screenshot
        )
    }
    
    private func processScreenshotAndShowApproval(screenshotPath: String, participantsText: String) {
        // Show loading window while parsing
        showParsingWindow()
        
        Task {
            do {
                // Convert screenshot to base64
                guard let imageData = NSImage(contentsOfFile: screenshotPath)?.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: imageData),
                      let pngData = bitmap.representation(using: .png, properties: [:]) else {
                    throw SupabaseError.apiError("Failed to process screenshot")
                }
                
                let base64String = pngData.base64EncodedString()
                
                // Parse bet data from screenshot using vision API
                let betData = try await SupabaseClient.shared.parseBetScreenshot(base64String)
                
                // Check if this is a settled bet
                if betData.status != "pending" {
                    // This is a settled bet - find matching pending bets
                    let matches = try await SupabaseClient.shared.findMatchingBets(
                        betData: betData,
                        ticketNumber: betData.ticket_number
                    )
                    
                    // Close parsing window
                    await MainActor.run { [weak self] in
                        self?.closeParsingWindow()
                    }
                    
                    // Show settlement matching view
                    await MainActor.run { [weak self] in
                        self?.showSettlementMatchingWindow(
                            screenshotPath: screenshotPath,
                            parsedBetData: betData,
                            matches: matches,
                            base64Screenshot: base64String,
                            participantsText: participantsText
                        )
                    }
                    return
                }
                
                // Parse participants based on actual risk from vision API
                let parseResult = ParticipantParser.parse(participantsText, totalRisk: betData.risk)
                
                // Close parsing window
                await MainActor.run { [weak self] in
                    self?.closeParsingWindow()
                }
                
                // Check approval settings
                let alwaysRequireApproval = UserDefaults.standard.bool(forKey: "alwaysRequireApproval")
                let autoApproveHighConfidence = UserDefaults.standard.bool(forKey: "autoApproveHighConfidence")
                
                // For now, always show approval window (future: add confidence logic)
                let shouldShowApproval = alwaysRequireApproval || !autoApproveHighConfidence
                
                await MainActor.run { [weak self] in
                    if shouldShowApproval {
                        self?.showApprovalWindow(
                            screenshotPath: screenshotPath,
                            betData: betData,
                            participants: parseResult.participants,
                            participantsText: participantsText,
                            base64Screenshot: base64String
                        )
                    } else {
                        // Auto-approve high confidence bets
                        self?.submitBet(
                            betData: betData,
                            participants: parseResult.participants,
                            participantsText: participantsText,
                            base64Screenshot: base64String
                        )
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.closeParsingWindow()
                    print("Error processing screenshot: \(error)")
                    self?.showError("Failed to process screenshot: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showApprovalWindow(screenshotPath: String, 
                                   betData: BetData, 
                                   participants: [ParsedParticipant],
                                   participantsText: String,
                                   base64Screenshot: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Approve Bet Details"
        window.center()
        window.isReleasedWhenClosed = false
        
        let windowController = NSWindowController(window: window)
        
        let hostingView = NSHostingView(
            rootView: BetApprovalView(
                screenshotPath: screenshotPath,
                betData: betData,
                participants: participants,
                onApprove: { [weak self, weak windowController] updatedBetData, updatedParticipants in
                    windowController?.close()
                    // Submit bet to Supabase
                    self?.submitBet(
                        betData: updatedBetData,
                        participants: updatedParticipants,
                        participantsText: participantsText,
                        base64Screenshot: base64Screenshot
                    )
                },
                onReject: { [weak windowController] in
                    windowController?.close()
                }
            )
        )
        
        window.contentView = hostingView
        windowController.showWindow(nil)
        window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        
        // Use setupWindow for consistent window management
        setupWindow(window, withController: windowController)
    }
    
    private func submitBet(betData: BetData, 
                          participants: [ParsedParticipant], 
                          participantsText: String,
                          base64Screenshot: String) {
        Task {
            do {
                // Format participants text for API
                let formattedParticipants = participants
                    .map { "\($0.name): \(String(format: "%.2f", $0.stake))" }
                    .joined(separator: ", ")
                
                let response = try await SupabaseClient.shared.addBet(
                    screenshot: base64Screenshot,
                    participantsText: formattedParticipants,
                    whoPaid: nil,
                    betData: betData
                )
                
                if response.success {
                    await MainActor.run { [weak self] in
                        self?.showSuccess("Bet added successfully!")
                    }
                } else {
                    throw SupabaseError.apiError(response.error ?? "Unknown error")
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showSuccess(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Success"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func processManualBetEntry(participantsText: String, betData: BetData) {
        // Parse participants
        let parseResult = ParticipantParser.parse(participantsText, totalRisk: betData.risk)
        
        if !parseResult.errors.isEmpty {
            showError("Failed to parse participants: \(parseResult.errors.joined(separator: ", "))")
        } else if parseResult.participants.isEmpty {
            showError("No participants found")
        } else {
            // Show approval window
            showApprovalWindow(
                screenshotPath: "", // Empty for manual entry
                betData: betData,
                participants: parseResult.participants,
                participantsText: participantsText,
                base64Screenshot: "" // Empty for manual entry
            )
        }
    }
    
    private func showSettlementMatchingWindow(screenshotPath: String,
                                             parsedBetData: BetData,
                                             matches: [BetMatch],
                                             base64Screenshot: String,
                                             participantsText: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Settlement Matching"
        window.center()
        window.isReleasedWhenClosed = false
        
        let windowController = NSWindowController(window: window)
        
        let hostingView = NSHostingView(
            rootView: SettlementMatchingView(
                screenshotPath: screenshotPath,
                parsedBetData: parsedBetData,
                matches: matches,
                base64Screenshot: base64Screenshot,
                onSelectMatch: { [weak self, weak windowController] betId in
                    windowController?.close()
                    // Settle the selected bet with screenshot
                    self?.settleWithScreenshot(betId: betId, screenshot: base64Screenshot)
                },
                onCreateNew: { [weak self, weak windowController] in
                    windowController?.close()
                    // Create new settled bet with the participants that were entered
                    self?.createSettledBet(
                        betData: parsedBetData,
                        base64Screenshot: base64Screenshot,
                        participantsText: participantsText
                    )
                },
                onCancel: { [weak windowController] in
                    windowController?.close()
                }
            )
        )
        
        window.contentView = hostingView
        windowController.showWindow(nil)
        window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        
        // Use setupWindow for consistent window management
        setupWindow(window, withController: windowController)
    }
    
    private func settleWithScreenshot(betId: String, screenshot: String) {
        Task {
            do {
                let summary = try await SupabaseClient.shared.settleBetWithScreenshot(
                    betId: betId,
                    screenshot: screenshot
                )
                
                await MainActor.run { [weak self] in
                    self?.showSettlementSuccess(summary)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.showError("Failed to settle bet: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showSettlementSuccess(_ summary: SettlementSummary) {
        let alert = NSAlert()
        alert.messageText = "Bet Settled Successfully"
        
        var message = "Ticket #\(summary.ticketNumber) has been settled as \(summary.status).\n\n"
        
        if !summary.winners.isEmpty {
            message += "Winners:\n"
            for winner in summary.winners {
                message += "• \(winner.name): +$\(String(format: "%.2f", winner.profit))\n"
            }
        }
        
        if !summary.losers.isEmpty {
            message += "\nLosers:\n"
            for loser in summary.losers {
                message += "• \(loser.name): -$\(String(format: "%.2f", loser.loss))\n"
            }
        }
        
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func createSettledBet(betData: BetData, base64Screenshot: String, participantsText: String) {
        Task {
            do {
                // Parse participants to format them properly
                let parseResult = ParticipantParser.parse(participantsText, totalRisk: betData.risk)
                
                if !parseResult.errors.isEmpty {
                    await MainActor.run { [weak self] in
                        self?.showError("Failed to parse participants: \(parseResult.errors.joined(separator: ", "))")
                    }
                    return
                }
                
                // Format participants for the API
                let formattedParticipants = parseResult.participants
                    .map { "\($0.name): \(String(format: "%.2f", $0.stake))" }
                    .joined(separator: ", ")
                
                let response = try await SupabaseClient.shared.addBet(
                    screenshot: base64Screenshot,
                    participantsText: formattedParticipants,
                    whoPaid: nil,
                    betData: betData
                )
                
                if response.success {
                    await MainActor.run { [weak self] in
                        self?.showSuccess("Settled bet created successfully! Ticket #\(betData.ticket_number)")
                    }
                } else {
                    throw SupabaseError.apiError(response.error ?? "Unknown error")
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.showError("Failed to create settled bet: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func processPaymentRecording(from: String, to: String, amount: Double, method: String?, note: String?) {
        Task {
            do {
                let response = try await SupabaseClient.shared.recordPayment(
                    fromUserName: from,
                    toUserName: to,
                    amount: amount,
                    paymentMethod: method,
                    note: note
                )
                
                await MainActor.run { [weak self] in
                    if let payment = response.payment {
                        var message = "Payment of $\(String(format: "%.2f", payment.amount)) from \(payment.from) to \(payment.to) recorded successfully."
                        
                        // Add balance change information
                        if let netEffect = response.payment?.net_effect {
                            message += "\n\n"
                            message += "\(netEffect.from_user.name): $\(String(format: "%.2f", netEffect.from_user.new_outstanding)) outstanding\n"
                            message += "\(netEffect.to_user.name): $\(String(format: "%.2f", netEffect.to_user.new_outstanding)) outstanding"
                        }
                        
                        self?.showSuccess(message)
                    } else {
                        self?.showSuccess("Payment recorded successfully!")
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.showError("Failed to record payment: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var screenshotManager = ScreenshotManager()
    @StateObject private var authManager = AuthenticationManager.shared
    @EnvironmentObject var appDelegate: AppDelegate
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 10) {
            if authManager.isAuthenticated {
                // Authenticated user menu
                if let email = authManager.currentUserEmail {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                }
                
                Button("Take Bet Screenshot") {
                    dismiss()
                    NotificationCenter.default.post(name: .takeScreenshot, object: nil)
                }
                .help(AppShortcut.takeScreenshot.displayString)
                
                Button("Manual Bet Entry") {
                    dismiss()
                    NotificationCenter.default.post(name: .manualEntry, object: nil)
                }
                .help(AppShortcut.manualEntry.displayString)
                
                Button("Load Bet Screenshot...") {
                    dismiss()
                    NotificationCenter.default.post(name: .loadScreenshot, object: nil)
                }
                .help(AppShortcut.loadScreenshot.displayString)
                
                Divider()
                
                Button("Record Payment") {
                    dismiss()
                    NotificationCenter.default.post(name: .recordPayment, object: nil)
                }
                .help(AppShortcut.recordPayment.displayString)
                
                Divider()
                
                Button("Open Screenshots Folder") {
                    dismiss()
                    screenshotManager.openScreenshotsFolder()
                }
                
                Button("Settings...") {
                    dismiss()
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .help(AppShortcut.settings.displayString)
                
                Divider()
                
                Button("Sign Out") {
                    authManager.signOut()
                }
                
            } else {
                // Not authenticated menu
                Text("Not signed in")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Sign In") {
                    dismiss()
                    appDelegate.showAuthenticationWindow()
                }
                .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .help(AppShortcut.quit.displayString)
        }
        .padding()
        .frame(width: 250)
    }
}

@MainActor
class ScreenshotManager: ObservableObject {
    @AppStorage("screenshotLocation") private var customLocation = ""
    
    private var baseDirectory: URL {
        if !customLocation.isEmpty {
            return URL(fileURLWithPath: customLocation)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/BetTracker")
    }
    
    func captureScreenshot() async -> String? {
        // Create directory if needed
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        
        let tempPath = "/tmp/bet_\(UUID().uuidString).png"
        
        // Use screencapture with interactive selection
        let process = Process()
        process.launchPath = "/usr/sbin/screencapture"
        process.arguments = ["-i", "-s", tempPath]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Check if file was created (user didn't cancel)
            if FileManager.default.fileExists(atPath: tempPath) {
                // Generate final filename
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let timestamp = formatter.string(from: Date())
                let filename = "BetScreenshot_\(timestamp).png"
                let finalPath = baseDirectory.appendingPathComponent(filename)
                
                // Move to final location
                try FileManager.default.moveItem(
                    at: URL(fileURLWithPath: tempPath),
                    to: finalPath
                )
                
                // Play sound
                NSSound(named: "Grab")?.play()
                
                return finalPath.path
            }
        } catch {
            print("Screenshot failed: \(error)")
        }
        
        return nil
    }
    
    func openScreenshotsFolder() {
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(baseDirectory)
    }
    
    func loadScreenshot() -> String? {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Bet Screenshot"
        openPanel.message = "Choose a bet screenshot to analyze"
        // openPanel.showsResizeIndicator = true // Deprecated in macOS 15.0
        openPanel.showsHiddenFiles = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.png, .jpeg, .heic]
        
        if openPanel.runModal() == .OK {
            guard let sourceURL = openPanel.url else { return nil }
            
            // Create directory if needed
            try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            
            // Generate filename with timestamp
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = formatter.string(from: Date())
            let filename = "BetScreenshot_loaded_\(timestamp).\(sourceURL.pathExtension)"
            let destinationURL = baseDirectory.appendingPathComponent(filename)
            
            do {
                // Copy file to screenshots folder
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                return destinationURL.path
            } catch {
                print("Error copying screenshot: \(error)")
                // If copy fails, just return the original path
                return sourceURL.path
            }
        }
        
        return nil
    }
}

