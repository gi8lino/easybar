import CoreGraphics

extension CalendarBuiltinConfig {
  /// Returns the preferred surface size for the configured popup mode.
  public var popupSurfaceSize: CGSize {
    switch popupMode {
    case .month:
      return CGSize(width: 560, height: 560)
    case .upcoming:
      return CGSize(width: 360, height: 520)
    case .none:
      return CGSize(width: 280, height: 96)
    }
  }
}
