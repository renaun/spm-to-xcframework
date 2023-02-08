import ArgumentParser
import Foundation

/// Name with camel case to get help to show "spm-
@main
struct SpmToXcframework: ParsableCommand {
    @Argument(help: "The path to the Package.swift file")
    var path: String = "./"

    @Option(name: .shortAndLong, help:"(Optional) Specific libraries to package. Default is to build all of them with -scheme <PackageName>-Package")
    var libraries: [String]?

    @Option(name: .shortAndLong, help:"(Optional) Specific bundles to package. Default is to add all *.bundle from all targets and epdencies.")
    var bundles: [String]?

    @Option(name: .shortAndLong, help:"Paths to folders with linked frameworks the package expects to find during building.")
    var frameworks = [String]()

    @Option(name: .shortAndLong, help: "The output directory defaults to ./xcframework inside the path folder.")
    var output: String?

    @Flag(help: "Just list package name and possible library targets to build")
    var list: Bool = false

    @Option(help: "Defaults to both .ios, and .simulator, other platforms not support yet.")
    var platforms: [Platform] = [.ios, .simulator]

    @Flag(name:.shortAndLong) var verbose: Bool = false
    @Flag(help: "Sets BUILD_LIBRARY_FOR_DISTRIBUTION to NO, typically you want this YES for any dynamic libraries to use in iOS applications. Defaults to YES.")
    var disableLibraryEvolution: Bool = false
    @Flag(help: "Include to generate xcframework with ObjC compability modulemap and -Swift.h files.")
    var objc: Bool = false
    @Flag var clean: Bool = false
    @Flag var keepBuildProducts: Bool = false

    func run() throws {
        var linking = [LinkedFramework]()
        for f in frameworks {
            guard FileManager.default.fileExists(atPath: f) else {
                throw ValidationError("Framework linking path doesn't exist: \(f)")
            }
            linking.append(LinkedFramework(path: f))
        }
        let fullPath = execute("echo \"$(cd \(path); pwd)\"").trimmingCharacters(in: .newlines)
        let outputPath: String
        if let output {
            outputPath = execute("echo \"$(cd \(output); pwd)\"").trimmingCharacters(in: .newlines)
            try? FileManager.default.createDirectory(atPath: outputPath, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: outputPath) {
                throw ValidationError("Invalid output directory: \(outputPath)")
            }
        } else {
            outputPath = fullPath + "/xcframeworks"
            try FileManager.default.createDirectory(atPath: outputPath, withIntermediateDirectories: true)
        }

        let spm = try SPMPackage(fullPath)
        if spm.libraries.count == 0 { throw ValidationError("No libraries found to package in \(spm.name)") }
        let allLibraries = spm.libraries.filter { $0.type == .dynamic }.map { $0.name }
        let nonDynamic = spm.libraries.filter { $0.type != .dynamic }.map { $0.name }
        if nonDynamic.count > 0 {
            log("Non dynamic library targets not support yet. Not packaging: \(nonDynamic.joined(separator: ","))")
        }

        if list {
            print("Found Package \"\(spm.name)\"")
            print("Potential xcframework dynamic libraries targets: \(allLibraries.joined(separator: ","))")
            if nonDynamic.count > 0 { print("Found static libraries targets: \(nonDynamic.joined(separator: ","))") }
            return
        }

        // Check that all the passed in libraries are valid
        if let libraries, let lib = libraries.first(where: { !allLibraries.contains($0) }) {
            throw ValidationError("Invalid library name found: \(lib), run -list to find valid library targets.")
        }

        let commandBuilder = CommandBuilder(
            scheme: spm.name + (allLibraries.count > 1 ? "-Package" : ""),
            libaries: libraries ?? allLibraries,
            path: fullPath,
            outputPath: outputPath,
            platforms: platforms,
            libraryEvolution: !disableLibraryEvolution,
            frameworks: linking,
            objc: objc,
            bundles: bundles ?? ["*"]
        )
        createxcframeworks(with: commandBuilder)
    }

    func log(_ msg: String) {
        guard verbose else { return }
        print(msg)
    }

    func createxcframeworks(with commandBuilder: CommandBuilder) {
        if clean {
            log("Cleaning Package")
            execute(commandBuilder.cleanCommand, verbose)
        }

        log("Listing Schemes")
        execute(commandBuilder.listSchemes, verbose)

        log("Remove XCFrameworks and dSYMs")
        execute(commandBuilder.cleanXCFrameworksCommand, verbose)

        for p in platforms {
            log("Building Package for \(p.sdk)")
            execute(commandBuilder.buildCommands(p), verbose)

            log("Moving package files for \(p.sdk)")
            commandBuilder.frameworkPackageUp(p).forEach {
                execute($0, verbose)
            }
        }

        log("Creating xcframeworks")
        commandBuilder.xcframeworkCommand().forEach {
            execute($0, verbose)
        }

        if !keepBuildProducts {
            log("Deleting build folders.")
            execute(commandBuilder.cleanupCommand, verbose)
        }
        log("Finished")
    }

    @discardableResult
    func execute(_ command: String, _ verbose: Bool = false) -> String {
        if verbose { print(command) }
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!

        if verbose { print(output) }
        return output
    }
}
