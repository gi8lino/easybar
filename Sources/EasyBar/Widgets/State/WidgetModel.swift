import Foundation

/// Data returned from a widget script.
struct WidgetModel: Identifiable {

    var id: String
    var kind: String?

    var icon: String?
    var text: String?

    var min: Double?
    var max: Double?
    var step: Double?
    var value: Double?

    var position: String?
    var order: Int?
}
