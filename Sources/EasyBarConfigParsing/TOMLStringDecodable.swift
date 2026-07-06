import Foundation

/// A string-backed enum that can be decoded from a TOML string value.
public protocol TOMLStringDecodable: RawRepresentable where RawValue == String {
  /// User-facing allowed raw values for config diagnostics.
  static var allowedValues: [String] { get }
}

extension TOMLStringDecodable
where Self: CaseIterable, AllCases: Collection, AllCases.Element == Self {
  /// Default diagnostics for case-iterable string enums.
  public static var allowedValues: [String] {
    allCases.map(\.rawValue)
  }
}
