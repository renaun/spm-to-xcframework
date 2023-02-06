import Foundation

struct LinkedFramework {
    var path: String
    /// Find any xcframeworks in the path directory and return linking paths to the platform specific .framework
    func linking(_ platform: Platform) -> String {
        var xcframeworks = [String]()
        if path.hasSuffix(".xcframework") {
            xcframeworks.append(path)
        } else {
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: path) else { return "" }
            xcframeworks = items.filter { $0.contains(".xcframework") }
        }
        var links = [String]()
        for f in xcframeworks {
            guard var archs = try? FileManager.default.contentsOfDirectory(atPath: path + f) else { continue }
            archs = archs.filter { $0.contains("ios") }
            if platform.name == "ios", let sim = archs.first(where: { !$0.contains("simulator") }) {
                links.append("-F'\(path + f + "/" + sim)/'")
            } else if platform.name == "simulator", let v = archs.first(where: { $0.contains("simulator") }) {
                links.append("-F'\(path + f + "/" + v)/'")
            }
        }
        return links.joined(separator: " ")
    }
}
