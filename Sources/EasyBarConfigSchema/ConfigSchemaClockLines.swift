extension ConfigSchemaRegistry {
  static let clockLines: [Line] = [
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
    section(name: "builtins.time.style"),
    entry(
      key: "icon",
      value: "\"🕒\"",
      description: "Leading icon of the widget.",
    ),
    entry(
      key: "text_color",
      value: "\"theme.text\"",
      description: "Text color of the widget.",
    ),
    entry(
      key: "background_color",
      value: "\"theme.surface\"",
      description: "Background color of the widget.",
    ),
    entry(
      key: "border_color",
      value: "\"theme.border\"",
      description: "Border color of the widget.",
    ),
    entry(
      key: "border_width",
      value: "1",
      description: "Border width of the widget.",
    ),
    entry(
      key: "corner_radius",
      value: "8",
      description: "Corner radius of the widget background.",
    ),
    entry(
      key: "margin_x",
      value: "0",
      description: "Horizontal outer margin around the widget.",
    ),
    entry(
      key: "margin_y",
      value: "0",
      description: "Vertical outer margin around the widget.",
    ),
    entry(
      key: "padding_x",
      value: "8",
      description: "Horizontal inner padding of the widget.",
    ),
    entry(
      key: "padding_y",
      value: "4",
      description: "Vertical inner padding of the widget.",
    ),
    entry(
      key: "spacing",
      value: "6",
      description: "Gap between the icon and text.",
    ),
    entry(
      key: "opacity",
      value: "1.0",
      description: "Overall opacity of the widget.",
    ),
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
    section(name: "builtins.date.style"),
    entry(
      key: "icon",
      value: "\"📅\"",
      description: "Leading icon of the widget.",
    ),
    entry(
      key: "text_color",
      value: "\"theme.text\"",
      description: "Text color of the widget.",
    ),
    entry(
      key: "background_color",
      value: "\"theme.surface\"",
      description: "Background color of the widget.",
    ),
    entry(
      key: "border_color",
      value: "\"theme.border\"",
      description: "Border color of the widget.",
    ),
    entry(
      key: "border_width",
      value: "1",
      description: "Border width of the widget.",
    ),
    entry(
      key: "corner_radius",
      value: "8",
      description: "Corner radius of the widget background.",
    ),
    entry(
      key: "margin_x",
      value: "0",
      description: "Horizontal outer margin around the widget.",
    ),
    entry(
      key: "margin_y",
      value: "0",
      description: "Vertical outer margin around the widget.",
    ),
    entry(
      key: "padding_x",
      value: "8",
      description: "Horizontal inner padding of the widget.",
    ),
    entry(
      key: "padding_y",
      value: "4",
      description: "Vertical inner padding of the widget.",
    ),
    entry(
      key: "spacing",
      value: "6",
      description: "Gap between the icon and text.",
    ),
    entry(
      key: "opacity",
      value: "1.0",
      description: "Overall opacity of the widget.",
    ),
    .blank,
    section(name: "builtins.date.content"),
    entry(
      key: "format",
      value: "\"yyyy-MM-dd\"",
      description: "Date format string.",
    ),
  ]
}
