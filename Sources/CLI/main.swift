import Foundation
import Core

@main
struct Runner {
    static func main() async {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let defaultSrc = "/tmp/lyra_src"
        let defaultDst = "/tmp/lyra_dst"
        let srcPath = ProcessInfo.processInfo.environment["SRC"] ?? defaultSrc
        let dstPath = ProcessInfo.processInfo.environment["DST"] ?? defaultDst
        let src = URL(fileURLWithPath: srcPath)
        let dst = URL(fileURLWithPath: dstPath)
        let log = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LOG"] ?? cwd.appendingPathComponent("lyra_copy.jsonl").path)

        // Ensure default dirs exist for quick smoke test
        let fm2 = FileManager.default
        if !fm2.fileExists(atPath: src.path) { try? fm2.createDirectory(at: src, withIntermediateDirectories: true) }
        if !fm2.fileExists(atPath: dst.path) { try? fm2.createDirectory(at: dst, withIntermediateDirectories: true) }
        let cfg = JobConfig(source: src, dest: dst, logFile: log)
        do {
            let jm = try JobManager(config: cfg)
            await jm.start()
            // 簡易待機: ステップが進むのを待つだけ（MVP）
            // 実際にはCombineで完了監視等を行う
            try? await Task.sleep(nanoseconds: 200_000_000)
            print("LyraCopyCLI finished launching job: \(cfg.jobID.uuidString)")
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
}
