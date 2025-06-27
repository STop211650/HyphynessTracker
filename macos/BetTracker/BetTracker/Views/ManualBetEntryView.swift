import SwiftUI

struct ManualBetEntryView: View {
    @State private var ticketNumber = ""
    @State private var sportsbook = ""
    @State private var betType = "straight"
    @State private var odds = ""
    @State private var risk = ""
    @State private var toWin = ""
    @State private var participantsText = ""
    @State private var legs: [ManualBetLeg] = []
    @State private var showingLegEntry = false
    @State private var isProcessing = false
    @State private var errorMessage = ""
    @State private var showError = false
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case ticketNumber
    }
    
    let onSubmit: (String, BetData) -> Void
    let onCancel: () -> Void
    
    var betTypes = ["straight", "parlay", "teaser", "round_robin", "futures"]
    
    var isValid: Bool {
        !ticketNumber.isEmpty &&
        !betType.isEmpty &&
        !odds.isEmpty &&
        Double(risk) != nil &&
        Double(toWin) != nil &&
        !participantsText.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Manual Bet Entry")
                .font(.headline)
                .padding(.top)
            
            // Form
            Form {
                Section("Bet Details") {
                    TextField("Ticket Number", text: $ticketNumber)
                        .focused($focusedField, equals: .ticketNumber)
                    TextField("Sportsbook (optional)", text: $sportsbook)
                    
                    Picker("Bet Type", selection: $betType) {
                        ForEach(betTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    
                    TextField("Odds (e.g., +150 or -110)", text: $odds)
                    
                    HStack {
                        TextField("Risk Amount", text: $risk)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("$")
                    }
                    
                    HStack {
                        TextField("To Win Amount", text: $toWin)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("$")
                    }
                }
                
                if betType == "parlay" {
                    Section("Parlay Legs") {
                        if legs.isEmpty {
                            Text("No legs added")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(legs) { leg in
                                VStack(alignment: .leading) {
                                    Text(leg.event)
                                        .font(.caption)
                                    Text("\(leg.market): \(leg.selection) @ \(leg.odds)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Button("Add Leg") {
                            showingLegEntry = true
                        }
                    }
                }
                
                Section("Participants") {
                    VStack(alignment: .leading) {
                        Text("Enter participants and their stakes:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $participantsText)
                            .frame(minHeight: 60)
                            .font(.system(.body, design: .monospaced))
                        
                        Text("Examples: \"Sam: 50, Alex: 30\" or \"Sam, Alex split equally\"")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            
            // Error message
            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                
                Button("Submit") {
                    submitBet()
                }
                .keyboardShortcut(.return)
                .disabled(!isValid || isProcessing)
            }
            .padding(.bottom)
        }
        .frame(width: 500, height: 600)
        .onAppear {
            // Focus the first text field after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .ticketNumber
            }
        }
        .onEscapeKey {
            onCancel()
        }
        .sheet(isPresented: $showingLegEntry) {
            LegEntryView { leg in
                legs.append(leg)
            }
        }
    }
    
    private func submitBet() {
        guard let riskAmount = Double(risk),
              let toWinAmount = Double(toWin) else {
            errorMessage = "Invalid risk or win amount"
            showError = true
            return
        }
        
        let betData = BetData(
            sportsbook: sportsbook.isEmpty ? nil : sportsbook,
            ticket_number: ticketNumber,
            type: betType,
            odds: odds,
            risk: riskAmount,
            to_win: toWinAmount,
            status: "pending",
            legs: legs.map { BetLeg(
                event: $0.event,
                market: $0.market,
                selection: $0.selection,
                odds: $0.odds
            )}
        )
        
        onSubmit(participantsText, betData)
    }
}

struct LegEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var event = ""
    @State private var market = ""
    @State private var selection = ""
    @State private var odds = ""
    
    let onAdd: (ManualBetLeg) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Parlay Leg")
                .font(.headline)
            
            Form {
                TextField("Event (e.g., Lakers vs Warriors)", text: $event)
                TextField("Market (e.g., Spread, Total)", text: $market)
                TextField("Selection (e.g., Lakers -5.5)", text: $selection)
                TextField("Odds (e.g., -110)", text: $odds)
            }
            .padding()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Add") {
                    let leg = ManualBetLeg(
                        event: event,
                        market: market,
                        selection: selection,
                        odds: odds
                    )
                    onAdd(leg)
                    dismiss()
                }
                .disabled(event.isEmpty || market.isEmpty || selection.isEmpty || odds.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

struct ManualBetLeg: Identifiable {
    let id = UUID()
    let event: String
    let market: String
    let selection: String
    let odds: String
}