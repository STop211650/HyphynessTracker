import SwiftUI
import AppKit

struct BetApprovalView: View {
    let screenshotPath: String
    let betData: BetData
    let participants: [ParsedParticipant]
    let onApprove: (BetData, [ParsedParticipant]) -> Void
    let onReject: () -> Void
    
    @State private var editedOdds: String
    @State private var editedRisk: String
    @State private var editedToWin: String
    @State private var editedStatus: String
    @State private var editedType: String
    @State private var editedParticipants: [EditableParticipant]
    @State private var isProcessing = false
    @State private var errorMessage = ""
    @State private var screenshotImage: NSImage?
    
    init(screenshotPath: String, 
         betData: BetData, 
         participants: [ParsedParticipant],
         onApprove: @escaping (BetData, [ParsedParticipant]) -> Void,
         onReject: @escaping () -> Void) {
        self.screenshotPath = screenshotPath
        self.betData = betData
        self.participants = participants
        self.onApprove = onApprove
        self.onReject = onReject
        
        // Initialize editable state
        self._editedOdds = State(initialValue: betData.odds)
        self._editedRisk = State(initialValue: String(format: "%.2f", betData.risk))
        self._editedToWin = State(initialValue: String(format: "%.2f", betData.to_win))
        self._editedStatus = State(initialValue: betData.status)
        self._editedType = State(initialValue: betData.type)
        
        // Smart participant initialization
        let totalStakes = participants.reduce(0) { $0 + $1.stake }
        let matchesWinnings = abs(totalStakes - betData.to_win) < 0.01
        
        if betData.status.lowercased() == "won" && matchesWinnings {
            // For won bets where amounts match winnings, calculate risk proportionally
            self._editedParticipants = State(initialValue: participants.map { participant in
                let winningsRatio = participant.stake / betData.to_win
                let calculatedStake = betData.risk * winningsRatio
                return EditableParticipant(
                    id: UUID(), 
                    name: participant.name, 
                    stake: String(format: "%.2f", calculatedStake),
                    winnings: String(format: "%.2f", participant.stake)
                )
            })
        } else {
            // Standard case - amounts are stakes
            self._editedParticipants = State(initialValue: participants.map { 
                EditableParticipant(
                    id: UUID(), 
                    name: $0.name, 
                    stake: String(format: "%.2f", $0.stake),
                    winnings: betData.status.lowercased() == "won" ? String(format: "%.2f", $0.stake * (betData.to_win / betData.risk)) : nil
                )
            })
        }
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Left side - Screenshot
            VStack {
                Text("Screenshot")
                    .font(.headline)
                
                if let image = screenshotImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 400, maxHeight: 500)
                        .border(Color.gray.opacity(0.3), width: 1)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 400, height: 300)
                        .overlay(
                            ProgressView()
                        )
                }
            }
            
            // Right side - Editable details
            VStack(alignment: .leading, spacing: 16) {
                Text("Verify Bet Details")
                    .font(.title2)
                    .bold()
                
                // Bet details
                GroupBox("Bet Information") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Type:")
                                .frame(width: 80, alignment: .trailing)
                            Picker("", selection: $editedType) {
                                Text("Straight").tag("straight")
                                Text("Parlay").tag("parlay")
                                Text("Future").tag("future")
                                Text("Prop").tag("prop")
                                Text("Live").tag("live")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                        
                        HStack {
                            Text("Odds:")
                                .frame(width: 80, alignment: .trailing)
                            TextField("Odds", text: $editedOdds)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }
                        
                        HStack {
                            Text("Risk:")
                                .frame(width: 80, alignment: .trailing)
                            TextField("Risk", text: $editedRisk)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }
                        
                        HStack {
                            Text("To Win:")
                                .frame(width: 80, alignment: .trailing)
                            TextField("To Win", text: $editedToWin)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }
                        
                        HStack {
                            Text("Status:")
                                .frame(width: 80, alignment: .trailing)
                            Picker("", selection: $editedStatus) {
                                Text("Pending").tag("pending")
                                Text("Won").tag("won")
                                Text("Lost").tag("lost")
                                Text("Push").tag("push")
                                Text("Void").tag("void")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Participants
                GroupBox("Participants") {
                    VStack(alignment: .leading, spacing: 8) {
                        // Headers for won bets
                        if editedStatus.lowercased() == "won" {
                            HStack {
                                Text("Name")
                                    .frame(width: 150, alignment: .leading)
                                    .font(.caption)
                                Text("Risked")
                                    .frame(width: 88, alignment: .center)
                                    .font(.caption)
                                Text("Won")
                                    .frame(width: 88, alignment: .center)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        ForEach($editedParticipants) { $participant in
                            HStack {
                                TextField("Name", text: $participant.name)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 150)
                                
                                // Risk amount
                                HStack(spacing: 2) {
                                    Text("$")
                                    TextField("Stake", text: $participant.stake)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 70)
                                }
                                
                                // Winnings (for won bets)
                                if editedStatus.lowercased() == "won" {
                                    HStack(spacing: 2) {
                                        Text("$")
                                        TextField("Winnings", text: Binding(
                                            get: { participant.winnings ?? "" },
                                            set: { participant.winnings = $0 }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 70)
                                    }
                                }
                            }
                        }
                        
                        // Total validation
                        let totalStakes = editedParticipants.compactMap { Double($0.stake) }.reduce(0, +)
                        let risk = Double(editedRisk) ?? 0
                        if abs(totalStakes - risk) > 0.01 {
                            Text("⚠️ Stakes total $\(String(format: "%.2f", totalStakes)) but risk is $\(String(format: "%.2f", risk))")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        // Winnings validation for won bets
                        if editedStatus.lowercased() == "won" {
                            let totalWinnings = editedParticipants.compactMap { Double($0.winnings ?? "0") }.reduce(0, +)
                            let toWin = Double(editedToWin) ?? 0
                            if abs(totalWinnings - toWin) > 0.01 {
                                Text("⚠️ Winnings total $\(String(format: "%.2f", totalWinnings)) but to win is $\(String(format: "%.2f", toWin))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Reject") {
                        onReject()
                    }
                    .keyboardShortcut(.escape)
                    
                    Button("Approve") {
                        handleApprove()
                    }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                }
            }
            .frame(width: 400)
            .padding(.vertical)
        }
        .padding()
        .frame(width: 850, height: 600)
        .onAppear {
            loadScreenshot()
        }
    }
    
    private var isValid: Bool {
        // Check if all fields have valid values
        guard Double(editedRisk) != nil,
              Double(editedToWin) != nil,
              !editedOdds.isEmpty else {
            return false
        }
        
        // Check if all participants have valid stakes
        for participant in editedParticipants {
            if participant.name.isEmpty || Double(participant.stake) == nil {
                return false
            }
        }
        
        // Check if stakes match risk
        let totalStakes = editedParticipants.compactMap { Double($0.stake) }.reduce(0, +)
        let risk = Double(editedRisk) ?? 0
        return abs(totalStakes - risk) < 0.01
    }
    
    private func loadScreenshot() {
        if let image = NSImage(contentsOfFile: screenshotPath) {
            screenshotImage = image
        }
    }
    
    private func handleApprove() {
        guard isValid else { return }
        
        // Create updated bet data
        var updatedBetData = betData
        updatedBetData.odds = editedOdds
        updatedBetData.risk = Double(editedRisk) ?? betData.risk
        updatedBetData.to_win = Double(editedToWin) ?? betData.to_win
        updatedBetData.status = editedStatus
        updatedBetData.type = editedType
        
        // Create updated participants
        let updatedParticipants = editedParticipants.compactMap { editable in
            if let stake = Double(editable.stake) {
                return ParsedParticipant(name: editable.name, stake: stake)
            }
            return nil
        }
        
        onApprove(updatedBetData, updatedParticipants)
    }
}

// Helper struct for editable participants
struct EditableParticipant: Identifiable {
    let id: UUID
    var name: String
    var stake: String
    var winnings: String?  // Only used for won bets
}

// Bet data structure (temporary - should match backend)
struct BetData: Codable {
    var sportsbook: String?
    var ticket_number: String
    var type: String
    var odds: String
    var risk: Double
    var to_win: Double
    var status: String
    var legs: [BetLeg]
}

struct BetLeg: Codable {
    var event: String
    var market: String
    var selection: String
    var odds: String
}