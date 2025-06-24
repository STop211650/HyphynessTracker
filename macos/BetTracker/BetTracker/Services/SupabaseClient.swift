import Foundation

class SupabaseClient {
    static let shared = SupabaseClient()
    
    private let baseURL = "https://anxncoikpbipuplrkqrd.supabase.co"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFueG5jb2lrcGJpcHVwbHJrcXJkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk3ODY1OTMsImV4cCI6MjA2NTM2MjU5M30.gMAaJ1h7ZmiSbaInhNgYNCsJhLj8SljiawkDyWlYrGQ"
    
    private init() {}
    
    // Add a bet
    func addBet(screenshot: String, participantsText: String, whoPaid: String? = nil, betData: BetData? = nil) async throws -> AddBetResponse {
        guard let authToken = AuthenticationManager.shared.getStoredAuthToken() else {
            throw SupabaseError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/functions/v1/add-bet")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let betDataOverride: BetDataOverride? = betData.map { data in
            BetDataOverride(
                type: data.type,
                odds: data.odds,
                risk: data.risk,
                to_win: data.to_win,
                status: data.status,
                sportsbook: data.sportsbook,
                ticket_number: data.ticket_number,
                legs: data.legs
            )
        }
        
        let body = AddBetRequest(
            screenshot: screenshot,
            participants_text: participantsText,
            who_paid: whoPaid,
            bet_data_override: betDataOverride
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(AddBetResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw SupabaseError.apiError(errorResponse.error)
            }
            throw SupabaseError.unknownError(statusCode: httpResponse.statusCode)
        }
    }
    
    // Parse bet screenshot using vision API
    func parseBetScreenshot(_ base64Image: String) async throws -> BetData {
        guard let authToken = AuthenticationManager.shared.getStoredAuthToken() else {
            print("SupabaseClient: No auth token found")
            throw SupabaseError.notAuthenticated
        }
        print("SupabaseClient: Auth token found, making parse-bet request")
        
        let url = URL(string: "\(baseURL)/functions/v1/parse-bet")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let body = ["screenshot": base64Image]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError
        }
        
