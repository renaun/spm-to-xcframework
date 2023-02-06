import Foundation
import ArgumentParser

struct SPMPackage {
    var path: String
    var name: String
    var libraries: [Library]

    init(_ path: String) throws {
        self.path = path
        let filepath = "\(path)/Package.swift"
        // Check if Package.swift exists
        guard FileManager.default.fileExists(atPath: filepath) else {
            throw ValidationError("No 'Package.swift' found at: [\(path)]")
        }
        do {
            var package = try String(contentsOfFile: filepath, encoding: .utf8)
            package = package.replacingOccurrences(of: "\n", with: "")
            package = package.replacingOccurrences(of: " ", with: "")
            let parts = package.components(separatedBy: "Package(name:\"")
            guard parts.count == 2,
                  var p = parts.last?.components(separatedBy: ".library(name:\""),
                  let packageName = p.removeFirst().components(separatedBy: "\"").first else {
                throw ValidationError("Couldn't find Package name")
            }
            name = packageName
            var libs = [Library]()
            for lib in p {
                let type: Library.LibraryType = lib.contains("type:.dynamic") ? .dynamic : .static
                guard let name = lib.components(separatedBy: "\"").first else { continue }
                libs.append(Library(name: name, type: type))
            }
            libraries = libs
        } catch {
            throw ValidationError("Couldn't read contents of 'Package.swift' at: [\(path)]")
        }
    }
}

struct Library {
    var name: String
    var type: LibraryType

    enum LibraryType: String {
        case `static`, dynamic
    }
}
