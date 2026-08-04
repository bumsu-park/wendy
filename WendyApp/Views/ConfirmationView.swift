import MarkdownUI
import SwiftUI

/// In-thread card for a gated tool-call confirmation: humanizes the server's
/// gate reason (e.g. "calendar_create (write)" → "Create calendar event"),
/// shows Approve/Deny while pending, and collapses to a status line once
/// resolved.
struct ConfirmationView: View {
    let message: ChatMessage
    let onRespond: (Bool) -> Void

    private var resolution: ConfirmResolution { message.resolution ?? .pending }

    var body: some View {
        HStack {
            Group {
                if resolution == .pending {
                    pendingBody
                } else {
                    resolvedBody
                }
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 1)
            )

            Spacer(minLength: 40)
        }
    }

    private var pendingBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: actionIcon)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                    Text("Wendy is asking for permission")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Batch prompts carry per-call details after the first line.
            if let details = actionDetails {
                Markdown(details)
                    .markdownTextStyle { FontSize(.em(0.85)) }
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack(spacing: 12) {
                Button {
                    onRespond(true)
                } label: {
                    Label("Approve", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    onRespond(false)
                } label: {
                    Label("Deny", systemImage: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    private var resolvedBody: some View {
        HStack(spacing: 6) {
            Label(statusText, systemImage: statusIcon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(statusColor)

            Text("· \(actionTitle)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Humanizing the gate reason

    /// First line of the server message, e.g. "calendar_create (write)" or
    /// "Approve 3 calendar_create (write) actions?".
    private var firstLine: String {
        String(message.content.split(separator: "\n").first ?? "")
    }

    /// Known gated tools → friendly action names. Fallback de-snakes the tool
    /// name so unknown tools still read like words.
    private static let friendlyNames: [String: String] = [
        "calendar_create": "Create calendar event",
        "calendar_update": "Update calendar event",
        "calendar_delete": "Delete calendar event",
        "gmail_send": "Send email",
        "gmail_draft": "Draft email",
        "shell": "Run a shell command",
        "write_file": "Write a file",
        "push_phone": "Send a push notification",
    ]

    private var toolName: String? {
        // Reason format is "<tool> (<capability>)"; batches wrap it in
        // "Approve N <tool> (<capability>) actions?".
        let line = firstLine
        if let match = line.range(of: #"[a-z][a-z0-9_]*(?= \()"#, options: .regularExpression) {
            return String(line[match])
        }
        return nil
    }

    private var batchCount: Int? {
        guard firstLine.hasPrefix("Approve ") else { return nil }
        return Int(firstLine.split(separator: " ").dropFirst().first ?? "")
    }

    private var actionTitle: String {
        guard let tool = toolName else { return firstLine }
        let friendly = Self.friendlyNames[tool]
            ?? tool.replacingOccurrences(of: "_", with: " ").capitalizedFirst
        if let n = batchCount, n > 1 {
            return "\(friendly) (\(n) actions)"
        }
        return friendly
    }

    /// Lines after the first (batch arg details), if any.
    private var actionDetails: String? {
        let lines = message.content.split(separator: "\n").dropFirst()
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }

    private var actionIcon: String {
        guard let tool = toolName else { return "hand.raised" }
        if tool.hasPrefix("calendar") { return "calendar" }
        if tool.hasPrefix("gmail") || tool.contains("mail") { return "envelope" }
        if tool.contains("shell") || tool.contains("exec") { return "terminal" }
        if tool.contains("write") || tool.contains("file") { return "doc" }
        if tool.contains("push") { return "bell" }
        return "hand.raised"
    }

    // MARK: - Resolved styling

    private var statusText: String {
        switch resolution {
        case .approved: return "Approved"
        case .denied: return "Denied"
        case .expired: return "Expired"
        case .pending: return ""
        }
    }

    private var statusIcon: String {
        switch resolution {
        case .approved: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .expired: return "clock.badge.xmark"
        case .pending: return ""
        }
    }

    private var statusColor: Color {
        switch resolution {
        case .approved: return .green
        case .denied: return .red
        case .expired: return .secondary
        case .pending: return .primary
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}
