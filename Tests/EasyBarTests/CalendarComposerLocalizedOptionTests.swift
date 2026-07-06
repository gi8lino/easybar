import EasyBarCalendarPresentation
import Foundation
import XCTest

@testable import EasyBarCalendarUI

final class CalendarComposerLocalizedOptionTests: XCTestCase {
  func testAlertOptionsUseSystemLocalizedDefaultsWhenNoConfigOverrideExists() {
    let config = makeConfig()

    XCTAssertEqual(
      CalendarEventComposer.AlertOption.fiveMinutes.title(config: config),
      CalendarComposerLocalizedText.alertBefore(seconds: 5 * 60)
    )
    XCTAssertEqual(
      CalendarEventComposer.AlertOption.atTime.title(config: config),
      CalendarComposerLocalizedText.atTimeOfEvent
    )
  }

  func testTravelTimeOptionsUseSystemLocalizedDurationsWhenNoConfigOverrideExists() {
    let config = makeConfig()

    XCTAssertEqual(
      CalendarEventComposer.TravelTimeOption.ninetyMinutes.title(config: config),
      CalendarComposerLocalizedText.duration(seconds: 90 * 60)
    )
    XCTAssertEqual(
      CalendarEventComposer.TravelTimeOption.none.title(config: config),
      CalendarComposerLocalizedText.none
    )
  }

  func testConfiguredComposerOptionLabelsOverrideSystemLocalizedDefaults() {
    let config = makeConfig(
      alertLabels: ["5_minutes": "Five before"],
      travelTimeLabels: ["90_minutes": "Ninety travel"]
    )

    XCTAssertEqual(
      CalendarEventComposer.AlertOption.fiveMinutes.title(config: config), "Five before")
    XCTAssertEqual(
      CalendarEventComposer.TravelTimeOption.ninetyMinutes.title(config: config),
      "Ninety travel"
    )
  }

  private func makeConfig(
    alertLabels: [String: String] = [:],
    travelTimeLabels: [String: String] = [:]
  ) -> CalendarComposerConfig {
    CalendarComposerConfig(
      createTitle: "Create",
      editTitle: "Edit",
      saveLabel: "Save",
      updateLabel: "Update",
      removeLabel: "Remove",
      cancelLabel: "Cancel",
      deleteConfirmationTitle: "Delete?",
      deleteConfirmationMessage: "Cannot undo.",
      openCalendarLabel: "Calendar",
      titleLabel: "Title",
      titlePlaceholder: "What?",
      locationLabel: "Location",
      locationPlaceholder: "Where?",
      calendarLabel: "Calendar",
      allDayLabel: "All day",
      startLabel: "Start",
      endLabel: "End",
      travelTimeLabel: "Travel time",
      alertLabel: "Alert",
      addAlertLabel: "Add alert",
      defaultCalendarName: nil,
      defaultAlert: "1_hour",
      defaultTravelTime: "none",
      alertLabels: alertLabels,
      travelTimeLabels: travelTimeLabels,
      paddingX: 14,
      paddingY: 14,
      backgroundColorHex: "#000000",
      borderColorHex: "#111111",
      borderWidth: 1,
      cornerRadius: 10,
      headerTextColorHex: "#ffffff",
      secondaryTextColorHex: "#cccccc"
    )
  }
}
