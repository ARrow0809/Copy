import Foundation

public protocol JSONLWritable {
    func toJSONL() throws -> String
}

extension LogLine: JSONLWritable {
    public func toJSONL() throws -> String {
        let data = try JSONEncoder().encode(self)
        guard let line = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "JSONL", code: -1, userInfo: [NSLocalizedDescriptionKey: "UTF8 encoding failed"])
        }
        return line + "\n"
    }
}

public final class JSONLLogger {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "jsonl.logger.queue", qos: .utility)
    private let handle: FileHandle

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            fm.createFile(atPath: fileURL.path, contents: nil)
        }
        self.handle = try FileHandle(forWritingTo: fileURL)
        try self.handle.seekToEnd()
    }

    deinit {
        try? handle.close()
    }

    public func append(_ line: JSONLWritable) {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let text = try line.toJSONL()
                if let data = text.data(using: .utf8) {
                    _ = try self.handle.seekToEnd()
                    self.handle.write(data)
                }
            } catch {
                // swallow in MVP; could redirect to os_log
            }
        }
    }

    public func readAll() throws -> [LogLine] {
        let data = try Data(contentsOf: fileURL)
        guard let content = String(data: data, encoding: .utf8) else { return [] }
        var results: [LogLine] = []
        results.reserveCapacity(256)
        for line in content.split(whereSeparator: { $0.isNewline }) {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            if let data = String(line).data(using: .utf8) {
                if let obj = try? JSONDecoder().decode(LogLine.self, from: data) {
                    results.append(obj)
                }
            }
        }
        return results
    }
}
