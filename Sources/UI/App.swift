import SwiftUI
import Core

@main
struct LyraCopyApp: App {
    let jobState: JobState
    let manager: JobManager?
    let initError: String?

    init() {
        let state = JobState()
        self.jobState = state
        
        let fm = FileManager.default
        let src = URL(fileURLWithPath: "/tmp/lyra_src")
        let dst = URL(fileURLWithPath: "/tmp/lyra_dst")
        let logDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".lyracopy")
        try? fm.createDirectory(at: logDir, withIntermediateDirectories: true)
        let log = logDir.appendingPathComponent("lyra_copy.jsonl")
        
        // Ensure test dirs
        try? fm.createDirectory(at: src, withIntermediateDirectories: true)
        try? fm.createDirectory(at: dst, withIntermediateDirectories: true)
        
        let cfg = JobConfig(source: src, dest: dst, logFile: log)
        do {
            let mgr = try JobManager(config: cfg, state: state)
            self.manager = mgr
            self.initError = nil
        } catch {
            self.manager = nil
            self.initError = String(describing: error)
            print("JobManager init failed: \(error)")
        }
        
        // UI側のStateにmanagerのStateを紐づける (簡易)
        if let manager = self.manager {
             // 実際にはmanager.stateをそのまま参照する
        }
    }

    var body: some Scene {
        WindowGroup {
            // managerが持っている実際のJobStateを渡す
            if let manager = manager {
                ContentView(jobState: manager.state, manager: manager)
            } else {
                VStack(spacing: 12) {
                    Text("Initialization Error")
                        .font(.title)
                    if let initError, !initError.isEmpty {
                        Text(initError)
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else {
                        Text("JobManager could not be created. Check file permissions for log path and directories.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
    }
}
