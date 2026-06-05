import Foundation

extension CalendarBuiltinConfig {
  public struct Upcoming {
    public struct Events {
      public var days: Int
      public var excludePastEvents: Bool

      public init(days: Int, excludePastEvents: Bool) {
        self.days = days
        self.excludePastEvents = excludePastEvents
      }
    }

    public struct Popup {
      public var backgroundColorHex: String
      public var borderColorHex: String
      public var borderWidth: Double
      public var cornerRadius: Double
      public var paddingX: Double
      public var paddingY: Double
      public var spacing: Double
      public var marginX: Double
      public var marginY: Double

      public init(
        backgroundColorHex: String,
        borderColorHex: String,
        borderWidth: Double,
        cornerRadius: Double,
        paddingX: Double,
        paddingY: Double,
        spacing: Double,
        marginX: Double,
        marginY: Double
      ) {
        self.backgroundColorHex = backgroundColorHex
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.paddingX = paddingX
        self.paddingY = paddingY
        self.spacing = spacing
        self.marginX = marginX
        self.marginY = marginY
      }
    }

    public var events: Events
    public var popup: Popup

    public init(events: Events, popup: Popup) {
      self.events = events
      self.popup = popup
    }
  }
}
