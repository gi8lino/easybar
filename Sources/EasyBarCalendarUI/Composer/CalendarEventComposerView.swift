import SwiftUI

/// Reusable SwiftUI calendar composer view.
public struct CalendarEventComposerView: View {
  @ObservedObject public var composer: CalendarEventComposer
  public let config: CalendarComposerConfig
  public let appointmentsStyle: CalendarAppointmentsStyle
  public let onCancel: () -> Void
  public let onSaved: () -> Void
  public let onDeleted: () -> Void
  @State private var showsDeleteConfirmation = false

  public init(
    composer: CalendarEventComposer,
    config: CalendarComposerConfig,
    appointmentsStyle: CalendarAppointmentsStyle,
    onCancel: @escaping () -> Void,
    onSaved: @escaping () -> Void,
    onDeleted: @escaping () -> Void
  ) {
    self.composer = composer
    self.config = config
    self.appointmentsStyle = appointmentsStyle
    self.onCancel = onCancel
    self.onSaved = onSaved
    self.onDeleted = onDeleted
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      headerView
      messageView
      detailsSectionView
      scheduleSectionView
      alertsSectionView
      footerView
    }
    .frame(width: 388, alignment: .leading)
    .padding(.horizontal, CGFloat(config.paddingX))
    .padding(.vertical, CGFloat(config.paddingY))
    .background(color(config.backgroundColorHex))
    .overlay {
      RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
        .stroke(color(config.borderColorHex), lineWidth: CalendarUIPrimitives.borderLineWidth(config.borderWidth))
    }
    .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
    .alert(config.deleteConfirmationTitle, isPresented: $showsDeleteConfirmation) {
      Button(config.cancelLabel, role: .cancel) {}
      Button(config.removeLabel, role: .destructive) { composer.delete { onDeleted() } }
    } message: {
      Text(config.deleteConfirmationMessage)
    }
  }

  private var headerView: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center) {
        Text(composer.panelTitle).font(.system(size: 24, weight: .medium)).foregroundStyle(
          color(config.headerTextColorHex))
        Spacer()
        if composer.isSaving { ProgressView().controlSize(.small).tint(color(config.headerTextColorHex)) }
      }
      Rectangle().fill(color(config.borderColorHex).opacity(0.9)).frame(height: 1)
    }
  }
  @ViewBuilder private var messageView: some View {
    if let errorMessage = composer.errorMessage, !errorMessage.isEmpty {
      Text(errorMessage).font(.system(size: 12, weight: .regular)).foregroundStyle(.red).padding(.horizontal, 10)
        .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading).background(
          RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.03))
        ).overlay {
          RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.red.opacity(0.35), lineWidth: 1)
        }
    } else if let infoMessage = composer.infoMessage, !infoMessage.isEmpty {
      Text(infoMessage).font(.system(size: 12, weight: .regular)).foregroundStyle(
        color(appointmentsStyle.secondaryTextColorHex)
      ).padding(.horizontal, 10).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading).background(
        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.03))
      ).overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(
          color(config.borderColorHex).opacity(0.8), lineWidth: 1)
      }
    }
  }
  private var detailsSectionView: some View {
    sectionContainer {
      VStack(alignment: .leading, spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          fieldLabel(config.titleLabel)
          TextField(config.titlePlaceholder, text: $composer.title).textFieldStyle(.roundedBorder)
        }
        VStack(alignment: .leading, spacing: 4) {
          fieldLabel(config.locationLabel)
          TextField(config.locationPlaceholder, text: $composer.location).textFieldStyle(.roundedBorder)
        }
        VStack(alignment: .leading, spacing: 4) {
          fieldLabel(config.calendarLabel)
          Picker("", selection: $composer.selectedCalendarID) {
            ForEach(composer.calendars) { Text($0.title).tag($0.id) }
          }.labelsHidden().pickerStyle(.menu).frame(width: 170, alignment: .leading)
        }
      }
    }
  }
  private var scheduleSectionView: some View {
    sectionContainer {
      VStack(alignment: .leading, spacing: 10) {
        allDayRowView
        scheduleRowView(
          label: config.startLabel, date: $composer.startDate, time: $composer.startTime,
          showsTimePicker: !composer.isAllDay)
        scheduleRowView(
          label: config.endLabel, date: $composer.endDate, time: $composer.endTime, showsTimePicker: !composer.isAllDay)
        HStack(alignment: .center, spacing: fieldSpacing) {
          fieldLabel(config.travelTimeLabel).frame(width: fieldLabelWidth, alignment: .leading)
          Picker("", selection: Binding(get: { composer.travelTime }, set: { composer.setTravelTime($0) })) {
            ForEach(CalendarEventComposer.TravelTimeOption.allCases) { Text(composer.title(for: $0)).tag($0) }
          }.labelsHidden().pickerStyle(.menu).frame(width: menuFieldWidth, alignment: .leading)
          if composer.travelTime == .custom {
            customMinutesField(text: $composer.customTravelTimeMinutes, width: customFieldWidth)
          }
          Spacer(minLength: 0)
        }
      }
    }
  }
  private var allDayRowView: some View {
    HStack(alignment: .center, spacing: fieldSpacing) {
      fieldLabel(config.allDayLabel).frame(width: fieldLabelWidth, alignment: .leading)
      Toggle("", isOn: $composer.isAllDay).toggleStyle(.checkbox).labelsHidden()
      Spacer(minLength: 0)
    }
  }
  private func scheduleRowView(label: String, date: Binding<Date>, time: Binding<Date>, showsTimePicker: Bool)
    -> some View
  {
    HStack(alignment: .center, spacing: fieldSpacing) {
      Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(
        color(appointmentsStyle.secondaryTextColorHex)
      ).frame(width: fieldLabelWidth, alignment: .leading)
      DatePicker("", selection: date, displayedComponents: .date).labelsHidden().frame(
        width: dateFieldWidth, alignment: .leading)
      Group {
        if showsTimePicker {
          DatePicker("", selection: time, displayedComponents: .hourAndMinute).labelsHidden()
        } else {
          Color.clear
        }
      }.frame(width: timeFieldWidth, alignment: .leading)
    }
  }
  private var alertsSectionView: some View {
    sectionContainer {
      VStack(alignment: .leading, spacing: 8) {
        fieldLabel(config.alertLabel)
        ForEach(composer.alertRows) { row in
          HStack(alignment: .center, spacing: 8) {
            Picker("", selection: Binding(get: { row.option }, set: { composer.setAlert($0, id: row.id) })) {
              ForEach(CalendarEventComposer.AlertOption.allCases) { Text(composer.title(for: $0)).tag($0) }
            }.labelsHidden().pickerStyle(.menu).frame(width: 170, alignment: .leading)
            if row.option == .custom {
              customMinutesField(
                text: Binding(
                  get: { composer.customAlertMinutes(for: row.id) },
                  set: { composer.setCustomAlertMinutes($0, id: row.id) }), width: customFieldWidth)
            }
            Button {
              composer.removeAlert(id: row.id)
            } label: {
              Image(systemName: "minus.circle.fill").font(.system(size: 14, weight: .medium))
            }.buttonStyle(.plain).foregroundStyle(Color.white.opacity(0.75))
          }
        }
        Button {
          composer.addAlert()
        } label: {
          Label(config.addAlertLabel, systemImage: "plus").font(.system(size: 12, weight: .medium))
        }.buttonStyle(.plain).foregroundStyle(color(appointmentsStyle.secondaryTextColorHex))
      }
    }
  }
  private var footerView: some View {
    VStack(spacing: 10) {
      Rectangle().fill(color(config.borderColorHex).opacity(0.9)).frame(height: 1)
      HStack(spacing: 8) {
        Button {
          composer.openCalendarApp()
        } label: {
          Label(config.openCalendarLabel, systemImage: "calendar")
        }.buttonStyle(SecondaryFooterButtonStyle())
        if composer.canDelete {
          Button(config.removeLabel) { showsDeleteConfirmation = true }.buttonStyle(DangerFooterButtonStyle())
        }
        Spacer()
        Button(config.cancelLabel) { onCancel() }.buttonStyle(SecondaryFooterButtonStyle())
        Button(composer.saveButtonTitle) { composer.save { onSaved() } }.buttonStyle(PrimaryFooterButtonStyle())
          .disabled(!composer.canSave)
      }
    }.padding(.top, 2)
  }
  private var panelCornerRadius: CGFloat { max(CGFloat(config.cornerRadius), 12) }
  private func sectionContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content().padding(12).frame(maxWidth: .infinity, alignment: .leading).background(
      RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.025))
    ).overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(
        color(config.borderColorHex).opacity(0.8), lineWidth: 1)
    }
  }
  private func fieldLabel(_ value: String) -> some View {
    Text(value).font(.system(size: 12, weight: .medium)).foregroundStyle(color(appointmentsStyle.secondaryTextColorHex))
  }
  private var fieldLabelWidth: CGFloat { 82 }
  private var fieldSpacing: CGFloat { 4 }
  private var dateFieldWidth: CGFloat { menuFieldWidth }
  private var timeFieldWidth: CGFloat { 72 }
  private var menuFieldWidth: CGFloat { 170 }
  private var customFieldWidth: CGFloat { 76 }
  private func customMinutesField(text: Binding<String>, width: CGFloat) -> some View {
    HStack(alignment: .center, spacing: 4) {
      TextField("Min", text: text).textFieldStyle(.roundedBorder).frame(width: width, alignment: .leading)
      Text("min").font(.system(size: 11, weight: .medium)).foregroundStyle(
        color(appointmentsStyle.secondaryTextColorHex))
    }
  }
  private func color(_ hex: String) -> Color { Color(calendarHex: hex) }
}

