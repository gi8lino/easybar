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
    var iconColor: String?
    var labelColor: String?
    var visible: Bool

    var role: String?

    var imagePath: String?
    var imageSize: Double?
    var imageCornerRadius: Double?

    var fontSize: Double?
    var iconFontSize: Double?
    var labelFontSize: Double?

    var value: Double?
    var min: Double?
    var max: Double?
    var step: Double?
    var values: [Double]?
    var lineWidth: Double?

    var paddingX: Double?
    var paddingY: Double?
    var paddingLeft: Double?
    var paddingRight: Double?
    var paddingTop: Double?
    var paddingBottom: Double?
    var spacing: Double?

    var backgroundColor: String?
    var borderColor: String?
    var borderWidth: Double?
    var cornerRadius: Double?
    var opacity: Double?

    var width: Double?
    var height: Double?
    var yOffset: Double?
}
