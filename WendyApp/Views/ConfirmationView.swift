import MarkdownUI
import SwiftUI

/// In-thread bubble for a gated tool-call confirmation: shows the server's
/// (possibly batched) prompt with Approve/Deny while pending, and collapses
/// to a compact status line once resolved.
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
            .padding(12)
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.5), lineWidth: 1)
            )

            Spacer(minLength: 60)
        }
    }

    private var pendingBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Confirm action", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Markdown(message.content)
                .textSelection(.enabled)

            HStack(spacing: 12) {
                Button {
                    onRespond(true)
                } label: {
                    Text("Approve")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button {
                    onRespond(false)
                } label: {
                    Text("Deny")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
    }

    private var resolvedBody: some View {
        HStack(spacing: 6) {
            Label(statusText, systemImage: statusIcon)
                .font(.subheadline)
                .foregroundStyle(statusColor)

            // First line of the prompt as a reminder of what was (auto-)answered.
            if let summary = message.content.split(separator: "\n").first {
                Text("· \(summary)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var statusText: String {
        switch resolution {
        case .approved: return "Approved"
        case .denied: return "Denied"
        case .expired: return "Expired — the action was auto-denied"
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
