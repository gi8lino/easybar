import Foundation
import XCTest

@testable import EasyBarCalendarCore

final class EventTravelTimeBridgeTests: XCTestCase {
  private final class TravelTimeObject: NSObject {
    @objc dynamic var travelTime: NSNumber = 0
  }

  func testUnsupportedObjectIsIgnoredWithoutUsingKVC() {
    let object = NSObject()

    XCTAssertNil(CalendarSnapshotProvider.EventTravelTimeBridge.getSeconds(from: object))
    XCTAssertFalse(
      CalendarSnapshotProvider.EventTravelTimeBridge.setSeconds(300, on: object)
    )
  }

  func testSupportedObjectStoresAndReadsPositiveTravelTime() {
    let object = TravelTimeObject()

    XCTAssertTrue(
      CalendarSnapshotProvider.EventTravelTimeBridge.setSeconds(600, on: object)
    )
    XCTAssertEqual(
      CalendarSnapshotProvider.EventTravelTimeBridge.getSeconds(from: object),
      600
    )
  }

  func testNilTravelTimeClearsSupportedObject() {
    let object = TravelTimeObject()
    object.travelTime = 600

    XCTAssertTrue(
      CalendarSnapshotProvider.EventTravelTimeBridge.setSeconds(nil, on: object)
    )
    XCTAssertNil(CalendarSnapshotProvider.EventTravelTimeBridge.getSeconds(from: object))
  }
}
