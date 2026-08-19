import Foundation

@MainActor
final class ListViewModel: ObservableObject {
    let listName: String

    @Published private(set) var items: [ListItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    init(listName: String) {
        self.listName = listName
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let lists = try await APIService.shared.fetchLists()
            // Missing list ⇒ empty: lists spring into being server-side on first add.
            items = lists.first { $0.name == listName }?.items ?? []
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Optimistic: flip locally, then tell the server. On failure, reload so the
    /// row snaps back to the server's truth rather than lying.
    func toggle(_ item: ListItem) {
        guard let index = items.firstIndex(of: item) else { return }
        let newChecked = !item.checked
        items[index].checked = newChecked
        Task {
            do {
                try await APIService.shared.toggleItem(
                    list: listName,
                    text: item.text,
                    checked: newChecked
                )
            } catch {
                errorMessage = error.localizedDescription
                await load()
            }
        }
    }
}
