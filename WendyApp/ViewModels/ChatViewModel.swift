import Foundation
import Combine
import UIKit

@MainActor
final class ChatViewModel: ObservableObject {
    private let maxStoredMessages = 30

    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false
    /// True while a confirmation bubble awaits Approve/Deny. Locks the input:
    /// the turn is suspended server-side and holds the session's serial queue,
    /// so a new message would just block behind it.
    @Published private(set) var pendingConfirmActive = false
    @Published private(set) var hasSavedChat = false

    @Published var currentAgent: AgentProfile = Configuration.currentAgent {
        didSet {
            guard oldValue != currentAgent else { return }
            switchAgent(from: oldValue)
        }
    }

    private var backgroundObserver: AnyCancellable?

    private static func saveFileURL(for agent: AgentProfile) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("last_chat_\(agent.rawValue).json")
    }

    init() {
        hasSavedChat = FileManager.default.fileExists(
            atPath: Self.saveFileURL(for: currentAgent).path
        )

        backgroundObserver = NotificationCenter.default
            .publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.saveMessages() }
            }
    }

    // MARK: - Agent switching

    private func switchAgent(from previous: AgentProfile) {
        saveMessages()
        Configuration.currentAgent = currentAgent
        messages = []
        pendingConfirmActive = false
        hasSavedChat = FileManager.default.fileExists(
            atPath: Self.saveFileURL(for: currentAgent).path
        )
    }

    // MARK: - Persistence

    func saveMessages() {
        guard !messages.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(messages)
            try data.write(to: Self.saveFileURL(for: currentAgent), options: .atomic)
            hasSavedChat = true
        } catch {
            // Best-effort
        }
    }

    func loadPreviousMessages() {
        let url = Self.saveFileURL(for: currentAgent)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            messages = try JSONDecoder().decode([ChatMessage].self, from: data)
        } catch {
            try? FileManager.default.removeItem(at: url)
        }
        hasSavedChat = false
    }

    // MARK: - Sending

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        appendMessage(userMessage)
        inputText = ""
        isLoading = true

        let agent = currentAgent
        Task { @MainActor in
            do {
                let outcome = try await APIService.shared.sendMessage(text, agent: agent)
                handleOutcome(outcome)
            } catch {
                let explanation = Self.describeError(error)
                appendMessage(ChatMessage(role: .error, content: "Something went wrong: \(explanation)"))
            }
            isLoading = false
            saveMessages()
        }
    }

    // MARK: - Gated tool-call confirmations

    /// Answer a pending confirmation bubble and resume its suspended turn.
    func respond(to message: ChatMessage, approved: Bool) {
        guard !isLoading,  // an answer is already in flight — ignore extra taps
              message.role == .confirmation,
              message.resolution == .pending,
              let turnID = message.turnID,
              let confirmationID = message.confirmationID
        else { return }

        isLoading = true
        let agent = currentAgent
        Task { @MainActor in
            do {
                let outcome = try await APIService.shared.confirm(
                    turnID: turnID,
                    confirmationID: confirmationID,
                    approved: approved,
                    agent: agent
                )
                resolve(messageID: message.id, as: approved ? .approved : .denied)
                handleOutcome(outcome)
            } catch APIError.confirmationExpired {
                resolve(messageID: message.id, as: .expired)
                pendingConfirmActive = false
            } catch {
                let explanation = Self.describeError(error)
                appendMessage(ChatMessage(role: .error, content: "Something went wrong: \(explanation)"))
                pendingConfirmActive = false
            }
            isLoading = false
            saveMessages()
        }
    }

    /// Route a chat outcome: final reply → assistant bubble (unlock); pending
    /// confirmation → confirmation bubble (lock input until answered).
    private func handleOutcome(_ outcome: ChatOutcome) {
        switch outcome {
        case .reply(let text):
            appendMessage(ChatMessage(role: .assistant, content: text))
            pendingConfirmActive = false
        case .pendingConfirmation(let turnID, let confirmationID, let message):
            appendMessage(ChatMessage(
                confirmationMessage: message,
                turnID: turnID,
                confirmationID: confirmationID
            ))
            pendingConfirmActive = true
        }
    }

    private func resolve(messageID: UUID, as resolution: ConfirmResolution) {
        guard let idx = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[idx].resolution = resolution
    }

    private func appendMessage(_ message: ChatMessage) {
        messages.append(message)
        if messages.count > maxStoredMessages {
            messages.removeFirst(messages.count - maxStoredMessages)
        }
    }

    private static func describeError(_ error: Error) -> String {
        if let api = error as? APIError {
            return api.errorDescription ?? String(describing: api)
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection."
            case .timedOut:
                return "Request timed out."
            case .cannotFindHost, .cannotConnectToHost:
                return "Can't reach the server. Check the URL in Settings."
            default:
                return urlError.localizedDescription
            }
        }
        if error is DecodingError {
            return "The server sent a response this app couldn't read."
        }
        return error.localizedDescription
    }
}
