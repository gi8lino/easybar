import Foundation

enum ConfigError: Error, LocalizedError {
    case invalidType(path: String, expected: String, actual: String)
    case invalidValue(path: String, message: String)

    var errorDescription: String? {
        switch self {
        case let .invalidType(path, expected, actual):
            return "\(path): expected \(expected), got \(actual)"
        case let .invalidValue(path, message):
            return "\(path): \(message)"
        }
    }
}
