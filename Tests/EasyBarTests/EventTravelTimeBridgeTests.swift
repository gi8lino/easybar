import Foundation
import XCTest

@testable import EasyBarCalendarCore

final class EventTravelTimeBridgeTests: XCTestCase {
  private final class TravelTimeObject: NSObject {
    @objc dynamic var travelTime: NSNumber = 0
  }

  func testUnsupportedObjectIsIgnoredWithoutUsingKVC() {
    let object = NSObject()

    XCTAssertNil(EventKitTravelTimeAdapter.read(from: object))
    XCTAssertFalse(
      EventKitTravelTimeAdapter.write(300, to: object)
    )
  }

  func testSupportedObjectStoresAndReadsPositiveTravelTime() {
    let object = TravelTimeObject()

    XCTAssertTrue(
      EventKitTravelTimeAdapter.write(600, to: object)
    )
    XCTAssertEqual(
      EventKitTravelTimeAdapter.read(from: object),
      600
    )
  }

  func testNilTravelTimeClearsSupportedObject() {
    let object = TravelTimeObject()
    object.travelTime = 600

    XCTAssertTrue(
      EventKitTravelTimeAdapter.write(nil, to: object)
    )
    XCTAssertNil(EventKitTravelTimeAdapter.read(from: object))
  }
}
