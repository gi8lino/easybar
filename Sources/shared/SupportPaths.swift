import Foundation

/// Returns the shared support directory used by EasyBar for editor-facing assets.
public func defaultSupportDirectoryPath() -> URL {
  FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".local/share/easybar")
}

/// Returns the default Lua editor stub path installed for widget workspaces.
public func defaultWidgetEditorStubPath() -> URL {
  defaultSupportDirectoryPath()
    .appendingPathComponent("easybar_api.lua")
}
