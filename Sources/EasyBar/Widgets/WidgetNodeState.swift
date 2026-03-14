import Foundation

struct WidgetNodeState: Identifiable, Codable, Equatable {
    let id: String
    let root: String
    let kind: String
    let parent: String?
    let position: String
    let order: Int

    var icon: String
    var text: String
    var color: String?
    var visible: Bool

    var role: String?

    var value: Double?
    var min: Double?
    var max: Double?
    var step: Double?
    var values: [Double]?
    var lineWidth: Double?

    var paddingX: Double?
    var paddingY: Double?
    var spacing: Double?
    var backgroundColor: String?
    var borderColor: String?
    var borderWidth: Double?
    var cornerRadius: Double?
    var opacity: Double?
}
