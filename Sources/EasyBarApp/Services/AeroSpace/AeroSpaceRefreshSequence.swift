import Foundation

/// Identifies one AeroSpace state refresh within a service lifecycle generation.
struct AeroSpaceRefreshToken: Equatable, Sendable {
  let generation: UInt64
  let requestID: UInt64
}

/// Issues monotonically newer refresh tokens and accepts only the latest one.
struct AeroSpaceRefreshSequence: Sendable {
  private var latestRequestID: UInt64 = 0

  /// Issues a new token for the current service lifecycle generation.
  mutating func issue(generation: UInt64) -> AeroSpaceRefreshToken {
    latestRequestID &+= 1
    return AeroSpaceRefreshToken(
      generation: generation,
      requestID: latestRequestID
    )
  }

  /// Returns whether a token still represents the latest queued refresh.
  func isCurrent(_ token: AeroSpaceRefreshToken, generation: UInt64) -> Bool {
    token.generation == generation && token.requestID == latestRequestID
  }
}
