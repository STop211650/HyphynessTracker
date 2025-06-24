import SwiftUI

struct SettlementView: View {
    @Environment(\.dismiss) var dismiss
    let bet: ActiveBet
    @State private var selectedResult: BetResult = .won
    @State private var isSettling = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showSuccess = false
    @State private var settlementSummary: SettlementSummary?
    
    enum BetResult: String, CaseIterable {
        case won = "won"
        case lost = "lost"
        case push = "push"
        case void = "void"
        
        var displayName: String {
            switch self {
            case .won: return "Won"
            case .lost: return "Lost"
            case .push: return "Push (Tie)"
            case .void: return "Void (Cancelled)"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Settle Bet")
                    .font(.headline)
                Text("Ticket #\(bet.ticket_number)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Participants Summary
            VStack(alignment: .leading, spacing: 12) {
                Text("Participants:")
                    .font(.headline)
                
                ForEach(bet.participants, id: \.user_id) { participant in
                    HStack {
                        Text(participant.name)
                        Spacer()
                        Text("$\(participant.stake, specifier: "%.2f")")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                
                HStack {
                    Text("Total Risk:")
                        .font(.headline)
                    Spacer()
                    Text("$\(bet.risk, specifier: "%.2f")")
                }
                
                HStack {
                    Text("Potential Win:")
                        .font(.headline)
                    Spacer()
                    Text("$\(bet.to_win, specifier: "%.2f")")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Result Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Result:")
                    .font(.headline)
                
                ForEach(BetResult.allCases, id: \.self) { result in
                    HStack {
                        Image(systemName: selectedResult == result ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(selectedResult == result ? .accentColor : .secondary)
                        Text(result.displayName)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedResult = result
                    }
                }
            }
            
            Spacer()
            
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
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Settle") {
                    settleBet()
                }
                .keyboardShortcut(.return)
                .disabled(isSettling)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
        .sheet(isPresented: $showSuccess) {
            if let summary = settlementSummary {
                SettlementSuccessView(summary: summary) {
                    dismiss()
                }
            }
        }
    }
    
    private func settleBet() {
        isSettling = true
        showError = false
        
        Task {
            do {
                let summary = try await SupabaseClient.shared.settleBet(
                    betId: bet.id,
                    status: selectedResult.rawValue
                )
                
                await MainActor.run {
                    settlementSummary = summary
                    showSuccess = true
                    isSettling = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSettling = false
                }
            }
        }
    }
}

struct SettlementSuccessView: View {
    let summary: SettlementSummary
    let onDone: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Settlement Complete")
                .font(.headline)
            
            Text("Bet #\(summary.ticket_number) - \(summary.status.uppercased())")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Show payouts
            if summary.status == "won" {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Payouts:")
                        .font(.headline)
                    
                    ForEach(summary.payouts, id: \.user_id) { payout in
                        HStack {
                            Text(payout.name)
                            Spacer()
                            Text("+$\(payout.profit, specifier: "%.2f")")
                                .foregroundColor(.green)
                            Text("($\(payout.total, specifier: "%.2f") total)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else if summary.status == "lost" {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Losses:")
                        .font(.headline)
                    
                    ForEach(summary.losses, id: \.user_id) { loss in
                        HStack {
                            Text(loss.name)
                            Spacer()
                            Text("-$\(loss.amount, specifier: "%.2f")")
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button("Done") {
                onDone()
            }
            .keyboardShortcut(.return)
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}

// Data models for active bets and settlement
struct ActiveBet: Identifiable {
    let id: String
    let ticket_number: String
    let risk: Double
    let to_win: Double
    let odds: String
    let participants: [BetParticipant]
    let status: String
    let placed_at: Date
}

struct BetParticipant {
    let user_id: String
    let name: String
    let stake: Double
}

struct SettlementSummary {
    let betId: String
    let ticketNumber: String
    let status: String
    let risk: Double
    let totalPayout: Double
    let winners: [WinnerInfo]
    let losers: [LoserInfo]
    
    // Computed properties for backward compatibility
    var ticket_number: String { ticketNumber }
    var payouts: [PayoutInfo] {
        winners.map { winner in
            PayoutInfo(
                user_id: winner.name,
                name: winner.name,
                profit: winner.profit,
                total: winner.profit + (risk / Double(winners.count))
            )
        }
    }
    var losses: [LossInfo] {
        losers.map { loser in
            LossInfo(
                user_id: loser.name,
                name: loser.name,
                amount: loser.loss
            )
        }
    }
}

struct PayoutInfo {
    let user_id: String
    let name: String
    let profit: Double
    let total: Double
}

struct LossInfo {
    let user_id: String
    let name: String
    let amount: Double
}