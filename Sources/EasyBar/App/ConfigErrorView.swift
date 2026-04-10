import SwiftUI

struct ConfigErrorView: View {
  let state: Config.LoadFailureState
  let configPath: String
  let onClose: () -> Void

  private var errorText: String {
    state.error.localizedDescription
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  private var title: String {
    switch state.context {
    case .initialLoad:
      return "EasyBar started with a config problem"
    case .reloadKeptPreviousConfig:
      return "EasyBar could not apply the new config"
    }
  }

  private var summary: String {
    switch state.context {
    case .initialLoad:
      return "The bar is running with fallback defaults until the config is fixed and reloaded."
    case .reloadKeptPreviousConfig:
      return
        "The previous working config is still active. Fix the file and reload config to apply the changes."
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(title, systemImage: "exclamationmark.triangle.fill")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.primary)

      Text(summary)
        .font(.system(size: 13))
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 6) {
        Text("Config file")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.secondary)

        Text(configPath)
          .font(.system(size: 12, design: .monospaced))
          .textSelection(.enabled)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("What is wrong")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.secondary)

        ScrollView {
          Text(errorText)
            .font(.system(size: 12, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
        }
        .frame(minHeight: 120, maxHeight: 220)
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.9))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
      }

      HStack {
        Spacer()
        Button("Close", action: onClose)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(18)
    .frame(width: 520)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
  }
}
