import EasyBarShared
import XCTest

final class CalendarFilterMatcherTests: XCTestCase {
  func testMatchesIncludedTitleAfterNormalization() {
    let target = CalendarFilterTarget(title: "  Feriés  ")

    XCTAssertTrue(
      CalendarFilterMatcher.matches(
        target,
        includeTokens: ["feries"],
        excludeTokens: []
      )
    )
  }

  func testMatchesCalendarIdentifierAndSourceIdentifier() {
    let target = CalendarFilterTarget(
      title: "Work",
      identifier: "calendar-123",
      sourceTitle: "iCloud",
      sourceIdentifier: "source-456"
    )

    XCTAssertTrue(
      CalendarFilterMatcher.matches(
        target,
        includeTokens: ["source-456"],
        excludeTokens: []
      )
    )
    XCTAssertFalse(
      CalendarFilterMatcher.matches(
        target,
        includeTokens: ["icloud"],
        excludeTokens: []
      )
    )
  }

  func testExcludedFiltersWinOverIncludedFilters() {
    let target = CalendarFilterTarget(title: "Work")

    XCTAssertFalse(
      CalendarFilterMatcher.matches(
        target,
        includeTokens: ["work"],
        excludeTokens: ["work"]
      )
    )
  }

  func testBlankFiltersDoNotMatchMissingOptionalFields() {
    let target = CalendarFilterTarget(title: "Work")

    XCTAssertTrue(
      CalendarFilterMatcher.matches(
        target,
        includeTokens: ["   "],
        excludeTokens: []
      )
    )
    XCTAssertTrue(
      CalendarFilterMatcher.matches(
        target,
        includeTokens: [],
        excludeTokens: ["   "]
      )
    )
  }
}
