import SwiftUI

struct MonthCalendarEventComposerView: View {

  @ObservedObject var composer: MonthCalendarEventComposer
  let onCancel: () -> Void
  let onSaved: () -> Void
  let onDeleted: () -> Void

  private let config = Config.shared.builtinCalendar.month.popup

  /// Renders the standalone appointment composer.
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      headerView
      messageView
      titleFieldView
      dateAndTimeView
      calendarPickerView
      locationFieldView
      alertPickerView
      travelTimePickerView
      footerView
    }
    .frame(width: 360, alignment: .leading)
    .padding(.horizontal, CGFloat(config.paddingX))
    .padding(.vertical, CGFloat(config.paddingY))
    .background(color(config.backgroundColorHex))
    .overlay {
      RoundedRectangle(cornerRadius: CGFloat(config.cornerRadius))
        .stroke(
          color(config.borderColorHex),
          lineWidth: CGFloat(config.borderWidth)
        )
    }
    .clipShape(
      RoundedRectangle(cornerRadius: CGFloat(config.cornerRadius))
    )
  }
}

// MARK: - Sections

extension MonthCalendarEventComposerView {
  /// Builds the composer header.
  private var headerView: some View {
    Text(composer.panelTitle)
      .foregroundStyle(color(config.headerTextColorHex))
  }

  /// Builds the optional status or error message area.
  @ViewBuilder
  private var messageView: some View {
    if let errorMessage = composer.errorMessage, !errorMessage.isEmpty {
      Text(errorMessage)
        .foregroundStyle(.red)
    } else if let infoMessage = composer.infoMessage, !infoMessage.isEmpty {
      Text(infoMessage)
        .foregroundStyle(color(config.secondaryTextColorHex))
    }
  }

  /// Builds the title input field.
  private var titleFieldView: some View {
    VStack(alignment: .leading, spacing: 4) {
      fieldLabel("Title")

      TextField(config.composerTitlePlaceholder, text: $composer.title)
        .textFieldStyle(.roundedBorder)
    }
  }

  /// Builds the date and time fields.
  private var dateAndTimeView: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top, spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          fieldLabel("Date")

          DatePicker(
            "",
            selection: $composer.date,
            displayedComponents: .date
          )
          .labelsHidden()
        }

        VStack(alignment: .leading, spacing: 4) {
          fieldLabel("Time")

          if composer.isAllDay {
            Text("All day")
              .foregroundStyle(color(config.secondaryTextColorHex))
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 6)
          } else {
            HStack(spacing: 6) {
              DatePicker(
                "",
                selection: $composer.startTime,
                displayedComponents: .hourAndMinute
              )
              .labelsHidden()

              Text("to")
                .foregroundStyle(color(config.secondaryTextColorHex))

              DatePicker(
                "",
                selection: $composer.endTime,
                displayedComponents: .hourAndMinute
              )
              .labelsHidden()
            }
          }
        }
      }

      Toggle("All day", isOn: $composer.isAllDay)
        .toggleStyle(.checkbox)
        .foregroundStyle(color(config.eventTextColorHex))
    }
  }

  /// Builds the calendar picker.
  private var calendarPickerView: some View {
    VStack(alignment: .leading, spacing: 4) {
      fieldLabel("Calendar")

      Picker("", selection: $composer.selectedCalendarID) {
        ForEach(composer.calendars) { option in
          Text(option.title).tag(option.id)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// Builds the location input field.
  private var locationFieldView: some View {
    VStack(alignment: .leading, spacing: 4) {
      fieldLabel("Location")

      TextField(config.composerLocationPlaceholder, text: $composer.location)
        .textFieldStyle(.roundedBorder)
    }
  }

  /// Builds the alert picker.
  private var alertPickerView: some View {
    VStack(alignment: .leading, spacing: 4) {
      fieldLabel("Alert")

      Picker("", selection: $composer.alert) {
        ForEach(MonthCalendarEventComposer.AlertOption.allCases) { option in
          Text(option.title).tag(option)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// Builds the travel-time picker.
  private var travelTimePickerView: some View {
    VStack(alignment: .leading, spacing: 4) {
      fieldLabel("Travel time")

      Picker("", selection: $composer.travelTime) {
        ForEach(MonthCalendarEventComposer.TravelTimeOption.allCases) { option in
          Text(option.title).tag(option)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// Builds the footer action row.
  private var footerView: some View {
    HStack {
      Button("Open in Calendar") {
        composer.openCalendarApp()
      }
      .buttonStyle(.plain)
      .foregroundStyle(color(config.secondaryTextColorHex))

      if composer.canDelete {
        Button("Remove") {
          composer.delete {
            onDeleted()
          }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
      }

      Spacer()

      Button("Cancel") {
        onCancel()
      }
      .buttonStyle(.plain)
      .foregroundStyle(color(config.secondaryTextColorHex))

      Button(composer.saveButtonTitle) {
        composer.save {
          onSaved()
        }
      }
      .disabled(!composer.canSave)
    }
    .padding(.top, 4)
  }
}

// MARK: - Helpers

extension MonthCalendarEventComposerView {
  /// Builds one field label in the popup style.
  private func fieldLabel(_ value: String) -> some View {
    Text(value)
      .foregroundStyle(color(config.secondaryTextColorHex))
  }

  /// Converts one hex string into SwiftUI color.
  private func color(_ hex: String) -> Color {
    Color(hex: hex)
  }
}
