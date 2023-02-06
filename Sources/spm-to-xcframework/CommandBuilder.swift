import Foundation

struct CommandBuilder {
    let scheme: String
    let libaries: [String]
    let path: String
    let outputPath: String
    let platforms: [Platform]
    let libraryEvolution: Bool
    let frameworks: [LinkedFramework]
}

extension CommandBuilder {
    private var baseCommand: String {
        "xcodebuild -workspace \(path) -scheme \(scheme)"
    }

    private var buildDirCommand: String { "BUILD_DIR='\(outputPath)'" }
    private var xcframeworkPath: String { "\(outputPath)" }

    var cleanCommand: String {
        "\(baseCommand) clean \(platforms.map(\.destination).joined(separator: " "))"
    }

    var clearOutput: String {
        "rm -rf '\(outputPath)'"
    }

    var listSchemes: String { "\(baseCommand) -list -derivedDataPath '\(outputPath)/DerivedData'" }

    var buildCommands: [String] {

        return platforms.map { platform -> String in
            let linking = frameworks.map { $0.linking(platform)}
            return """
            \(baseCommand) \
            archive -archivePath \(outputPath)/\(platform.name) \
            -derivedDataPath '\(outputPath)/DerivedData' \
            \(buildDirCommand) \
            \(platform.destination) \
            -configuration Release \
            SKIP_INSTALL=NO \
            BUILD_LIBRARY_FOR_DISTRIBUTION=\(libraryEvolution ? "YES" : "NO") \
            OTHER_SWIFT_FLAGS="\(linking.joined(separator: " "))" \
            OTHER_LDFLAGS="\(linking.joined(separator: " "))"
            """
        }
    }

    var frameworkPackageUp: [String] {
        var commands = [String]()

        for lib in libaries {
            for p in platforms {
                let libpath = "\(outputPath)/\(p.name).xcarchive/Products/usr/local/lib/\(lib).framework"
                commands.append("mkdir -p \(libpath)/Modules")
                commands.append("mkdir -p \(libpath)/Modules/\(lib).swiftmodule")
                commands.append("cp -R '\(outputPath)/Release-\(p.sdk)'/\(lib).swiftmodule/*\(p.name).swiftdoc \(libpath)/Modules/\(lib).swiftmodule/")
                commands.append("cp -R '\(outputPath)/Release-\(p.sdk)'/\(lib).swiftmodule/*\(p.name).swiftinterface \(libpath)/Modules/\(lib).swiftmodule/")
                commands.append("cp -R '\(outputPath)/Release-\(p.sdk)'/*\(lib).bundle \(libpath)")
                commands.append("cp -R '\(outputPath)/Release-\(p.sdk)/\(lib).framework.dSYM' '\(xcframeworkPath)/'")
            }
        }
        return commands
    }

    func xcframeworkCommand() -> [String] {
        var commands = [String]()

        for lib in libaries {
            let allFrameworks = platforms
                .map { p in
                    return "'\(outputPath)/\(p.name).xcarchive/Products/usr/local/lib/\(lib).framework'"
                }
                .joined(separator: " -framework ")

            commands.append("xcodebuild -create-xcframework -framework \(allFrameworks) \(libraryEvolution ? "" : "-allow-internal-distribution") -output '\(xcframeworkPath)/\(lib).xcframework'")
        }
        return commands
    }

    var cleanupCommand: String {
        let commands = platforms.map { "rm -rf '\(outputPath)/\($0.buildFolder)'" } + [ "rm -rf '\(outputPath)'/*.xcarchive"]
        return commands.joined(separator: "; ")
    }

    var openFolderCommand: String {
        "open \(outputPath)"
    }
}
