import SwiftUI

struct SettingsView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EasyBar startup is managed by Homebrew.")
                .font(.system(size: 13, weight: .medium))

            Text("Enable automatic launch at login with:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("brew services start easybar")
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)

            Text("Disable it with:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("brew services stop easybar")
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)

            Text("You can also restart the service with:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("brew services restart easybar")
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(width: 360)
    }
}
