import EasyBarShared
import Foundation

extension Config {
  /// One fully loaded config state produced off to the side before swapping live values.
  struct LoadedState {
    let snapshot: ConfigSnapshot
    let registeredDirectories: [String: RequiredDirectory]
  }

  /// Loads config from disk during app startup.
  @discardableResult
  func loadInitialState() -> (any Error)? {
    do {
      applyLoadedState(try Self.makeLoadedState())
      loadFailureState = nil
      objectWillChange.send()
      return nil
    } catch {
      loadFailureState = LoadFailureState(error: error, context: .initialLoad)
      objectWillChange.send()
      return error
    }
  }

  /// Reloads config from disk and returns one validation error when reload fails.
  @discardableResult
  func reload() -> (any Error)? {
    let fallbackSnapshot = snapshot()
    let fallbackDirectories = registeredDirectories

    do {
      applyLoadedState(try Self.makeLoadedState())
      loadFailureState = nil
      objectWillChange.send()
      return nil
    } catch {
      apply(fallbackSnapshot)
      registeredDirectories = fallbackDirectories
      loadFailureState = LoadFailureState(error: error, context: .reloadKeptPreviousConfig)
      objectWillChange.send()
      return error
    }
  }

  /// Swaps one fully loaded config state into the live store.
  private func applyLoadedState(_ state: LoadedState) {
    apply(state.snapshot)
    registeredDirectories = state.registeredDirectories
  }

  /// Builds one staged config state without mutating the live singleton.
  private static func makeLoadedState() throws -> LoadedState {
    let staged = Self.makeUnloadedConfig()
    staged.resetToDefaults()
    try staged.load()

    return LoadedState(
      snapshot: staged.snapshot(),
      registeredDirectories: staged.registeredDirectories
    )
  }
}
