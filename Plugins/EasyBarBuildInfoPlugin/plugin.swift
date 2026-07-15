import Foundation
import PackagePlugin

@main
struct EasyBarBuildInfoPlugin: BuildToolPlugin {
  private static let versionFileName = "easybar-build-version"

  func createBuildCommands(
    context: PluginContext,
    target _: Target
  ) throws -> [Command] {
    let generator = try context.tool(named: "EasyBarGenerateBuildInfo")
    let versionFile = context.package.directory
      .appending(".build")
      .appending(Self.versionFileName)
    let output = context.pluginWorkDirectory.appending("BuildInfo.generated.swift")

    return [
      .buildCommand(
        displayName: "Generate EasyBar build info",
        executable: generator.path,
        arguments: [
          versionFile.string,
          output.string,
        ],
        inputFiles: Self.inputFiles(for: versionFile),
        outputFiles: [output]
      )
    ]
  }

  private static func inputFiles(for path: Path) -> [Path] {
    FileManager.default.fileExists(atPath: path.string) ? [path] : []
  }
}
