import SwiftUI

struct SettingsView: View {

    @ObservedObject private var loginItemManager = LoginItemManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Start EasyBar at login", isOn: Binding(
                get: {
                    loginItemManager.isEnabled
                },
                set: { newValue in
                    loginItemManager.setEnabled(newValue)
                }
            ))

            if let message = loginItemManager.statusMessage,
               !message.isEmpty {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            loginItemManager.refresh()
        }
    }
}
