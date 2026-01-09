import SwiftUI
import AppKit
import Core

@MainActor
public struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject var jobState: JobState
    let manager: JobManager?
    
    @State private var selectedTab: String = "転送"
    @State private var sourcePath: String = ""
    @State private var destPath: String = ""
    @State private var erasePath: String = ""
    @State private var showAdvanced: Bool = false
    @State private var showLog: Bool = false
    
    public init(jobState: JobState, manager: JobManager?) {
        _jobState = StateObject(wrappedValue: jobState)
        self.manager = manager
    }

    private var isRunning: Bool { jobState.stepStatuses.values.contains(.running) }
    private var isStartDisabled: Bool {
        // 無効化条件: 実行中 もしくは パスが空
        isRunning || sourcePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || destPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        let theme = Theme(colorScheme: colorScheme)
        HStack(spacing: 0) {
            // --- サイドバー ---
            VStack(alignment: .leading, spacing: 20) {
                SidebarItem(icon: "bolt.fill", title: "転送", isSelected: selectedTab == "転送", theme: theme) {
                    selectedTab = "転送"
                }
                SidebarItem(icon: "trash.fill", title: "消去", isSelected: selectedTab == "消去", theme: theme) {
                    selectedTab = "消去"
                }
                Spacer()
            }
            .frame(width: 220)
            .padding(.top, 40)
            .background(theme.sidebarBackground)
            
            // --- メインコンテンツ ---
            ZStack {
                theme.mainBackground
                    .ignoresSafeArea()
                
                if selectedTab == "転送" {
                    TransferView(sourcePath: $sourcePath, destPath: $destPath, jobState: jobState, manager: manager, showLog: $showLog, theme: theme)
                } else {
                    EraseView(erasePath: $erasePath, jobState: jobState, manager: manager, theme: theme)
                }
            }
            .padding(.horizontal, 40)
        }
    }
}

// --- 転送画面 ---
struct TransferView: View {
    @Binding var sourcePath: String
    @Binding var destPath: String
    @ObservedObject var jobState: JobState
    let manager: JobManager?
    @Binding var showLog: Bool
    let theme: Theme

    private var isRunning: Bool { jobState.stepStatuses.values.contains(.running) }
    private var isStartDisabled: Bool {
        isRunning || sourcePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || destPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            VStack(alignment: .leading, spacing: 8) {
                Text("今すぐ高速・安全コピー")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(theme.primaryText)
                Text("rsync による信頼性の高い差分コピーと検証を提供します。")
                    .font(.system(size: 16))
                    .foregroundColor(theme.secondaryText)
            }
            .padding(.top, 40)
            
            VStack(spacing: 24) {
                HStack(spacing: 20) {
                    PathInputView(label: "コピー元ディレクトリ", path: $sourcePath, icon: "folder", theme: theme)
                    Image(systemName: "arrow.right")
                        .foregroundColor(theme.secondaryText)
                        .font(.system(size: 20, weight: .light))
                    PathInputView(label: "コピー先ディレクトリ", path: $destPath, icon: "folder", theme: theme)
                }
            }
            .padding(32)
            .background(theme.cardBackground)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 10)

