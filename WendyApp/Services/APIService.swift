import Foundation

struct ChatRequestBody: Encodable {
    let message: String
    let user_id: String
    let agent: String
}

struct ConfirmRequestBody: Encodable {
    let turn_id: String
    let confirmation_id: Int
    let approved: Bool
}

/// Discriminated union both `/api/chat` and `/api/chat/confirm` reply with:
/// either the turn's final text, or a suspended turn awaiting approval of a
/// gated tool call (open-bbum #76).
enum ChatOutcome {
    case reply(String)
    case pendingConfirmation(turnID: String, confirmationID: Int, message: String)
}

private struct ChatResponseBody: Decodable {
    let status: String?
    let response: String?
    let turn_id: String?
    let confirmation_id: Int?
    let message: String?

    func toOutcome() throws -> ChatOutcome {
        if status == "pending_confirmation" {
            guard let turn_id, let confirmation_id, let message else {
                throw APIError.invalidResponse
            }
            return .pendingConfirmation(
                turnID: turn_id,
                confirmationID: confirmation_id,
                message: message
            )
        }
        guard let response else { throw APIError.invalidResponse }
        return .reply(response)
    }
}

final class APIService {
    static let shared = APIService()
    private init() {}

    func sendMessage(
        _ message: String,
        agent: AgentProfile = Configuration.currentAgent,
        userID: String = "ios_user"
    ) async throws -> ChatOutcome {
        let body = ChatRequestBody(
            message: message,
            user_id: userID,
            agent: agent.rawValue
        )
        return try await post(path: "/api/chat", body: body, agent: agent)
    }

    /// Answer a pending confirmation and resume its turn. A 404 means the turn
    /// is unknown or already expired (the server auto-denies after ~30s).
    func confirm(
        turnID: String,
        confirmationID: Int,
        approved: Bool,
        agent: AgentProfile = Configuration.currentAgent
    ) async throws -> ChatOutcome {
        let body = ConfirmRequestBody(
            turn_id: turnID,
            confirmation_id: confirmationID,
            approved: approved
        )
        return try await post(path: "/api/chat/confirm", body: body, agent: agent)
    }

    /// Register the APNs device token with a gated backend (open-bbum #57).
    /// The reply is `{ok:true}` — no chat body to decode, just check the status.
    func registerPushToken(
        _ token: String,
        agent: AgentProfile
    ) async throws {
        struct Body: Encodable { let device_token: String }
        _ = try await sendRequest(
            path: "/api/push/register",
            body: Body(device_token: token),
            agent: agent
        )
    }

    private func post(
        path: String,
        body: some Encodable,
        agent: AgentProfile
    ) async throws -> ChatOutcome {
        let data = try await sendRequest(path: path, body: body, agent: agent)
        let decoded = try JSONDecoder().decode(ChatResponseBody.self, from: data)
        return try decoded.toOutcome()
    }

    /// Build + send a POST with the agent's `X-API-Key`, returning the raw response
    /// body on HTTP 200. Shared by `/api/chat`, `/api/chat/confirm`, and push register.
    private func sendRequest(
        path: String,
        body: some Encodable,
        agent: AgentProfile
    ) async throws -> Data {
        guard Configuration.isConfigured(for: agent) else {
            throw APIError.notConfigured
        }

        let baseURL = Configuration.apiBaseURL(for: agent)
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Configuration.apiKey(for: agent), forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 120
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404, path == "/api/chat/confirm" {
                throw APIError.confirmationExpired
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }

        return data
    }
}

enum APIError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case confirmationExpired

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "API not configured. Tap the gear icon to set the server URL and API key for this agent."
        case .invalidURL:
            return "Invalid server URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .serverError(let code):
            return "Server error (HTTP \(code))."
        case .confirmationExpired:
            return "This confirmation expired before it was answered."
        }
    }
}
