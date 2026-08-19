import SwiftUI

/// A single openbbum checklist (e.g. `todo`, `shopping`) with tappable
/// checkbox rows. Instantiated once per tab.
struct ListView: View {
    let title: String
    @StateObject private var viewModel: ListViewModel

    init(title: String, listName: String) {
        self.title = title
        _viewModel = StateObject(wrappedValue: ListViewModel(listName: listName))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.items.isEmpty {
                    emptyState
                } else {
                    List(viewModel.items) { item in
                        row(for: item)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(.red)
                }
            }
        }
    }

    private func row(for item: ListItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(item.checked ? .green : .secondary)
            Text(item.text)
                .strikethrough(item.checked)
                .foregroundStyle(item.checked ? .secondary : .primary)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.toggle(item) }
    }

    private var emptyState: some View {
        // ScrollView so pull-to-refresh still works with no rows.
        ScrollView {
            VStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Nothing here")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 120)
        }
    }
}
