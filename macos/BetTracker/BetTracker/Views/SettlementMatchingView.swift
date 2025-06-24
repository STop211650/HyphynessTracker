import SwiftUI

struct SettlementMatchingView: View {
    let screenshotPath: String
    let parsedBetData: BetData
    let matches: [BetMatch]
    let base64Screenshot: String
    let onSelectMatch: (String) -> Void
    let onCreateNew: () -> Void
    let onCancel: () -> Void
    
    @State private var selectedMatchId: String?
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Settlement Detected")
                    .font(.headline)
                Text("This bet appears to be settled as: \(parsedBetData.status.capitalized)")
                    .foregroundColor(statusColor)
                if !parsedBetData.ticket_number.isEmpty {
                    Text("Ticket #\(parsedBetData.ticket_number)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Settlement Details
            HStack(spacing: 40) {
                // Screenshot
                VStack {
                    if let image = NSImage(contentsOfFile: screenshotPath) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                
                // Parsed Details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Settlement Details:")
                        .font(.headline)
                    
                    DetailRow(label: "Type", value: parsedBetData.type.capitalized)
                    DetailRow(label: "Odds", value: parsedBetData.odds)
                    DetailRow(label: "Risk", value: String(format: "$%.2f", parsedBetData.risk))
                    DetailRow(label: "To Win", value: String(format: "$%.2f", parsedBetData.to_win))
                    DetailRow(label: "Result", value: parsedBetData.status.capitalized)
                        .foregroundColor(statusColor)
                }
            }
            
            Divider()
            
            // Matching Bets Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Matching Pending Bets:")
                    .font(.headline)
                
                if matches.isEmpty {
                    Text("No matching pending bets found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(matches, id: \.id) { match in
                                MatchRow(
                                    match: match,
                                    isSelected: selectedMatchId == match.id,
                                    onSelect: {
                                        selectedMatchId = match.id
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                
                Button("Create New Entry") {
                    onCreateNew()
                }
                
                Button("Update Selected") {
                    if let matchId = selectedMatchId {
                        onSelectMatch(matchId)
                    }
                }
                .keyboardShortcut(.return)
                .disabled(selectedMatchId == nil)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 700, height: 600)
    }
    
    var statusColor: Color {
        switch parsedBetData.status {
        case "won":
            return .green
        case "lost":
            return .red
        case "push":
            return .orange
        case "void":
            return .gray
        default:
            return .primary
        }
    }
}

struct MatchRow: View {
    let match: BetMatch
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Ticket #\(match.bet_data.ticket_number)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("\(match.confidence)% match")
                            .font(.caption)
                            .foregroundColor(confidenceColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(confidenceColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    HStack(spacing: 16) {
                        Text("\(match.bet_data.type.capitalized)")
                            .font(.caption)
                        Text(String(format: "$%.2f", match.bet_data.risk) + " @ \(match.bet_data.odds)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatDate(match.created_at))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    var confidenceColor: Color {
        if match.confidence >= 80 {
            return .green
        } else if match.confidence >= 60 {
            return .orange
        } else {
            return .red
        }
    }
    
    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}