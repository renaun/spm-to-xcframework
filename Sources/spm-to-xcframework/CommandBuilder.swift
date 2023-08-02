import Foundation

struct CommandBuilder {
    let scheme: String
    let libaries: [String]
    let path: String
    let outputPath: String
    let platforms: [Platform]
    let libraryEvolution: Bool
    let frameworks: [LinkedFramework]
    let objc: Bool
    let bundles: [String]
}

extension CommandBuilder {
    private var baseCommand: String {
        "xcodebuild -workspace \(path) -scheme \(scheme)"
    }

    private var buildDirCommand: String { "BUILD_DIR='\(outputPath)'" }
    private var xcframeworkPath: String { "\(outputPath)" }

    var cleanCommand: String { "rm -rf '\(outputPath)'/*" }

    var cleanXCFrameworksCommand: String { "rm -rf '\(outputPath)'/*.xcframework; rm -rf '\(outputPath)'/*.dSYM" }

    var listSchemes: String { "\(baseCommand) -list -derivedDataPath '\(outputPath)/DerivedData'" }

    func buildCommands(_ p: Platform) -> String {
// archive -archivePath \(outputPath)/\(platform.name) \
        let linking = frameworks.map { $0.linking(p)}
        return """
        \(baseCommand) \
        archive -archivePath \(outputPath)/\(p.name) \
        -derivedDataPath '\(outputPath)/DerivedData' \
        \(buildDirCommand) \
        \(p.destination) \
        -configuration Release \
        SKIP_INSTALL=NO \
        DEFINES_MODULE=YES \
        GENERATED_MODULEMAP_DIR=\(outputPath)/SwiftModuleMap-\(p.name) \
        BUILD_LIBRARY_FOR_DISTRIBUTION=\(libraryEvolution ? "YES" : "NO") \
        OTHER_SWIFT_FLAGS="\(libraryEvolution ? "-no-verify-emitted-module-interface " : "")\(linking.joined(separator: " "))" \
        OTHER_LDFLAGS="\(linking.joined(separator: " "))"
        """
    }

    func frameworkPackageUp(_ p: Platform) -> [String] {
        var commands = [String]()

        for lib in libaries {
            let modulepath = "\(outputPath)/SwiftModuleMap-\(p.name)"
            let libpath = "\(outputPath)/\(p.name).xcarchive/Products/usr/local/lib/\(lib).framework"
            commands.append("mkdir -p \(libpath)/Modules")
            commands.append("mkdir -p \(libpath)/Modules/\(lib).swiftmodule")
            commands.append("cp -R '\(outputPath)/Release-\(p.sdk)'/\(lib).swiftmodule/*\(p.name).swiftdoc \(libpath)/Modules/\(lib).swiftmodule/")
            commands.append("cp -R '\(outputPath)/Release-\(p.sdk)'/\(lib).swiftmodule/*\(p.name).swiftinterface \(libpath)/Modules/\(lib).swiftmodule/")
            for b in bundles {
                commands.append("cp -LR '\(outputPath)/Release-\(p.sdk)'/\(b).bundle \(libpath)")
            }
            commands.append("cp -R '\(outputPath)/Release-\(p.sdk)/\(lib).framework.dSYM' '\(xcframeworkPath)/'")
            if objc {
                commands.append("mkdir -p \(libpath)/Headers")
                commands.append("cp '\(modulepath)'/\(lib)-Swift.h \(libpath)/Headers")
                commands.append("cp '\(modulepath)'/\(lib).modulemap \(libpath)/Modules")
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
        let commands = platforms.map { "rm -rf '\(outputPath)/\($0.buildFolder)'" } + [ "rm -rf '\(outputPath)'/*.xcarchive", "rm -rf '\(outputPath)/SwiftModuleMap*" ]
        return commands.joined(separator: "; ")
    }

    var openFolderCommand: String {
        "open \(outputPath)"
    }
}
