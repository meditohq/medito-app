import Flutter
import UIKit
import XCTest
import HealthKit
#if canImport(Medito_Dev)
@testable import Medito_Dev
#elseif canImport(Medito)
@testable import Medito
#else
@testable import Runner
#endif

class RunnerTests: XCTestCase {

  private let startMs: Int64 = 1_792_404_000_123
  private let endMs: Int64 = 1_792_404_600_123

  private func arguments() -> [String: Any] {
    return [
      "startEpochMs": startMs,
      "endEpochMs": endMs,
      "title": "Body Scan",
      "trackId": "track-1",
      "fileId": "file-9",
    ]
  }

  func testMindfulnessSampleIncludesSessionMetadata() throws {
    let sample = try XCTUnwrap(MindfulnessHealthWriter.makeSample(arguments: arguments()))
    XCTAssertEqual(sample.categoryType.identifier, HKCategoryTypeIdentifier.mindfulSession.rawValue)
    XCTAssertEqual(sample.value, HKCategoryValue.notApplicable.rawValue)
    XCTAssertEqual(sample.startDate.timeIntervalSince1970, Double(startMs) / 1000, accuracy: 0.001)
    XCTAssertEqual(sample.endDate.timeIntervalSince1970, Double(endMs) / 1000, accuracy: 0.001)
    let metadata = try XCTUnwrap(sample.metadata)
    XCTAssertEqual(metadata["org.meditofoundation.title"] as? String, "Body Scan")
    XCTAssertEqual(metadata["org.meditofoundation.trackId"] as? String, "track-1")
    XCTAssertEqual(metadata["org.meditofoundation.fileId"] as? String, "file-9")
    XCTAssertEqual(metadata[HKMetadataKeyWasUserEntered] as? Bool, false)
    XCTAssertEqual(metadata[HKMetadataKeySyncIdentifier] as? String, "medito-\(endMs)")
    XCTAssertEqual(metadata[HKMetadataKeySyncVersion] as? Int, 1)
  }

  func testMindfulnessSyncIdentityIsStableAcrossRetriesButDistinctForRepeats() throws {
    let first = try XCTUnwrap(MindfulnessHealthWriter.makeSample(arguments: arguments()))
    let retry = try XCTUnwrap(MindfulnessHealthWriter.makeSample(arguments: arguments()))
    XCTAssertEqual(
      first.metadata?[HKMetadataKeySyncIdentifier] as? String,
      retry.metadata?[HKMetadataKeySyncIdentifier] as? String
    )
    var repeated = arguments()
    repeated["startEpochMs"] = endMs
    repeated["endEpochMs"] = endMs + 600_000
    let repeatSample = try XCTUnwrap(MindfulnessHealthWriter.makeSample(arguments: repeated))
    XCTAssertNotEqual(
      first.metadata?[HKMetadataKeySyncIdentifier] as? String,
      repeatSample.metadata?[HKMetadataKeySyncIdentifier] as? String
    )
  }

  func testMindfulnessTitleTrimsWhitespaceAndFallsBackForLegacyCompletions() throws {
    for title in [nil, NSNull(), "", " \n "] as [Any?] {
      var args = arguments()
      args["title"] = title
      let sample = try XCTUnwrap(MindfulnessHealthWriter.makeSample(arguments: args))
      XCTAssertEqual(sample.metadata?["org.meditofoundation.title"] as? String, "Medito")
    }
    var args = arguments()
    args["title"] = "  Body Scan\n"
    let sample = try XCTUnwrap(MindfulnessHealthWriter.makeSample(arguments: args))
    XCTAssertEqual(sample.metadata?["org.meditofoundation.title"] as? String, "Body Scan")
  }

  func testMindfulnessOmitsMissingOrEmptyContentIDs() throws {
    var args = arguments()
    args["trackId"] = NSNull()
    args["fileId"] = ""
    let sample = try XCTUnwrap(MindfulnessHealthWriter.makeSample(arguments: args))
    XCTAssertNil(sample.metadata?["org.meditofoundation.trackId"])
    XCTAssertNil(sample.metadata?["org.meditofoundation.fileId"])
  }

  func testMindfulnessPreservesLocalizedTimerNamesAndSyntheticIDs() throws {
    var args = arguments()
    args["title"] = "Temporizador"
    args["trackId"] = "timer-600"
    args["fileId"] = "timer-countdown-600000"
    let sample = try XCTUnwrap(MindfulnessHealthWriter.makeSample(arguments: args))
    XCTAssertEqual(sample.metadata?["org.meditofoundation.title"] as? String, "Temporizador")
    XCTAssertEqual(sample.metadata?["org.meditofoundation.trackId"] as? String, "timer-600")
    XCTAssertEqual(sample.metadata?["org.meditofoundation.fileId"] as? String, "timer-countdown-600000")
  }

  func testMindfulnessRejectsMissingDatesOrAnInvertedInterval() {
    XCTAssertNil(MindfulnessHealthWriter.makeSample(arguments: [:]))
    var args = arguments()
    args["endEpochMs"] = startMs - 1
    XCTAssertNil(MindfulnessHealthWriter.makeSample(arguments: args))
  }

}
