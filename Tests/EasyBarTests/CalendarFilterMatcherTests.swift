import EasyBarShared
import XCTest

final class CalendarFilterMatcherTests: XCTestCase {
  func testGenericMatchesIncludedTitleAfterNormalization() {
    let target = CalendarFilterTarget(title: "  Feriés  ")

    XCTAssertTrue(
      CalendarFilterMatcher.matches(
        target,
        includeTokens: ["feries"],
        excludeTokens: []
      )
    )
  }

  func testGenericMatchesCalendarIdentifierAndSourceIdentifier() {
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

  func testGenericExcludedFiltersWinOverIncludedFilters() {
    let target = CalendarFilterTarget(title: "Work")

    XCTAssertFalse(
      CalendarFilterMatcher.matches(
        target,
        includeTokens: ["work"],
        excludeTokens: ["work"]
      )
    )
  }

  func testGenericBlankFiltersDoNotMatchMissingOptionalFields() {
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

  func testSplitFiltersMatchVisibleCalendarTitle() {
    let target = CalendarFilterTarget(
      title: "  Feriés  ",
      identifier: "calendar-123",
      sourceTitle: "iCloud",
      sourceIdentifier: "source-456"
    )

    XCTAssertTrue(
      CalendarFilterMatcher.matches(
        target,
        includedTitleTokens: ["feries"],
        excludedTitleTokens: [],
        includedCalendarIDTokens: [],
        excludedCalendarIDTokens: [],
        includedSourceIDTokens: [],
        excludedSourceIDTokens: []
      )
    )
  }

  func testSplitFiltersDoNotUseSourceTitle() {
    let target = CalendarFilterTarget(
      title: "Work",
      identifier: "calendar-123",
      sourceTitle: "iCloud",
      sourceIdentifier: "source-456"
    )

    XCTAssertFalse(
      CalendarFilterMatcher.matches(
        target,
        includedTitleTokens: ["icloud"],
        excludedTitleTokens: [],
        includedCalendarIDTokens: [],
        excludedCalendarIDTokens: [],
        includedSourceIDTokens: [],
        excludedSourceIDTokens: []
      )
    )
  }

  func testSplitFiltersSupportAdvancedIdentifierSelectors() {
    let target = CalendarFilterTarget(
      title: "Work",
      identifier: "calendar-123",
      sourceTitle: "iCloud",
      sourceIdentifier: "source-456"
    )

    XCTAssertTrue(
      CalendarFilterMatcher.matches(
        target,
        includedTitleTokens: [],
        excludedTitleTokens: [],
        includedCalendarIDTokens: ["calendar-123"],
        excludedCalendarIDTokens: [],
        includedSourceIDTokens: [],
        excludedSourceIDTokens: []
      )
    )
    XCTAssertTrue(
      CalendarFilterMatcher.matches(
        target,
        includedTitleTokens: [],
        excludedTitleTokens: [],
        includedCalendarIDTokens: [],
        excludedCalendarIDTokens: [],
        includedSourceIDTokens: ["source-456"],
        excludedSourceIDTokens: []
      )
    )
  }

  func testSplitExcludesOverrideIncludedSelectorsAcrossFields() {
    let target = CalendarFilterTarget(
      title: "Work",
      identifier: "calendar-123",
      sourceTitle: "iCloud",
      sourceIdentifier: "source-456"
    )

    XCTAssertFalse(
      CalendarFilterMatcher.matches(
        target,
        includedTitleTokens: ["work"],
        excludedTitleTokens: [],
        includedCalendarIDTokens: [],
        excludedCalendarIDTokens: ["calendar-123"],
        includedSourceIDTokens: [],
        excludedSourceIDTokens: []
      )
    )
  }
}
