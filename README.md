# LyraCopyMVP

macOS向け「大容量ファイルコピー支援アプリ（MVP）」のコアロジック（Log-driven State Machine）の土台実装。

- 状態源: 追記型JSONLログ（Resume対応）
- ステップ: S01〜S07（冪等実行）
- 技術: Swift 5+, Swift Concurrency, Combine, `Process` + `rsync`

構成:
- `Sources/Core/Model/Models.swift` — ステップ/ログ/設定のデータモデル
- `Sources/Core/Logging/JSONLLogger.swift` — JSONL追記/読み出し
- `Sources/Core/Job/JobManager.swift` — ステートマシン/再開ロジック/ステップ実行
- `Sources/Core/Rsync/RsyncWrapper.swift` — rsyncコマンド構築・出力ストリーム（骨格）

今後:
- UI層（SwiftUI）を別途追加
- 進捗/エラーの詳細整備、ユニットテスト追加
