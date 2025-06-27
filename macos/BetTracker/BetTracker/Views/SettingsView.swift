import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("screenshotLocation") private var screenshotLocation = ""
    @AppStorage("alwaysRequireApproval") private var alwaysRequireApproval = true
    @AppStorage("autoApproveHighConfidence") private var autoApproveHighConfidence = false
    
    @State private var selectedTab = "general"
    @State private var showingFolderPicker = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // General Tab
            GeneralSettingsView(
                screenshotLocation: $screenshotLocation,
                showingFolderPicker: $showingFolderPicker
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            .tag("general")
            
            // Approval Tab
            ApprovalSettingsView(
                alwaysRequireApproval: $alwaysRequireApproval,
                autoApproveHighConfidence: $autoApproveHighConfidence
            )
            .tabItem {
                Label("Approval", systemImage: "checkmark.circle")
            }
            .tag("approval")
            
            // About Tab
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag("about")
        }
        .frame(width: 500, height: 400)
        .onEscapeKey {
            // For settings, we just close the window
            if let window = NSApp.keyWindow {
                window.close()
            }
        }
        .sheet(isPresented: $showingFolderPicker) {
            FolderPickerView(selectedPath: $screenshotLocation)
        }
    }
}

struct GeneralSettingsView: View {
    @Binding var screenshotLocation: String
    @Binding var showingFolderPicker: Bool
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Screenshot Storage Location")
                        .font(.headline)
                    
                    HStack {
                        Text(displayPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        
                        Button("Choose...") {
                            showingFolderPicker = true
                        }
                    }
                    
                    Text("Screenshots will be saved to this location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Keyboard Shortcuts")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    // Display all shortcuts from AppShortcut
                    ForEach(AppShortcut.allShortcuts.indices, id: \.self) { index in
                        let shortcut = AppShortcut.allShortcuts[index]
                        HStack {
                            Text(shortcut.description + ":")
                            Spacer()
                            Text(shortcut.displayString)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("Global shortcuts use Option+Shift (⌥⇧) to avoid conflicts with other apps.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
    }
    
    private var displayPath: String {
        if screenshotLocation.isEmpty {
            return "~/Documents/BetTracker"
        }
        
        // Convert to tilde path for display
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if screenshotLocation.hasPrefix(homeDir) {
            return screenshotLocation.replacingOccurrences(of: homeDir, with: "~")
        }
        
        return screenshotLocation
    }
}

struct ApprovalSettingsView: View {
    @Binding var alwaysRequireApproval: Bool
    @Binding var autoApproveHighConfidence: Bool
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Approval Settings")
                        .font(.headline)
                    
                    Toggle("Always require approval", isOn: $alwaysRequireApproval)
                    
                    Toggle("Auto-approve high confidence bets", isOn: $autoApproveHighConfidence)
                        .disabled(alwaysRequireApproval)
                    
                    if !alwaysRequireApproval && autoApproveHighConfidence {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("High confidence bets will be automatically approved")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("You can still review them in the dashboard")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 20)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Approval Workflow")
                        .font(.headline)
                    
                    Text("When approval is required:")
                        .font(.subheadline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Review parsed bet details", systemImage: "1.circle.fill")
                        Label("Edit any incorrect information", systemImage: "2.circle.fill")
                        Label("Verify participant stakes", systemImage: "3.circle.fill")
                        Label("Approve or reject the bet", systemImage: "4.circle.fill")
                    }
                    .font(.caption)
                    .padding(.leading, 12)
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dice")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("BetTracker")
                .font(.title)
                .bold()
            
            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.horizontal, 40)
            
            VStack(spacing: 8) {
                Text("Track and manage sports bets with friends")
                    .font(.body)
                
                Text("Built with SwiftUI and Supabase")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Link("Visit Dashboard", destination: URL(string: "https://anxncoikpbipuplrkqrd.supabase.co")!)
                .buttonStyle(.link)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Folder picker view
struct FolderPickerView: View {
    @Binding var selectedPath: String
    @Environment(\.dismiss) var dismiss
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Choose Screenshot Folder")
                .font(.headline)
            
            // Simple instruction
            Text("Select a folder where screenshots will be saved")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Choose Folder") {
                    selectFolder()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        
        // Set initial directory
        if !selectedPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: selectedPath)
        } else {
            panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        }
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                selectedPath = url.path
                dismiss()
            }
        }
    }
}