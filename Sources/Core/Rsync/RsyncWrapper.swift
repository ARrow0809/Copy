import Foundation
import Darwin

public struct RsyncProgress {
    public let bytesDone: Int64
    public let speedBps: Int64?
    public let currentFile: String?
}

public final class RsyncWrapper {
    private var process: Process?
    
    public init() {}

    public func rsync(source: URL, dest: URL, dryRun: Bool, progress: @escaping (RsyncProgress) -> Void) async throws {
        let process = Process()
        self.process = process
        
        // Homebrew版rsyncを直接指定（.appからの起動時にPATHが通らないため）
        let rsyncPath = FileManager.default.fileExists(atPath: "/usr/local/bin/rsync") 
            ? "/usr/local/bin/rsync" 
            : "/usr/bin/rsync"
        process.executableURL = URL(fileURLWithPath: rsyncPath)
        
        var args = [
            "-a",
            "--human-readable",
            "--protect-args"
        ]
        
        if dryRun {
            args += ["--dry-run", "--itemize-changes", "--out-format=%n"]
        } else {
            // 進行状況を逐次出力させるため --no-inc-recursive を追加
            args += ["--info=progress2", "--no-inc-recursive", "--partial", "--append-verify"]
        }
        
        // rsyncの仕様上、フォルダの中身をコピーするには末尾に/が必要な場合があるが、
        // ここでは指定されたパスをそのまま使用
        args.append(source.path)
        args.append(dest.path)
        
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe // エラーも同じパイプで受ける（簡易化）
        
        try process.run()
        
        let handle = pipe.fileHandleForReading
        
        // progress2 の出力をパース (例: " 1.23GB  89%  10.25MB/s  0:00:05")
        for try await line in handle.bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if let parsedProgress = parseProgress(trimmed) {
                progress(parsedProgress)
            } else {
                // 進捗行でない場合は現在処理中のファイル名として通知（dry-run中の可視化に有効）
                progress(RsyncProgress(bytesDone: -1, speedBps: nil, currentFile: trimmed))
            }
        }
        
        process.waitUntilExit()
        
        let status = process.terminationStatus
        if status != 0 && status != 24 { // 24は一部ファイル消失（コピー中に消えた等）でrsync的には許容範囲の場合あり
            throw NSError(domain: "RsyncError", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "rsync exited with code \(status)"])
        }
    }
    
    public func stop() {
        guard let p = process else { return }
        if p.isRunning { p.terminate() }
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, let p = self.process, p.isRunning else { return }
            kill(p.processIdentifier, SIGKILL)
        }
    }

    // alias for clarity
    public func cancel() { stop() }

    private func parseProgress(_ line: String) -> RsyncProgress? {
        // 簡易パース: 数字の塊を見つけてバイト数とする
        // progress2形式: " 1,234,567  89%  10.25MB/s  0:00:05"
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard components.count >= 2 else { return nil }
        
        // 最初の要素がカンマ区切りの数字（バイト数）であるケースが多い
        let bytesString = components[0].replacingOccurrences(of: ",", with: "")
        if let bytes = Int64(bytesString) {
            return RsyncProgress(bytesDone: bytes, speedBps: nil, currentFile: nil)
        }
        
        return nil
    }
}
