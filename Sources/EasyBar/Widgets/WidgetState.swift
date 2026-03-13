import Foundation

struct WidgetState: Identifiable, Codable, Equatable {
    let id: String
    var icon: String
    var text: String
    var position: String
    var order: Int
    var color: String?
}
