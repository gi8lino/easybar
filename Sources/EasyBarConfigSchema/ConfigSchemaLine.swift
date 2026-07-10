/// User-facing config schema metadata used by generators and typo warnings.
///
/// Keep this close to the parsed config types so default config examples,
/// configuration reference docs, and unknown-key warnings share one source.
public enum ConfigSchemaRegistry {}

extension ConfigSchemaRegistry {
  /// One line in the generated default config file.
  public enum Line: Sendable {
    case blank
    case comment(String)
    case section(name: String, commented: Bool, prefix: String)
    case entry(key: String, value: String, description: String, commented: Bool, prefix: String)
    case optionalEntry(key: String, value: String, description: String)
  }

  static func section(
    name: String,
    commented: Bool = false,
    prefix: String = ""
  ) -> Line {
    .section(name: name, commented: commented, prefix: prefix)
  }

  static func entry(
    key: String,
    value: String,
    description: String,
    commented: Bool = false,
    prefix: String = ""
  ) -> Line {
    .entry(
      key: key,
      value: value,
      description: description,
      commented: commented,
      prefix: prefix
    )
  }

  static func optionalEntry(
    key: String,
    value: String,
    description: String
  ) -> Line {
    .optionalEntry(
      key: key,
      value: value,
      description: description
    )
  }
}
