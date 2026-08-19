import Foundation

/// One checkbox line of an openbbum list. Item texts are unique within a list
/// (the server toggles by text), so the text doubles as the identity.
struct ListItem: Decodable, Equatable, Identifiable {
    let text: String
    var checked: Bool

    var id: String { text }
}

/// A named markdown checklist as served by `GET /api/lists`.
struct BBumList: Decodable {
    let name: String
    let items: [ListItem]
}

struct ListsResponse: Decodable {
    let lists: [BBumList]
}
