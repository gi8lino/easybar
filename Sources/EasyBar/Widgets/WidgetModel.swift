import Foundation

/// Data returned from a widget script.
struct WidgetModel: Identifiable, Decodable {

    let id: String
    let icon: String?
    let text: String
    let position: String?
    let order: Int?
    let color: String?
}
