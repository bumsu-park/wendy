import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if viewModel.hasSavedChat && viewModel.messages.isEmpty {
                                Button {
                                    viewModel.loadPreviousMessages()
                                } label: {
                                    Label("Load Previous Chat", systemImage: "clock.arrow.circlepath")
                                        .font(.subheadline)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(Color(.systemGray5))
                                        .clipShape(Capsule())
                                }
                                .padding(.bottom, 4)
                            }

                            ForEach(viewModel.messages) { msg in
                                Group {
                                    if msg.role == .confirmation {
                                        ConfirmationView(message: msg) { approved in
                                            viewModel.respond(to: msg, approved: approved)
                                        }
                                    } else {
                                        MessageBubble(message: msg)
                                    }
                                }
                                .id(msg.id)
                            }

                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .padding(12)
                                        .background(Color(.systemGray5))
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    Spacer(minLength: 60)
                                }
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("bottomAnchor")
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation { proxy.scrollTo("bottomAnchor") }
                    }
                }

                Divider()

                InputBar(
                    text: $viewModel.inputText,
                    placeholder: viewModel.pendingConfirmActive
                        ? "Awaiting confirmation..."
                        : "Message \(viewModel.currentAgent.displayName)...",
                    // A pending confirmation locks the input: the turn is
                    // suspended server-side until it's answered.
                    isLoading: viewModel.isLoading || viewModel.pendingConfirmActive,
                    onSend: { viewModel.send() }
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Menu {
                        ForEach(AgentProfile.allCases, id: \.self) { agent in
                            Button {
                                viewModel.currentAgent = agent
                            } label: {
                                if agent == viewModel.currentAgent {
                                    Label(agent.displayName, systemImage: "checkmark")
                                } else {
                                    Text(agent.displayName)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.currentAgent.displayName)
                                .font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}
