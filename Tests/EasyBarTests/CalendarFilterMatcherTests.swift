import EasyBarShared
import XCTest

final class CalendarFilterMatcherTests: XCTestCase {
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
