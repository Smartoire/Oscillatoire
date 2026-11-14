import Foundation
import BrainwaveKit

/// Saves captures as JSON in Application Support, one file each, and writes CSV copies for sharing.
enum CaptureStore {
    static var directory: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("Captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func save(_ capture: Capture) throws {
        let data = try JSONEncoder().encode(capture)
        try data.write(to: url(for: capture), options: .atomic)
    }

    /// Newest first. Reads every saved capture, which is fine for a handful of recordings.
    static func loadAll() -> [Capture] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(Capture.self, from: Data(contentsOf: $0)) }
            .sorted { $0.started > $1.started }
    }

    /// Reads a capture exported from Brainwave as JSON: the wrapped export format, or a plain saved capture.
    static func importFile(_ url: URL) -> Capture? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        struct Export: Decodable { let capture: Capture }
        let iso = JSONDecoder()
        iso.dateDecodingStrategy = .iso8601
        if let export = try? iso.decode(Export.self, from: data) { return export.capture }
        return try? JSONDecoder().decode(Capture.self, from: data)
    }

    static func delete(_ capture: Capture) {
        try? FileManager.default.removeItem(at: url(for: capture))
    }

    /// Writes a CSV copy to the temporary folder, named by the capture's start time, for the share sheet.
    static func exportFile(for capture: Capture) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("Brainwave \(formatter.string(from: capture.started)).csv")
        try capture.csv().write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    /// Writes the capture as a JSON file for analysis tools and agents, named like the CSV.
    static func jsonFile(for capture: Capture) throws -> URL {
        let file = try exportFile(for: capture).deletingPathExtension().appendingPathExtension("json")
        try capture.jsonExport().write(to: file, options: .atomic)
        return file
    }

    private static func url(for capture: Capture) -> URL {
        directory.appendingPathComponent("\(capture.id.uuidString).json")
    }
}