        print("SupabaseClient: parse-bet response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            do {
                let parseResponse = try JSONDecoder().decode(ParseBetResponse.self, from: data)
                if parseResponse.success, let parsedData = parseResponse.bet_data {
                // Convert ParsedBetData to BetData
                return BetData(
                    sportsbook: parsedData.sportsbook,
                    ticket_number: parsedData.ticket_number,
                    type: parsedData.type,
                    odds: parsedData.odds,
                    risk: parsedData.risk,
                    to_win: parsedData.to_win,
                    status: parsedData.status,
                    legs: parsedData.legs.map { leg in
                        BetLeg(
                            event: leg.event,
                            market: leg.market,
                            selection: leg.selection,
                            odds: leg.odds
                        )
                    }
                )
                } else {
                    throw SupabaseError.apiError(parseResponse.error ?? "Failed to parse bet")
                }
            } catch DecodingError.dataCorrupted(let context) {
                print("SupabaseClient: Data corrupted - \(context)")
                print("SupabaseClient: Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.apiError("Data corrupted: \(context.debugDescription)")
            } catch DecodingError.keyNotFound(let key, let context) {
                print("SupabaseClient: Key '\(key)' not found - \(context)")
                print("SupabaseClient: Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.apiError("Missing key: \(key.stringValue)")
            } catch DecodingError.typeMismatch(let type, let context) {
                print("SupabaseClient: Type mismatch for type \(type) - \(context)")
                print("SupabaseClient: Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.apiError("Type mismatch: \(context.debugDescription)")
            } catch DecodingError.valueNotFound(let type, let context) {
                print("SupabaseClient: Value not found for type \(type) - \(context)")
                print("SupabaseClient: Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.apiError("Value not found: \(context.debugDescription)")
            } catch {
                print("SupabaseClient: Unknown decoding error - \(error)")
                print("SupabaseClient: Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw error
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw SupabaseError.apiError(errorResponse.error)
            }
            throw SupabaseError.unknownError(statusCode: httpResponse.statusCode)
        }
    }
    
    // Find matching pending bets
    func findMatchingBets(betData: BetData, ticketNumber: String? = nil) async throws -> [BetMatch] {
        guard let authToken = AuthenticationManager.shared.getStoredAuthToken() else {
            throw SupabaseError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/functions/v1/find-matching-bet")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let body = FindMatchingBetRequest(
            bet_data: betData,
            ticket_number: ticketNumber
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let matchResponse = try JSONDecoder().decode(FindMatchingBetResponse.self, from: data)
            if matchResponse.success {
                return matchResponse.matches ?? []
            } else {
                throw SupabaseError.apiError(matchResponse.error ?? "Failed to find matching bets")
            }
        } else {
            throw SupabaseError.unknownError(statusCode: httpResponse.statusCode)
        }
    }
    
    // Settle a bet with screenshot proof
    func settleBetWithScreenshot(betId: String, screenshot: String) async throws -> SettlementSummary {
        guard let authToken = AuthenticationManager.shared.getStoredAuthToken() else {
            throw SupabaseError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/functions/v1/settle-with-screenshot")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let body = SettleWithScreenshotRequest(
            screenshot: screenshot,
            bet_id: betId
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let settleResponse = try JSONDecoder().decode(SettleBetResponse.self, from: data)
            if settleResponse.success, let settlement = settleResponse.settlement {
                return SettlementSummary(
                    betId: settlement.bet_id,
                    ticketNumber: settlement.ticket_number,
                    status: settlement.status,
                    risk: settlement.risk,
                    totalPayout: settlement.total_payout,
                    winners: settlement.winners.map { WinnerInfo(name: $0.name, profit: $0.profit) },
                    losers: settlement.losers.map { LoserInfo(name: $0.name, loss: $0.loss) }
                )
            } else {
                throw SupabaseError.apiError(settleResponse.error ?? "Failed to settle bet")
            }
        } else {
            throw SupabaseError.unknownError(statusCode: httpResponse.statusCode)
        }
    }
    
    // Settle a bet
    func settleBet(betId: String, status: String) async throws -> SettlementSummary {
        guard let authToken = AuthenticationManager.shared.getStoredAuthToken() else {
            throw SupabaseError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/functions/v1/settle-bet")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let body = ["bet_id": betId, "status": status]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let settleResponse = try JSONDecoder().decode(SettleBetResponse.self, from: data)
            if settleResponse.success, let settlement = settleResponse.settlement {
                return SettlementSummary(
                    betId: settlement.bet_id,
                    ticketNumber: settlement.ticket_number,
                    status: settlement.status,
                    risk: settlement.risk,
                    totalPayout: settlement.total_payout,
                    winners: settlement.winners,
                    losers: settlement.losers
                )
            } else {
                throw SupabaseError.apiError(settleResponse.error ?? "Failed to settle bet")
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw SupabaseError.apiError(errorResponse.error)
            }
            throw SupabaseError.unknownError(statusCode: httpResponse.statusCode)
        }
    }
    
    // Get active bets for the user
    func getActiveBets() async throws -> [ActiveBet] {
        guard let authToken = AuthenticationManager.shared.getStoredAuthToken() else {
            throw SupabaseError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/functions/v1/get-active-bets")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let betsResponse = try JSONDecoder().decode(ActiveBetsResponse.self, from: data)
            if betsResponse.success, let bets = betsResponse.bets {
                return bets.map { bet in
                    ActiveBet(
                        id: bet.id,
                        ticket_number: bet.ticket_number,
                        risk: bet.risk,
                        to_win: bet.to_win,
                        odds: bet.odds,
                        participants: bet.participants.map { p in
                            BetParticipant(
                                user_id: p.user_id,
                                name: p.name,
                                stake: p.stake
                            )
                        },
                        status: bet.status,
                        placed_at: ISO8601DateFormatter().date(from: bet.placed_at) ?? Date()
                    )
                }
            } else {
                throw SupabaseError.apiError(betsResponse.error ?? "Failed to get active bets")
            }
        } else {
            throw SupabaseError.unknownError(statusCode: httpResponse.statusCode)
        }
    }
}

// Request/Response models
struct AddBetRequest: Codable {
    let screenshot: String
    let participants_text: String
    let who_paid: String?
    let bet_data_override: BetDataOverride?
}

struct BetDataOverride: Codable {
    let type: String
    let odds: String
    let risk: Double
    let to_win: Double
    let status: String
    let sportsbook: String?
    let ticket_number: String
    let legs: [BetLeg]
}

struct AddBetResponse: Codable {
    let success: Bool
    let bet: BetInfo?
    let error: String?
}

struct BetInfo: Codable {
    let id: String
    let ticket_number: String
    let type: String
    let risk: Double
    let to_win: Double
    let participants: [ParticipantInfo]
}

struct ParticipantInfo: Codable {
    let name: String
    let stake: Double
}

struct ErrorResponse: Codable {
    let success: Bool
    let error: String
}

struct ParseBetResponse: Codable {
    let success: Bool
    let bet_data: ParsedBetData?
    let error: String?
}

struct ParsedBetData: Codable {
    let sportsbook: String?
    let ticket_number: String
    let type: String
    let odds: String
    let risk: Double
    let to_win: Double
    let status: String
    let legs: [ParsedBetLeg]
}

struct ParsedBetLeg: Codable {
    let event: String
    let market: String
    let selection: String
    let odds: String?
}

// Errors
// Settlement models
struct SettleBetResponse: Codable {
    let success: Bool
    let settlement: SettlementInfo?
    let error: String?
}

struct SettlementInfo: Codable {
    let bet_id: String
    let ticket_number: String
    let status: String
    let risk: Double
    let total_payout: Double
    let winners: [WinnerInfo]
    let losers: [LoserInfo]
}

struct WinnerInfo: Codable {
    let name: String
    let profit: Double
}

struct LoserInfo: Codable {
    let name: String
    let loss: Double
}

// Active bets models
struct ActiveBetsResponse: Codable {
    let success: Bool
    let bets: [ActiveBetInfo]?
    let error: String?
}

struct ActiveBetInfo: Codable {
    let id: String
    let ticket_number: String
    let risk: Double
    let to_win: Double
    let odds: String
    let status: String
    let placed_at: String
    let participants: [ActiveBetParticipant]
}

struct ActiveBetParticipant: Codable {
    let user_id: String
    let name: String
    let stake: Double
}

// Find matching bet models
struct FindMatchingBetRequest: Codable {
    let bet_data: BetData
    let ticket_number: String?
}

struct FindMatchingBetResponse: Codable {
    let success: Bool
    let matches: [BetMatch]?
    let error: String?
}

struct BetMatch: Codable {
    let id: String
    let confidence: Int
    let bet_data: BetData
    let created_at: String
}

// Settle with screenshot models
struct SettleWithScreenshotRequest: Codable {
    let screenshot: String
    let bet_id: String
}

enum SupabaseError: LocalizedError {
    case notAuthenticated
    case networkError
    case apiError(String)
    case unknownError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue"
        case .networkError:
            return "Network error. Please check your connection."
        case .apiError(let message):
            return message
        case .unknownError(let code):
            return "Server error (code: \(code))"
        }
    }
}