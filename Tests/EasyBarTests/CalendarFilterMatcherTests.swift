import EasyBarShared
import XCTest

final class CalendarFilterMatcherTests: XCTestCase {
  func testMatchesIncludedTitleAfterNormalization() {
    let target = CalendarFilterTarget(title: "  Feriés  ")

    XCTAssertTrue(
      CalendarFilterMatcher.matches(
        target,
        includedFilters: ["feries"],
        excludedFilters: []
      )
    )
  }

  func testMatchesCalendarIdentifierAndSourceFields() {
    let target = CalendarFilterTarget(
      title: "Work",
      identifier: "calendar-123",
      sourceTitle: "iCloud",
      sourceIdentifier: "source-456"
    )

    XCTAssertTrue(
      CalendarFilterMatcher.matches(
        target,
        includedFilters: ["source-456"],
        excludedFilters: []
      )
    )
    XCTAssertTrue(
      CalendarFilterMatcher.matches(
        target,
        includedFilters: ["icloud"],
        excludedFilters: []
      )
    )
  }

  func testExcludedFiltersWinOverIncludedFilters() {
    let target = CalendarFilterTarget(title: "Work")

    XCTAssertFalse(
      CalendarFilterMatcher.matches(
        target,
        includedFilters: ["work"],
        excludedFilters: ["work"]
      )
    )
  }

  func testBlankFiltersDoNotMatchMissingOptionalFields() {
    let target = CalendarFilterTarget(title: "Work")

    XCTAssertTrue(
      CalendarFilterMatcher.matches(
        target,
        includedFilters: ["   "],
        excludedFilters: []
      )
    )
    XCTAssertTrue(
      CalendarFilterMatcher.matches(
        target,
        includedFilters: [],
        excludedFilters: ["   "]
      )
    )
  }
}
