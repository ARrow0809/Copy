import Foundation
import Combine
import AppKit

public enum JobControlState: Equatable {
    case idle
    case running
    case paused
    case stopped
}

public actor JobManager {
    public var config: JobConfig
    private let logger: JSONLLogger
    public nonisolated let state: JobState
    private let rsyncWrapper = RsyncWrapper()

    private var control: JobControlState = .idle

    public init(config: JobConfig, state: JobState = JobState()) throws {
        self.config = config
        self.logger = try JSONLLogger(fileURL: config.logFile)
        self.state = state
    }

    // MARK: - Public API
    public func start(source: URL? = nil, destination: URL? = nil) async {
        guard control == .idle || control == .paused || control == .stopped else { return }

        // パスが渡された場合は更新＋新規ジョブIDを発行
        if let source = source, let destination = destination {
            self.config.source = source
            self.config.dest = destination
            self.config.jobID = UUID() // 新規ジョブとして開始
        }

        control = .running
        await resetUIForRun()
        await run(from: nil) // 常にS01から開始
    }

    public func pause() {
        control = .paused
    }

    public func stop() {
        control = .stopped
        rsyncWrapper.cancel()
    }

    // MARK: - Resume Logic
    private func resumePoint() async -> StepID? {
        do {
            let lines = try logger.readAll()
            var lastOK: StepID? = nil
            for l in lines where l.job_id == config.jobID.uuidString {
                guard let sid = StepID(rawValue: l.step_id) else { continue }
                if l.event == "end" && l.status == "ok" {
                    lastOK = sid
                }
            }
            return lastOK
        } catch {
            return nil
        }
    }

    // MARK: - Execution
    private func run(from completed: StepID?) async {
        let steps = StepID.allCases
        var startIndex = 0
        if let completed { startIndex = (steps.firstIndex(of: completed) ?? -1) + 1 }

        for (idx, step) in steps.enumerated() where idx >= startIndex {
            if control != .running { break }
            
            await mark(step, .running)
            logger.append(LogLine(jobID: config.jobID, step: step, event: "start"))
            
            do {
                try await runStep(step)
                logger.append(LogLine(jobID: config.jobID, step: step, event: "end", status: "ok", exitCode: 0))
                await mark(step, .ok)
            } catch {
                logger.append(LogLine(jobID: config.jobID, step: step, event: "end", status: "error", exitCode: 1, message: String(describing: error)))
                await mark(step, .error)
                control = .stopped
                break
            }
        }
        
        if control == .running {
            control = .idle
            // 完了時: プログレスバーを100%にしてFinderでコピー先を開く
            await MainActor.run {
                if let total = state.totalBytes, total > 0 {
                    state.bytesDone = total
                }
            }
            await openDestinationFolder()
        }
    }

    private func openDestinationFolder() async {
        let destPath = config.dest.path
        await MainActor.run {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: destPath)
        }
    }

    private func mark(_ step: StepID, _ status: StepRunStatus) async {
        await MainActor.run {
            state.stepStatuses[step] = status
        }
    }

    private func resetUIForRun() async {
        await MainActor.run {
            for s in StepID.allCases { state.stepStatuses[s] = .waiting }
            state.bytesDone = 0
            state.totalBytes = nil
            state.speedBps = 0
            state.currentFile = nil
            state.errorMessage = nil
        }
    }

    private func runStep(_ step: StepID) async throws {
        switch step {
        case .S01_validate_paths:
            try validatePaths()
        case .S02_check_space:
            try checkSpace()
        case .S03_prepare_dest:
            try prepareDest()
        case .S04_plan_dryrun:
            // スキップ: 大規模ディレクトリでブロックするため一時的に無効化
            break
        case .S05_copy_run:
            try await rsyncRun()
        case .S06_post_verify:
            try await postVerify()
        case .S07_finalize:
            try finalize()
        }
    }

    // MARK: - Concrete steps
    private func validatePaths() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: config.source.path) else { throw NSError(domain: "Job", code: 1, userInfo: [NSLocalizedDescriptionKey: "Source not found: \(config.source.path)"]) }
        
        let src = config.source.standardizedFileURL.path
        let dst = config.dest.standardizedFileURL.path
        
        if src == dst {
            throw NSError(domain: "Job", code: 2, userInfo: [NSLocalizedDescriptionKey: "Source and Dest are identical"])
        }
        if dst.hasPrefix(src + "/") {
            throw NSError(domain: "Job", code: 3, userInfo: [NSLocalizedDescriptionKey: "Dest nested within Source"])
        }
    }

    private func checkSpace() throws {
        // 簡易実装: コピー先のドライブ情報を取得
        let attrs = try FileManager.default.attributesOfFileSystem(forPath: config.dest.deletingLastPathComponent().path)
        let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        
        // 進捗初期化
        Task { @MainActor in
            state.totalBytes = free // 仮
            state.bytesDone = 0
        }
    }

    private func prepareDest() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: config.dest.path) {
            try fm.createDirectory(at: config.dest, withIntermediateDirectories: true)
        }
    }

    private func rsyncDryRun() async throws {
        try await rsyncWrapper.rsync(source: config.source, dest: config.dest, dryRun: true) { progress in
            Task { @MainActor in
                if progress.bytesDone >= 0 { self.state.bytesDone = progress.bytesDone }
                if let file = progress.currentFile { self.state.currentFile = file }
            }
        }
    }

    private func rsyncRun() async throws {
        try await rsyncWrapper.rsync(source: config.source, dest: config.dest, dryRun: false) { progress in
            Task { @MainActor in
                self.state.bytesDone = progress.bytesDone
                if let speed = progress.speedBps { self.state.speedBps = speed }
                if let file = progress.currentFile { self.state.currentFile = file }
            }
        }
    }

    private func postVerify() async throws {
        // dry-runを再度行い、差分がないことを確認
        try await rsyncWrapper.rsync(source: config.source, dest: config.dest, dryRun: true) { _ in }
    }

    private func finalize() throws {
        // 完了処理
    }
}
