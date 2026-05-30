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
    let includedCalendarIDs = Set(includedCalendarIDTokens.compactMap(normalizedToken))
    let excludedCalendarIDs = Set(excludedCalendarIDTokens.compactMap(normalizedToken))
    let includedSourceIDs = Set(includedSourceIDTokens.compactMap(normalizedToken))
    let excludedSourceIDs = Set(excludedSourceIDTokens.compactMap(normalizedToken))

    let title = normalizedToken(target.title)
    let calendarID = normalizedToken(target.identifier ?? "")
    let sourceID = normalizedToken(target.sourceIdentifier ?? "")

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

  /// Returns whether one target passes the configured include/exclude filters.
  public static func matches(
    _ target: CalendarFilterTarget,
    includeTokens: [String],
    excludeTokens: [String]
  ) -> Bool {
    let included = Set(includeTokens.compactMap(normalizedToken))
    let excluded = Set(excludeTokens.compactMap(normalizedToken))

    if shouldRejectMissingLegacyIncludedMatch(target, included: included) {
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

    let candidates = normalizedCandidates(for: target)

    return !candidates.isDisjoint(with: filters)
  }

  /// Returns the normalized candidate tokens for one target.
  public static func normalizedCandidates(for target: CalendarFilterTarget) -> Set<String> {
    Set(
      [
        normalizedToken(target.title),
        normalizedToken(target.identifier ?? ""),
        normalizedToken(target.sourceIdentifier ?? ""),
      ].compactMap { $0 })
  }

  /// Returns whether one normalized candidate token matches the provided filters.
  public static func matchesToken(_ candidate: String?, filters: Set<String>) -> Bool {
    guard let candidate, !filters.isEmpty else { return false }
    return filters.contains(candidate)
  }

  /// Returns whether the target should be rejected because required include filters did not match.
  private static func shouldRejectMissingIncludedMatch(
    hasIncludedFilters: Bool,
    matchesIncluded: Bool
  ) -> Bool {
    return hasIncludedFilters && !matchesIncluded
  }

  /// Returns whether legacy include filters reject the provided target.
  private static func shouldRejectMissingLegacyIncludedMatch(
    _ target: CalendarFilterTarget,
    included: Set<String>
  ) -> Bool {
    return !included.isEmpty && !matchesAnyFilter(target, filters: included)
  }
}
