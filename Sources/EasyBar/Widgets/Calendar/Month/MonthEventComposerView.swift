import SwiftUI

struct MonthCalendarEventComposerView: View {

  @ObservedObject var composer: MonthCalendarEventComposer
  let onCancel: () -> Void
  let onSaved: () -> Void
  let onDeleted: () -> Void

  private let config = Config.shared.builtinCalendar.month.popup

  @State private var showsDeleteConfirmation = false

  /// Renders the standalone appointment composer.
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      headerView
      messageView
      detailsSectionView
      scheduleSectionView
      alertsSectionView
      footerView
    }
    .frame(width: 388, alignment: .leading)
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .background(color(config.backgroundColorHex))
    .overlay {
      RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
        .stroke(
          color(config.borderColorHex),
          lineWidth: max(CGFloat(config.borderWidth), 1)
        )
    }
    .clipShape(
      RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
    )
    .alert("Remove appointment?", isPresented: $showsDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}

      Button("Remove", role: .destructive) {
        composer.delete {
          onDeleted()
        }
      }
    } message: {
      Text("This action cannot be undone.")
    }
  }
}

// MARK: - Sections

extension MonthCalendarEventComposerView {
  /// Builds the composer header.
  private var headerView: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center) {
        Text(composer.panelTitle)
          .font(.system(size: 24, weight: .medium))
          .foregroundStyle(color(config.headerTextColorHex))

        Spacer()

        if composer.isSaving {
          ProgressView()
            .controlSize(.small)
            .tint(color(config.headerTextColorHex))
        }
      }

      Rectangle()
        .fill(color(config.borderColorHex).opacity(0.9))
        .frame(height: 1)
    }
  }

  /// Builds the optional status or error message area.
  @ViewBuilder
  private var messageView: some View {
    if let errorMessage = composer.errorMessage, !errorMessage.isEmpty {
      Text(errorMessage)
        .font(.system(size: 12, weight: .regular))
        .foregroundStyle(.red)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.03))
        )
        .overlay {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color.red.opacity(0.35), lineWidth: 1)
        }
    } else if let infoMessage = composer.infoMessage, !infoMessage.isEmpty {
      Text(infoMessage)
        .font(.system(size: 12, weight: .regular))
        .foregroundStyle(color(config.secondaryTextColorHex))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.03))
        )
        .overlay {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(color(config.borderColorHex).opacity(0.8), lineWidth: 1)
        }
    }
  }

  /// Builds the details section.
  private var detailsSectionView: some View {
    sectionContainer {
      VStack(alignment: .leading, spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          fieldLabel("Title")

          TextField(config.composerTitlePlaceholder, text: $composer.title)
            .textFieldStyle(.roundedBorder)
        }

        VStack(alignment: .leading, spacing: 4) {
          fieldLabel("Location")

          TextField(config.composerLocationPlaceholder, text: $composer.location)
            .textFieldStyle(.roundedBorder)
        }

        VStack(alignment: .leading, spacing: 4) {
          fieldLabel("Calendar")

          Picker("", selection: $composer.selectedCalendarID) {
            ForEach(composer.calendars) { option in
              Text(option.title).tag(option.id)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(width: 170, alignment: .leading)
        }
      }
    }
  }

  /// Builds the schedule section.
  private var scheduleSectionView: some View {
    sectionContainer {
      VStack(alignment: .leading, spacing: 10) {
        allDayRowView

        scheduleRowView(
          label: config.composerStartLabel,
          date: $composer.startDate,
          time: $composer.startTime,
          showsTimePicker: !composer.isAllDay
        )

        scheduleRowView(
          label: config.composerEndLabel,
          date: $composer.endDate,
          time: $composer.endTime,
          showsTimePicker: !composer.isAllDay
        )

        VStack(alignment: .leading, spacing: 4) {
          fieldLabel("Travel time")

          alignedFieldRow {
            Picker("", selection: $composer.travelTime) {
              ForEach(MonthCalendarEventComposer.TravelTimeOption.allCases) { option in
                Text(option.title).tag(option)
              }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: menuFieldWidth, alignment: .leading)
          }
        }
      }
    }
  }

  /// Builds the all-day toggle row.
  private var allDayRowView: some View {
    HStack(alignment: .center, spacing: fieldSpacing) {
      fieldLabel(config.composerAllDayLabel)
        .frame(width: fieldLabelWidth, alignment: .leading)

      Toggle("", isOn: $composer.isAllDay)
        .toggleStyle(.checkbox)
        .labelsHidden()

      Spacer(minLength: 0)
    }
  }

  /// Builds one start or end schedule row.
  private func scheduleRowView(
    label: String,
    date: Binding<Date>,
    time: Binding<Date>,
    showsTimePicker: Bool
  ) -> some View {
    HStack(alignment: .center, spacing: fieldSpacing) {
      Text(label)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(color(config.secondaryTextColorHex))
        .frame(width: fieldLabelWidth, alignment: .leading)

      DatePicker(
        "",
        selection: date,
        displayedComponents: .date
      )
      .labelsHidden()
      .frame(width: dateFieldWidth, alignment: .leading)

      Group {
        if showsTimePicker {
          DatePicker(
            "",
            selection: time,
            displayedComponents: .hourAndMinute
          )
          .labelsHidden()
        } else {
          Color.clear
        }
      }
      .frame(width: timeFieldWidth, alignment: .leading)
    }
  }

  /// Builds the alerts section.
  private var alertsSectionView: some View {
    sectionContainer {
      VStack(alignment: .leading, spacing: 8) {
        fieldLabel("Alert")

        ForEach(composer.alertRows) { row in
          HStack(alignment: .center, spacing: 8) {
            Picker(
              "",
              selection: Binding(
                get: { row.option },
                set: { composer.setAlert($0, id: row.id) }
              )
            ) {
              ForEach(MonthCalendarEventComposer.AlertOption.allCases) { option in
                Text(option.title).tag(option)
              }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 170, alignment: .leading)

            Button {
              composer.removeAlert(id: row.id)
            } label: {
              Image(systemName: "minus.circle.fill")
                .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.white.opacity(0.75))
          }
        }

        Button {
          composer.addAlert()
        } label: {
          Label("Add alert", systemImage: "plus")
            .font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(color(config.secondaryTextColorHex))
      }
    }
  }

  /// Builds the footer action row.
  private var footerView: some View {
    VStack(spacing: 10) {
      Rectangle()
        .fill(color(config.borderColorHex).opacity(0.9))
        .frame(height: 1)

      HStack(spacing: 8) {
        Button {
          composer.openCalendarApp()
        } label: {
          Label("Calendar", systemImage: "calendar")
        }
        .buttonStyle(SecondaryFooterButtonStyle())

        if composer.canDelete {
          Button("Remove") {
            showsDeleteConfirmation = true
          }
          .buttonStyle(DangerFooterButtonStyle())
        }

        Spacer()

        Button("Cancel") {
          onCancel()
        }
        .buttonStyle(SecondaryFooterButtonStyle())

        Button(composer.saveButtonTitle) {
          composer.save {
            onSaved()
          }
        }
        .buttonStyle(PrimaryFooterButtonStyle())
        .disabled(!composer.canSave)
      }
    }
    .padding(.top, 2)
  }
}

// MARK: - Helpers

extension MonthCalendarEventComposerView {
  /// Returns the corner radius used by the panel.
  private var panelCornerRadius: CGFloat {
    max(CGFloat(config.cornerRadius), 12)
  }

  /// Builds one subtle grouped section container.
  private func sectionContainer<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    content()
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color.white.opacity(0.025))
      )
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(color(config.borderColorHex).opacity(0.8), lineWidth: 1)
      }
  }

  /// Builds one field label in the popup style.
  private func fieldLabel(_ value: String) -> some View {
    Text(value)
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(color(config.secondaryTextColorHex))
  }

  /// Aligns one schedule field below the date rows.
  private func alignedFieldRow<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    HStack(alignment: .center, spacing: fieldSpacing) {
      Color.clear
        .frame(width: fieldLabelWidth, alignment: .leading)

      content()

      Spacer(minLength: 0)
    }
  }

  /// Returns the shared label width used in the schedule section.
  private var fieldLabelWidth: CGFloat { 82 }

  /// Returns the shared spacing between schedule columns.
  private var fieldSpacing: CGFloat { 4 }

  /// Returns the date picker width used in schedule rows.
  private var dateFieldWidth: CGFloat { 142 }

  /// Returns the time picker width used in schedule rows.
  private var timeFieldWidth: CGFloat { 72 }

  /// Returns the menu width used by aligned schedule rows.
  private var menuFieldWidth: CGFloat { 170 }

  /// Converts one hex string into SwiftUI color.
  private func color(_ hex: String) -> Color {
    Color(hex: hex)
  }
}

// MARK: - Button Styles

private struct PrimaryFooterButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(.black.opacity(0.92))
      .padding(.horizontal, 18)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(Color.white.opacity(configuration.isPressed ? 0.85 : 0.96))
      )
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

private struct SecondaryFooterButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .regular))
      .foregroundStyle(Color.white.opacity(configuration.isPressed ? 0.78 : 0.9))
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(Color.white.opacity(configuration.isPressed ? 0.06 : 0.035))
      )
      .overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(Color.white.opacity(0.08), lineWidth: 1)
      }
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

private struct DangerFooterButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .regular))
      .foregroundStyle(.red.opacity(configuration.isPressed ? 0.8 : 1))
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(Color.red.opacity(configuration.isPressed ? 0.1 : 0.06))
      )
      .overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(Color.red.opacity(0.22), lineWidth: 1)
      }
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