private struct PrimaryFooterButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 13, weight: .medium)).foregroundStyle(.black.opacity(0.92)).padding(
      .horizontal, 18
    ).padding(.vertical, 8).background(
      RoundedRectangle(cornerRadius: 10, style: .continuous).fill(
        Color.white.opacity(configuration.isPressed ? 0.85 : 0.96))
    ).scaleEffect(configuration.isPressed ? 0.985 : 1).animation(
      .easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
private struct SecondaryFooterButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 13, weight: .regular)).foregroundStyle(
      Color.white.opacity(configuration.isPressed ? 0.78 : 0.9)
    ).padding(.horizontal, 14).padding(.vertical, 8).background(
      RoundedRectangle(cornerRadius: 10, style: .continuous).fill(
        Color.white.opacity(configuration.isPressed ? 0.06 : 0.035))
    ).overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1) }
      .scaleEffect(configuration.isPressed ? 0.985 : 1).animation(
        .easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
private struct DangerFooterButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 13, weight: .regular)).foregroundStyle(
      .red.opacity(configuration.isPressed ? 0.8 : 1)
    ).padding(.horizontal, 14).padding(.vertical, 8).background(
      RoundedRectangle(cornerRadius: 10, style: .continuous).fill(
        Color.red.opacity(configuration.isPressed ? 0.1 : 0.06))
    ).overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.red.opacity(0.22), lineWidth: 1) }
      .scaleEffect(configuration.isPressed ? 0.985 : 1).animation(
        .easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