            HStack {
                Button(action: {
                    let src = URL(fileURLWithPath: sourcePath)
                    let dst = URL(fileURLWithPath: destPath)
                    Task { await manager?.start(source: src, destination: dst) }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("転送開始")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(Color(hex: "2B6BFF"))
                    .cornerRadius(12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isStartDisabled)

                if isRunning {
                    Button(action: { Task { await manager?.stop() } }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("キャンセル")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(hex: "FF453A"))
                        .cornerRadius(10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                Button(action: { showLog.toggle() }) {
                    HStack(spacing: 8) {
                        Image(systemName: showLog ? "chart.bar.fill" : "doc.text.fill")
                        Text(showLog ? "進捗表示に戻る" : "コピーログ表示")
                    }
                    .foregroundColor(theme.secondaryText)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if showLog {
                CopyLogView(log: jobState.copyLog, theme: theme)
                    .frame(maxHeight: 250)
            } else if jobState.stepStatuses.values.contains(where: { $0 != .waiting }) {
                ProgressSection(jobState: jobState, theme: theme)
            }
            
            Spacer()
        }
    }
}

// --- 消去画面 ---
struct EraseView: View {
    @Binding var erasePath: String
    @ObservedObject var jobState: JobState
    let manager: JobManager?
    let theme: Theme

    private var isRunning: Bool { jobState.stepStatuses.values.contains(.running) }
    private var isEraseDisabled: Bool {
        isRunning || erasePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            VStack(alignment: .leading, spacing: 8) {
                Text("高速・安全消去")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(theme.primaryText)
                Text("巨大なファイルやディレクトリを高速に、かつ安全に消去します。")
                    .font(.system(size: 16))
                    .foregroundColor(theme.secondaryText)
            }
            .padding(.top, 40)
            
            VStack(spacing: 24) {
                PathInputView(label: "消去対象 (ファイル/ディレクトリ)", path: $erasePath, icon: "trash", theme: theme, allowsFiles: true)
            }
            .padding(32)
            .background(theme.cardBackground)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 10)

            HStack {
                Button(action: {
                    let target = URL(fileURLWithPath: erasePath)
                    Task { await manager?.startErase(target: target) }
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("消去実行")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(Color(hex: "FF453A"))
                    .cornerRadius(12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isEraseDisabled)

                if isRunning {
                    Button(action: { Task { await manager?.stop() } }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("キャンセル")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(hex: "48484A"))
                        .cornerRadius(10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
            }
            
            if jobState.stepStatuses[.E01_confirm] != .waiting {
                EraseProgressSection(jobState: jobState, theme: theme)
            }
            
            Spacer()
        }
    }
}

// 消去用進捗表示
struct EraseProgressSection: View {
    @ObservedObject var jobState: JobState
    let theme: Theme
    @State private var isBlinking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("消去の進捗")
                .font(.headline)
                .foregroundColor(theme.primaryText)
            
            HStack(spacing: 20) {
                ForEach([StepID.E01_confirm, .E02_delete_run], id: \.self) { step in
                    let status = jobState.stepStatuses[step] ?? .waiting
                    HStack {
                        Circle()
                            .fill(statusColor(for: status))
                            .frame(width: 12, height: 12)
                            .opacity(status == .running ? (isBlinking ? 0.3 : 1.0) : 1.0)
                            .animation(status == .running ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default, value: isBlinking)
                        Text(step == .E01_confirm ? "確認" : "消去実行")
                            .font(.system(size: 14))
                            .foregroundColor(theme.primaryText)
                    }
                }
            }
            .onAppear { isBlinking = true }
        }
        .padding(24)
        .background(theme.progressBackground)
        .cornerRadius(16)
    }

    func statusColor(for status: StepRunStatus) -> Color {
        switch status {
        case .waiting: return .gray.opacity(0.3)
        case .running: return Color(hex: "FF453A")
        case .ok: return .green
        case .error: return .red
        }
    }
}

// --- コンポーネント ---

struct SidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let theme: Theme
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .background(isSelected ? Color(hex: "2B6BFF") : Color.clear)
            .foregroundColor(isSelected ? .white : theme.sidebarText)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 12)
    }
}

struct PathInputView: View {
    let label: String
    @Binding var path: String
    let icon: String
    let theme: Theme
    var allowsFiles: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(theme.primaryText)
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(theme.secondaryText)
                TextField("", text: $path)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 15))
                    .foregroundColor(theme.primaryText)
                
                Button("参照...") {
                    selectPath()
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.buttonBackground)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.fieldBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.fieldBorder, lineWidth: 1)
            )
        }
    }
    
    private func selectPath() {
        let panel = NSOpenPanel()
        panel.title = label
        panel.canChooseFiles = allowsFiles
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "選択"
        
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}

struct ProgressSection: View {
    @ObservedObject var jobState: JobState
    let theme: Theme
    @State private var isBlinking = false
    
