import Foundation

/// Portable calendar identity used by shared filter matching.
public struct CalendarFilterTarget: Equatable, Sendable {
  /// Human-readable calendar title.
  public let title: String
  /// Stable calendar identifier when available.
  public let identifier: String?
  /// Human-readable source title when available.
  public let sourceTitle: String?
  /// Stable source identifier when available.
  public let sourceIdentifier: String?

  /// Creates one shared calendar filter target.
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
  /// Returns whether one target passes split title, calendar-id, and source-id filters.
  public static func matches(
    _ target: CalendarFilterTarget,
    includedTitleTokens: [String],
    excludedTitleTokens: [String],
    includedCalendarIDTokens: [String],
    excludedCalendarIDTokens: [String],
    includedSourceIDTokens: [String],
    excludedSourceIDTokens: [String]
  ) -> Bool {
    let includedTitles = Set(includedTitleTokens.compactMap(normalizedToken))
    let excludedTitles = Set(excludedTitleTokens.compactMap(normalizedToken))
    let includedCalendarIDs = Set(includedCalendarIDTokens.compactMap(trimmedIdentifierToken))
    let excludedCalendarIDs = Set(excludedCalendarIDTokens.compactMap(trimmedIdentifierToken))
    let includedSourceIDs = Set(includedSourceIDTokens.compactMap(trimmedIdentifierToken))
    let excludedSourceIDs = Set(excludedSourceIDTokens.compactMap(trimmedIdentifierToken))

    let title = normalizedToken(target.title)
    let calendarID = trimmedIdentifierToken(target.identifier ?? "")
    let sourceID = trimmedIdentifierToken(target.sourceIdentifier ?? "")

    let hasIncludedFilters =
      !includedTitles.isEmpty || !includedCalendarIDs.isEmpty || !includedSourceIDs.isEmpty

    let matchesIncluded =
      matchesToken(title, filters: includedTitles)
      || matchesToken(calendarID, filters: includedCalendarIDs)
      || matchesToken(sourceID, filters: includedSourceIDs)

    if shouldRejectMissingIncludedMatch(
      hasIncludedFilters: hasIncludedFilters,
      matchesIncluded: matchesIncluded
    ) {
      return false
    }

    let matchesExcluded =
      matchesToken(title, filters: excludedTitles)
      || matchesToken(calendarID, filters: excludedCalendarIDs)
      || matchesToken(sourceID, filters: excludedSourceIDs)

    if matchesExcluded {
      return false
    }

    return true
  }

  /// Normalizes one human-readable title token for stable matching.
  public static func normalizedToken(_ value: String) -> String? {
    let normalized =
      value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    return normalized.isEmpty ? nil : normalized
  }

  /// Returns whether the target matches at least one filter token.
  ///
  /// Human-readable titles use case- and diacritic-insensitive matching. Stable
  /// calendar and source identifiers are trimmed but otherwise compared exactly.
  public static func matchesAnyFilter(
    _ target: CalendarFilterTarget,
    filters: Set<String>
  ) -> Bool {
    guard !filters.isEmpty else { return false }

    let normalizedTitleFilters = Set(filters.compactMap(normalizedToken))
    let exactIdentifierFilters = Set(filters.compactMap(trimmedIdentifierToken))

    return
      matchesToken(normalizedToken(target.title), filters: normalizedTitleFilters)
      || matchesToken(
        trimmedIdentifierToken(target.identifier ?? ""),
        filters: exactIdentifierFilters
      )
      || matchesToken(
        trimmedIdentifierToken(target.sourceIdentifier ?? ""),
        filters: exactIdentifierFilters
      )
  }

  /// Returns candidate tokens using friendly title normalization and exact identifiers.
  public static func normalizedCandidates(for target: CalendarFilterTarget) -> Set<String> {
    Set(
      [
        normalizedToken(target.title),
        trimmedIdentifierToken(target.identifier ?? ""),
        trimmedIdentifierToken(target.sourceIdentifier ?? ""),
      ].compactMap { $0 })
  }

  /// Returns whether one candidate token matches the provided filters exactly.
  public static func matchesToken(_ candidate: String?, filters: Set<String>) -> Bool {
    guard let candidate, !filters.isEmpty else { return false }
    return filters.contains(candidate)
  }

  /// Trims one stable identifier without changing its case or Unicode representation.
  private static func trimmedIdentifierToken(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  /// Returns whether the target should be rejected because required include filters did not match.
  private static func shouldRejectMissingIncludedMatch(
    hasIncludedFilters: Bool,
    matchesIncluded: Bool
  ) -> Bool {
    return hasIncludedFilters && !matchesIncluded
  }
}
