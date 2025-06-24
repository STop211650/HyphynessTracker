import SwiftUI

@main
struct BetTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("🎲", systemImage: "dice") {
            ContentView()
                .environmentObject(appDelegate)
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var windowControllers: Set<NSWindowController> = []
    var parsingWindowController: NSWindowController?
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Check authentication status on launch
        if !AuthenticationManager.shared.isAuthenticated {
            // Show authentication window after a slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showAuthenticationWindow()
            }
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
        
        let windowController = NSWindowController(window: window)
        windowControllers.insert(windowController)
        
        let hostingView = NSHostingView(
            rootView: AuthenticationView(
                onAuthenticated: { [weak self, weak windowController] token in
                    if let controller = windowController {
                        controller.close()
                        self?.windowControllers.remove(controller)
                    }
                },
                onDismiss: { [weak self, weak windowController] in
                    if let controller = windowController {
                        controller.close()
                        self?.windowControllers.remove(controller)
                    }
                }
            )
        )
        
        window.contentView = hostingView
        windowController.showWindow(nil)
        
        // Make sure window appears on top
        window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showSettingsWindow() {
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
        windowControllers.insert(windowController)
        
        let hostingView = NSHostingView(
            rootView: SettingsView()
        )
        
        window.contentView = hostingView
        windowController.showWindow(nil)
        
        // Handle window close
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak windowController] _ in
            if let controller = windowController {
                self?.windowControllers.remove(controller)
            }
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showManualEntryWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Manual Bet Entry"
        window.center()
        
        let windowController = NSWindowController(window: window)
        windowControllers.insert(windowController)
        
        let hostingView = NSHostingView(
            rootView: ManualBetEntryView(
                onSubmit: { [weak self, weak windowController] participantsText, betData in
                    if let controller = windowController {
                        controller.close()
                        self?.windowControllers.remove(controller)
                    }
                    // Process manual bet entry
                    self?.processManualBetEntry(participantsText: participantsText, betData: betData)
                },
                onCancel: { [weak self, weak windowController] in
                    if let controller = windowController {
                        controller.close()
                        self?.windowControllers.remove(controller)
                    }
                }
            )
        )
        
        window.contentView = hostingView
        windowController.showWindow(nil)
        window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showBetDetailsWindow(for screenshotPath: String) {
        // Step 1: Show bet details input window
        showBetDetailsInputWindow(screenshotPath: screenshotPath)
    }
    
    private func showBetDetailsInputWindow(screenshotPath: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Bet Details"
        window.center()
        
        let windowController = NSWindowController(window: window)
        windowControllers.insert(windowController)
        
        let hostingView = NSHostingView(
            rootView: BetDetailsInputView(
                screenshotPath: screenshotPath,
                onContinue: { [weak self, weak windowController] participantsText in
                    if let controller = windowController {
                        controller.close()
                        self?.windowControllers.remove(controller)
                    }
                    // Process screenshot and show approval window
                    self?.processScreenshotAndShowApproval(screenshotPath: screenshotPath, participantsText: participantsText)
                },
                onCancel: { [weak self, weak windowController] in
                    if let controller = windowController {
                        controller.close()
                        self?.windowControllers.remove(controller)
                    }
                }
            )
        )
        
        window.contentView = hostingView
        windowController.showWindow(nil)
        window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func showParsingWindow() {
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
        
        let hostingView = NSHostingView(rootView: ParsingView())
        window.contentView = hostingView
        
        parsingWindowController?.showWindow(nil)
        window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func closeParsingWindow() {
        parsingWindowController?.close()
        parsingWindowController = nil
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
                            base64Screenshot: base64String
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
        
        let windowController = NSWindowController(window: window)
        windowControllers.insert(windowController)
        
        let hostingView = NSHostingView(
            rootView: BetApprovalView(
                screenshotPath: screenshotPath,
                betData: betData,
                participants: participants,
                onApprove: { [weak self, weak windowController] updatedBetData, updatedParticipants in
                    if let controller = windowController {
                        controller.close()
                        self?.windowControllers.remove(controller)
                    }
                    // Submit bet to Supabase
                    self?.submitBet(
                        betData: updatedBetData,
                        participants: updatedParticipants,
                        participantsText: participantsText,
                        base64Screenshot: base64Screenshot
                    )
                },
                onReject: { [weak self, weak windowController] in
                    if let controller = windowController {
                        controller.close()
                        self?.windowControllers.remove(controller)
                    }
                }
            )
        )
        
        window.contentView = hostingView
        windowController.showWindow(nil)
        window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
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
                                             base64Screenshot: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Settlement Matching"
        window.center()
        
        let windowController = NSWindowController(window: window)
        windowControllers.insert(windowController)
        
        let hostingView = NSHostingView(
            rootView: SettlementMatchingView(
                screenshotPath: screenshotPath,
                parsedBetData: parsedBetData,
                matches: matches,
                base64Screenshot: base64Screenshot,
                onSelectMatch: { [weak self, weak windowController] betId in
                    if let controller = windowController {
                        controller.close()
                        self?.windowControllers.remove(controller)
                    }
                    // Settle the selected bet with screenshot
                    self?.settleWithScreenshot(betId: betId, screenshot: base64Screenshot)
                },
                onCreateNew: { [weak self, weak windowController] in
                    if let controller = windowController {
                        controller.close()
                        self?.windowControllers.remove(controller)
                    }
                    // Create new bet entry with settled status
                    self?.showError("Creating new settled bet entries is not yet supported. Please update an existing pending bet.")
                },
                onCancel: { [weak self, weak windowController] in
                    if let controller = windowController {
                        controller.close()
                        self?.windowControllers.remove(controller)
                    }
                }
            )
        )
        
        window.contentView = hostingView
        windowController.showWindow(nil)
        window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
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
}

struct ContentView: View {
    @StateObject private var screenshotManager = ScreenshotManager()
    @StateObject private var authManager = AuthenticationManager.shared
    @EnvironmentObject var appDelegate: AppDelegate
    
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
                    Task {
                        if let path = await screenshotManager.captureScreenshot() {
                            // Show bet details window via AppDelegate
                            appDelegate.showBetDetailsWindow(for: path)
                        }
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Button("Manual Bet Entry") {
                    appDelegate.showManualEntryWindow()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Button("Load Bet Screenshot...") {
                    if let path = screenshotManager.loadScreenshot() {
                        // Show bet details window via AppDelegate
                        appDelegate.showBetDetailsWindow(for: path)
                    }
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Open Screenshots Folder") {
                    screenshotManager.openScreenshotsFolder()
                }
                
                Button("Settings...") {
                    appDelegate.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
                
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
                    appDelegate.showAuthenticationWindow()
                }
                .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding()
        .frame(width: 200)
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
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["png", "jpg", "jpeg", "heic"]
        
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