    private var progressPercent: Double {
        guard let total = jobState.totalBytes, total > 0 else { return 0 }
        return min(100, Double(jobState.bytesDone) / Double(total) * 100)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("現在の進捗")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)
                Spacer()
                // 進捗%表示
                if let total = jobState.totalBytes, total > 0 {
                    Text(String(format: "%.1f%%", progressPercent))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "2B6BFF"))
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(StepID.allCases, id: \.self) { step in
                        let status = jobState.stepStatuses[step] ?? .waiting
                        VStack {
                            Circle()
                                .fill(statusColor(for: status))
                                .frame(width: 12, height: 12)
                                .opacity(status == .running ? (isBlinking ? 0.3 : 1.0) : 1.0)
                                .animation(status == .running ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default, value: isBlinking)
                            Text(step.rawValue.prefix(3))
                                .font(.system(size: 10))
                                .foregroundColor(theme.secondaryText)
                        }
                    }
                }
            }
            .onAppear { isBlinking = true }
            
            // プログレスバー
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "2B6BFF"))
                        .frame(width: max(0, geo.size.width * CGFloat(progressPercent / 100)), height: 12)
                        .animation(.easeInOut(duration: 0.3), value: progressPercent)
                }
            }
            .frame(height: 12)
            
            // 転送中ファイル名
            if let file = jobState.currentFile, !file.isEmpty {
                Text(file)
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(24)
        .background(theme.progressBackground)
        .cornerRadius(16)
    }
    
    func statusColor(for status: StepRunStatus) -> Color {
        switch status {
        case .waiting: return .gray.opacity(0.3)
        case .running: return Color(hex: "2B6BFF")
        case .ok: return .green
        case .error: return .red
        }
    }
}

// --- ログ表示ビュー ---
struct CopyLogView: View {
    let log: [CopyLogEntry]
    let theme: Theme
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("転送履歴 (直近100件)")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)
                Spacer()
                Text("\(log.count) 件")
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryText)
            }
            
            if log.isEmpty {
                VStack {
                    Spacer()
                    Text("転送中のファイルはありません")
                        .foregroundColor(theme.secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(log) { entry in
                                HStack(spacing: 12) {
                                    Text(dateFormatter.string(from: entry.timestamp))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(theme.secondaryText)
                                        .frame(width: 60, alignment: .leading)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.fileName)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(theme.primaryText)
                                        Text(entry.sourcePath)
                                            .font(.system(size: 10))
                                            .foregroundColor(theme.secondaryText)
                                            .lineLimit(1)
                                            .truncationMode(.head)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatBytes(entry.fileSize))
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(theme.primaryText)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                                .id(entry.id)
                                
                                Divider()
                                    .background(theme.fieldBorder.opacity(0.3))
                            }
                        }
                    }
                    .onChange(of: log.count) { _ in
                        withAnimation {
                            if let last = log.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(theme.progressBackground)
        .cornerRadius(16)
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        let gb = mb / 1024
        return String(format: "%.1f GB", gb)
    }
}

// --- Utils ---
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Theming Helpers
struct Theme {
    let primaryText: Color
    let secondaryText: Color
    let sidebarText: Color
    let sidebarBackground: Color
    let mainBackground: Color
    let cardBackground: Color
    let fieldBackground: Color
    let fieldBorder: Color
    let buttonBackground: Color
    let progressBackground: Color

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            primaryText = Color(hex: "F5F5F7")
            secondaryText = Color(hex: "D1D1D6")
            sidebarText = Color(hex: "D1D1D6")
            sidebarBackground = Color(hex: "1C1C1E")
            mainBackground = Color(hex: "2C2C2E")
            cardBackground = Color(hex: "3A3A3C")
            fieldBackground = Color(hex: "2C2C2E")
            fieldBorder = Color(hex: "48484A")
            buttonBackground = Color(hex: "48484A")
            progressBackground = Color(hex: "2C2C2E")
        } else {
            primaryText = Color(hex: "1A1C1E")
            secondaryText = Color(hex: "6D7278")
            sidebarText = Color(hex: "6D7278")
            sidebarBackground = .white
            mainBackground = Color(hex: "F8F9FB")
            cardBackground = .white
            fieldBackground = .white
            fieldBorder = Color(hex: "E9ECEF")
            buttonBackground = Color(hex: "F1F3F5")
            progressBackground = Color(hex: "EDF2FF")
        }
    }
}
