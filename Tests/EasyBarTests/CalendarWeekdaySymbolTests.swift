import Foundation
import XCTest

@testable import EasyBarCalendarConfig

final class CalendarWeekdaySymbolTests: XCTestCase {
  func testResolveMonthWeekdaySymbolsKeepsManualSymbols() {
    let manualSymbols = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    XCTAssertEqual(
      CalendarBuiltinConfig.resolveMonthWeekdaySymbols(
        format: "ddd",
        manualSymbols: manualSymbols
      ),
      manualSymbols
    )
  }

  func testResolveMonthWeekdaySymbolsUsesSystemShortSymbolsByDefault() throws {
    let formatter = systemWeekdayFormatter()
    let sundayFirstSymbols = try XCTUnwrap(
      formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols
    )

    XCTAssertEqual(
      CalendarBuiltinConfig.resolveMonthWeekdaySymbols(format: "ddd", manualSymbols: nil),
      mondayFirstSymbols(fromSundayFirstSymbols: sundayFirstSymbols)
    )
  }

  func testResolveMonthWeekdaySymbolsUsesTwoCharacterSystemShortSymbols() throws {
    let formatter = systemWeekdayFormatter()
    let sundayFirstSymbols = try XCTUnwrap(
      formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols
    )
    let expectedSymbols = mondayFirstSymbols(
      fromSundayFirstSymbols: sundayFirstSymbols.map { String($0.prefix(2)) }
    )

    XCTAssertEqual(
      CalendarBuiltinConfig.resolveMonthWeekdaySymbols(format: "dd", manualSymbols: nil),
      expectedSymbols
    )
  }

  private func systemWeekdayFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.calendar = .autoupdatingCurrent
    return formatter
  }

  private func mondayFirstSymbols(fromSundayFirstSymbols symbols: [String]) -> [String] {
    guard symbols.count == 7 else { return symbols }

    return Array(symbols[1...6]) + [symbols[0]]
  }
}
