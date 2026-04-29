import XCTest

@testable import EasyBarShared

final class ProcessLoggerTests: XCTestCase {
  func testLogFieldsFormatsSimplePairs() {
    XCTAssertEqual(
      formatLogFields(
        "event", "wifi_change",
        "connected", true,
        "rssi", -51
      ),
      "event=wifi_change connected=true rssi=-51"
    )
  }

  func testLogFieldsQuotesWhitespaceAndEmptyValues() {
    XCTAssertEqual(
      formatLogFields(
        "message", "hello world",
        "empty", ""
      ),
      #"message="hello world" empty="""#
    )
  }

  func testLogFieldsEscapesSpecialCharacters() {
    XCTAssertEqual(
      formatLogFields(
        "payload", "line 1\nline\t2",
        "quote", #"say "hi""#
      ),
      #"payload="line 1\nline\t2" quote="say \"hi\"""#
    )
  }

  func testLogFieldsFormatsNilAndMissingValue() {
    XCTAssertEqual(
      formatLogFields(
        "ssid", nil,
        "orphan"
      ),
      "ssid=nil orphan=nil"
    )
  }

  func testTypedLogFieldsFormatStructuredPairs() {
    XCTAssertEqual(
      formatLogFields(
        logField("event", "startup"),
        logField("pid", 1234),
        logField("path", "/tmp/easybar.sock")
      ),
      "event=startup pid=1234 path=/tmp/easybar.sock"
    )
  }
}
