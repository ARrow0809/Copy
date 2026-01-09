import Foundation
import Combine

// --- Models ---
enum StepID: String, CaseIterable, Codable {
    case S01_validate, S02_space, S03_prepare, S04_dryrun, S05_copy, S06_verify, S07_finalize
}

struct LogLine: Codable {
    let ts: String
    let step: String
    let event: String
    let status: String?
}

// --- Manager ---
class SimpleJobManager {
    func start() async {
        print("🚀 LyraCopy MVP: Starting Job...")
        for step in StepID.allCases {
            print("⏳ [\(step.rawValue)] Running...")
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s dummy
            print("✅ [\(step.rawValue)] Done.")
        }
        print("🏁 Job Completed Successfully!")
    }
}

// --- Main ---
print("--- LyraCopy MVP Standalone Test ---")
let manager = SimpleJobManager()
let group = DispatchGroup()
group.enter()

Task {
    await manager.start()
    group.leave()
}

group.wait()
