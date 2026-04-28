import XCTest

@testable import EasyBarShared

final class ProcessLoggerTests: XCTestCase {
  func testLogFieldsFormatsSimplePairs() {
    XCTAssertEqual(
      logFields(
        "event", "wifi_change",
        "connected", true,
        "rssi", -51
      ),
      "event=wifi_change connected=true rssi=-51"
    )
  }

  func testLogFieldsQuotesWhitespaceAndEmptyValues() {
    XCTAssertEqual(
      logFields(
        "message", "hello world",
        "empty", ""
      ),
      #"message="hello world" empty="""#
    )
  }

  func testLogFieldsEscapesSpecialCharacters() {
    XCTAssertEqual(
      logFields(
        "payload", "line 1\nline\t2",
        "quote", #"say "hi""#
      ),
      #"payload="line 1\nline\t2" quote="say \"hi\"""#
    )
  }

  func testLogFieldsFormatsNilAndMissingValue() {
    XCTAssertEqual(
      logFields(
        "ssid", nil,
        "orphan"
      ),
      "ssid=nil orphan=nil"
    )
  }
}
