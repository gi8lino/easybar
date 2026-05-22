import Foundation

/// Portable calendar identity used by shared filter matching.
public struct CalendarFilterTarget: Equatable, Sendable {
  public let title: String
  public let identifier: String?
  public let sourceTitle: String?
  public let sourceIdentifier: String?

  public init(
    title: String,
    identifier: String? = nil,
    sourceTitle: String? = nil,
    sourceIdentifier: String? = nil
  ) {
    self.title = title
    self.identifier = identifier
    self.sourceTitle = sourceTitle
    self.sourceIdentifier = sourceIdentifier
  }
}

/// Shared calendar include/exclude matching semantics.
public enum CalendarFilterMatcher {
  /// Returns whether one target passes the configured include/exclude filters.
  public static func matches(
    _ target: CalendarFilterTarget,
    includeTokens: [String],
    excludeTokens: [String]
  ) -> Bool {
    let included = Set(includeTokens.compactMap(normalizedToken))
    let excluded = Set(excludeTokens.compactMap(normalizedToken))

    if !included.isEmpty && !matchesAnyFilter(target, filters: included) {
      return false
    }

    if matchesAnyFilter(target, filters: excluded) {
      return false
    }

    return true
  }

  /// Normalizes one filter token for stable matching.
  public static func normalizedToken(_ value: String) -> String? {
    let normalized =
      value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    return normalized.isEmpty ? nil : normalized
  }

  /// Returns whether the target matches at least one normalized filter token.
  public static func matchesAnyFilter(
    _ target: CalendarFilterTarget,
    filters: Set<String>
  ) -> Bool {
    guard !filters.isEmpty else { return false }

    let candidates = Set(
      [
        normalizedToken(target.title),
        normalizedToken(target.identifier ?? ""),
        normalizedToken(target.sourceTitle ?? ""),
        normalizedToken(target.sourceIdentifier ?? ""),
      ].compactMap { $0 })

    return !candidates.isDisjoint(with: filters)
  }
}
