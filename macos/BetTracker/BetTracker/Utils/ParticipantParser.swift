import Foundation

// Structure to hold parsed participant data
struct ParsedParticipant {
    let name: String
    let stake: Double
}

// Parser result with participants and any parsing errors
struct ParserResult {
    let participants: [ParsedParticipant]
    let errors: [String]
    let isEqualSplit: Bool
}

class ParticipantParser {
    
    // Parse natural language input for participants and stakes
    static func parse(_ input: String, totalRisk: Double? = nil) -> ParserResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var errors: [String] = []
        var participants: [ParsedParticipant] = []
        var isEqualSplit = false
        
        // Check for empty input
        if trimmed.isEmpty {
            return ParserResult(participants: [], errors: ["Input is empty"], isEqualSplit: false)
        }
        
        // Check for equal split patterns
        let equalSplitPatterns = [
            "split equally",
            "split evenly",
            "equal split",
            "even split",
            "split this equally",
            "split this evenly"
        ]
        
        let lowercased = trimmed.lowercased()
        for pattern in equalSplitPatterns {
            if lowercased.contains(pattern) {
                isEqualSplit = true
                break
            }
        }
        
        if isEqualSplit {
            // Extract names for equal split
            participants = parseEqualSplit(trimmed)
            
            // Calculate equal stakes if total risk is provided
            if let totalRisk = totalRisk, !participants.isEmpty {
                let stakePerPerson = totalRisk / Double(participants.count)
                participants = participants.map {
                    ParsedParticipant(name: $0.name, stake: stakePerPerson)
                }
            }
        } else {
            // Parse custom amounts
            participants = parseCustomAmounts(trimmed)
        }
        
        // Validate participants
        if participants.isEmpty {
            errors.append("No valid participants found")
        }
        
        // Check for duplicate names
        let names = participants.map { $0.name }
        let uniqueNames = Set(names)
        if names.count != uniqueNames.count {
            errors.append("Duplicate participant names found")
        }
        
        // Validate stakes if total risk is provided
        if let totalRisk = totalRisk, !participants.isEmpty && !isEqualSplit {
            let totalStakes = participants.reduce(0) { $0 + $1.stake }
            if abs(totalStakes - totalRisk) > 0.01 {
                errors.append("Stakes total $\(String(format: "%.2f", totalStakes)) but should equal $\(String(format: "%.2f", totalRisk))")
            }
        }
        
        return ParserResult(participants: participants, errors: errors, isEqualSplit: isEqualSplit)
    }
    
    // Parse equal split format
    private static func parseEqualSplit(_ input: String) -> [ParsedParticipant] {
        var participants: [ParsedParticipant] = []
        
        // Remove equal split keywords
        var cleanedInput = input
        let patterns = ["split equally", "split evenly", "equal split", "even split", "split this equally", "split this evenly"]
        for pattern in patterns {
            cleanedInput = cleanedInput.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        
        // Try to find names separated by commas or "and"
        let separators = CharacterSet(charactersIn: ",")
        let components = cleanedInput.components(separatedBy: separators)
        
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Split by "and" if present
            let andComponents = trimmed.components(separatedBy: " and ")
            for andComponent in andComponents {
                let name = extractName(from: andComponent)
                if !name.isEmpty {
                    participants.append(ParsedParticipant(name: name, stake: 0))
                }
            }
        }
        
        return participants
    }
    
    // Parse custom amounts format
    private static func parseCustomAmounts(_ input: String) -> [ParsedParticipant] {
        var participants: [ParsedParticipant] = []
        
        // Check if input contains commas
        if input.contains(",") {
            // Split by commas first (traditional format)
            let components = input.components(separatedBy: ",")
            
            for component in components {
                let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Try different patterns to extract name and amount
                if let participant = parseNameAmountPair(trimmed) {
                    participants.append(participant)
                }
            }
        } else {
            // No commas found, try to parse space-separated format
            participants = parseSpaceSeparatedAmounts(input)
        }
        
        return participants
    }
    
    // Parse space-separated format without commas (e.g., "Greg 50 Shyam 100")
    private static func parseSpaceSeparatedAmounts(_ input: String) -> [ParsedParticipant] {
        var participants: [ParsedParticipant] = []
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Use regex to find patterns of text followed by numbers
        let pattern = #"([A-Za-z]+(?:\s+[A-Za-z]+)*)\s+(\$?\d+(?:\.\d{1,2})?)"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed))
            
            for match in matches {
                if match.numberOfRanges == 3 {
                    // Extract name (group 1)
                    if let nameRange = Range(match.range(at: 1), in: trimmed) {
                        let name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)
                        
                        // Extract amount (group 2)
                        if let amountRange = Range(match.range(at: 2), in: trimmed) {
                            let amountStr = String(trimmed[amountRange])
                            if let amount = extractAmount(from: amountStr) {
                                participants.append(ParsedParticipant(name: name, stake: amount))
                            }
                        }
                    }
                }
            }
        } catch {
            // If regex fails, fall back to simple word-by-word parsing
            participants = parseSpaceSeparatedFallback(trimmed)
        }
        
        return participants
    }
    
    // Fallback parsing for space-separated format
    private static func parseSpaceSeparatedFallback(_ input: String) -> [ParsedParticipant] {
        var participants: [ParsedParticipant] = []
        let words = input.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        var i = 0
        while i < words.count {
            var nameComponents: [String] = []
            
            // Collect name components until we find a number
            while i < words.count {
                if let _ = extractAmount(from: words[i]) {
                    // Found amount
                    break
                }
                nameComponents.append(words[i])
                i += 1
            }
            
            // If we have a name and there's still an amount to read
            if !nameComponents.isEmpty && i < words.count {
                let name = nameComponents.joined(separator: " ")
                if let amount = extractAmount(from: words[i]) {
                    participants.append(ParsedParticipant(name: name, stake: amount))
                    i += 1
                }
            } else {
                // Move to next word if we couldn't parse
                i += 1
            }
        }
        
        return participants
    }
    
    // Parse a single name-amount pair
    private static func parseNameAmountPair(_ input: String) -> ParsedParticipant? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Pattern 1: "Name: amount" or "Name: $amount"
        if let colonRange = trimmed.range(of: ":") {
            let name = String(trimmed[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let amountStr = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            
            if let amount = extractAmount(from: amountStr) {
                return ParsedParticipant(name: name, stake: amount)
            }
        }
        
        // Pattern 2: "Name amount" or "Name $amount"
        let components = trimmed.components(separatedBy: .whitespaces)
        if components.count >= 2 {
            // Try to find the amount from the end
            for i in stride(from: components.count - 1, through: 1, by: -1) {
                if let amount = extractAmount(from: components[i]) {
                    let name = components[0..<i].joined(separator: " ")
                    return ParsedParticipant(name: name, stake: amount)
                }
            }
        }
        
        return nil
    }
    
    // Extract name from text
    private static func extractName(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common words that might appear
        let wordsToRemove = ["and", "with", "for"]
        var name = trimmed
        for word in wordsToRemove {
            name = name.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }
        
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Extract amount from text
    private static func extractAmount(from text: String) -> Double? {
        var cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove dollar sign if present
        cleanedText = cleanedText.replacingOccurrences(of: "$", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: ",", with: "")
        
        // Try to parse as double
        return Double(cleanedText)
    }
    
    // Validate that stakes sum to total risk
    static func validateStakes(_ participants: [ParsedParticipant], totalRisk: Double) -> Bool {
        let totalStakes = participants.reduce(0) { $0 + $1.stake }
        return abs(totalStakes - totalRisk) < 0.01 // Allow for small floating point differences
    }
}