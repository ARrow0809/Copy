import Foundation

@main
struct RunnerStandalone {
    static func main() async {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let defaultSrc = URL(fileURLWithPath: "/tmp/lyra_src")
        let defaultDst = URL(fileURLWithPath: "/tmp/lyra_dst")
        let src = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SRC"] ?? defaultSrc.path)
        let dst = URL(fileURLWithPath: ProcessInfo.processInfo.environment["DST"] ?? defaultDst.path)
        let log = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LOG"] ?? cwd.appendingPathComponent("lyra_copy.jsonl").path)

        let cfg = JobConfig(source: src, dest: dst, logFile: log)
        do {
            let jm = try JobManager(config: cfg)
            await jm.start()
            // MVP: ステップは同期的に順に進む（rsyncはダミー）。少し待機。
            try? await Task.sleep(nanoseconds: 500_000_000)
            print("LyraCopy Standalone finished: job=\(cfg.jobID)")
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
}

