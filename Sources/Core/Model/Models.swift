import Foundation
import Combine

public enum StepID: String, CaseIterable, Codable, Hashable {
    case S01_validate_paths
    case S02_check_space
    case S03_prepare_dest
    case S04_plan_dryrun
    case S05_copy_run
    case S06_post_verify
    case S07_finalize
}

public enum StepRunStatus: String, Codable {
    case waiting
    case running
    case ok
    case error
}

public struct JobConfig: Codable, Hashable {
    public var jobID: UUID
    public var source: URL
    public var dest: URL
    public var logFile: URL

    public init(jobID: UUID = UUID(), source: URL, dest: URL, logFile: URL) {
        self.jobID = jobID
        self.source = source
        self.dest = dest
        self.logFile = logFile
    }
}

public struct LogLine: Codable, Hashable {
    public var ts: String
    public var job_id: String
    public var step_id: String
    public var event: String
    public var status: String?
    public var exit_code: Int32?
    public var bytes_done: Int64?
    public var speed: Int64?
    public var message: String?

    public init(ts: Date = Date(), jobID: UUID, step: StepID, event: String, status: String? = nil, exitCode: Int32? = nil, bytesDone: Int64? = nil, speed: Int64? = nil, message: String? = nil) {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.ts = iso.string(from: ts)
        self.job_id = jobID.uuidString
        self.step_id = step.rawValue
        self.event = event
        self.status = status
        self.exit_code = exitCode
        self.bytes_done = bytesDone
        self.speed = speed
        self.message = message
    }
}

@MainActor
public final class JobState: ObservableObject {
    @Published public var stepStatuses: [StepID: StepRunStatus] = {
        var dict: [StepID: StepRunStatus] = [:]
        StepID.allCases.forEach { dict[$0] = .waiting }
        return dict
    }()

    @Published public var currentFile: String?
    @Published public var bytesDone: Int64 = 0
    @Published public var totalBytes: Int64?
    @Published public var speedBps: Int64 = 0
    @Published public var errorMessage: String?

    public nonisolated init() {}
}

