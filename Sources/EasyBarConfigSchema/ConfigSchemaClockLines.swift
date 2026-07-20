extension ConfigSchemaRegistry {
  static let clockLines: [Line] =
    [
      section(name: "builtins.time"),
      entry(
        key: "enabled",
        value: "false",
        description: "Shows or hides the time widget.",
      ),
      entry(
        key: "position",
        value: "\"right\"",
        description: "Places the widget on the left, center, or right side of the bar.",
      ),
      entry(
        key: "order",
        value: "40",
        description: "Sort order among widgets in the same position.",
      ),
      .blank,
    ]
    + widgetStyleLines(
      sectionName: "builtins.time.style",
      icon: "\"􀐫\""
    ) + [
      .blank,
      section(name: "builtins.time.content"),
      entry(
        key: "format",
        value: "\"HH:mm\"",
        description: "Time format string.",
      ),
      .blank,
      section(name: "builtins.date"),
      entry(
        key: "enabled",
        value: "false",
        description: "Shows or hides the date widget.",
      ),
      entry(
        key: "position",
        value: "\"right\"",
        description: "Places the widget on the left, center, or right side of the bar.",
      ),
      entry(
        key: "order",
        value: "50",
        description: "Sort order among widgets in the same position.",
      ),
      .blank,
    ]
    + widgetStyleLines(
      sectionName: "builtins.date.style",
      icon: "\"􀉉\""
    ) + [
      .blank,
      section(name: "builtins.date.content"),
      entry(
        key: "format",
        value: "\"yyyy-MM-dd\"",
        description: "Date format string.",
      ),
    ]
}
