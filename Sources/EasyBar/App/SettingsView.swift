import SwiftUI

struct SettingsView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EasyBar is installed and updated with Homebrew Cask.")
                .font(.system(size: 13, weight: .medium))

            Text("Launch it from Applications or with:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("open -a EasyBar")
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)

            Text("Update it with:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("brew upgrade --cask easybar")
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)

            Text("Uninstall it with:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("brew uninstall --cask easybar")
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)

            Text("The CLI is also installed:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("easybarctl")
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(width: 360)
    }
}
