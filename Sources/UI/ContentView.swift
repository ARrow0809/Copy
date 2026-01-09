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
    @State private var showAdvanced: Bool = false
    
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
                    print("Button clicked: Sidebar 転送")
                    selectedTab = "転送"
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
                
                VStack(alignment: .leading, spacing: 30) {
                    // ヘッダー
                    VStack(alignment: .leading, spacing: 8) {
                        Text("今すぐ高速・安全コピー")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(theme.primaryText)
                        Text("rsync による信頼性の高い差分コピーと検証を提供します。")
                            .font(.system(size: 16))
                            .foregroundColor(theme.secondaryText)
                    }
                    .padding(.top, 40)
                    
                    // パス選択カード
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
                    
                    // 下部コントロール
                    HStack {
                        Button(action: {
                            print("Button clicked: 転送開始")
                            let src = URL(fileURLWithPath: sourcePath)
                            let dst = URL(fileURLWithPath: destPath)
                            Task {
                                if let manager = manager {
                                    await manager.start(source: src, destination: dst)
                                } else {
                                    print("JobManager is nil: start ignored")
                                }
                            }
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

                        // キャンセルボタン（実行中のみ表示）
                        if isRunning {
                            Button(action: {
                                print("Button clicked: キャンセル")
                                Task { await manager?.stop() }
                            }) {
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
                        
                        Button(action: {
                            print("Button clicked: プリセットとして保存")
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.on.doc")
                                Text("プリセットとして保存")
                            }
                            .foregroundColor(theme.secondaryText)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // 進捗状況 (実行中に表示)
                    if manager?.state.stepStatuses.values.contains(where: { $0 != .waiting }) == true || isRunning {
                        ProgressSection(jobState: jobState, theme: theme)
                    }
                    
                    Spacer()
                    
                    // 高度な設定は削除（要件により非表示）
                }
                .padding(.horizontal, 40)
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
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
                    print("Button clicked: 参照...")
                    selectFolder()
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
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = label
        panel.canChooseFiles = false
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("現在の進捗")
                .font(.headline)
                .foregroundColor(theme.primaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(StepID.allCases, id: \.self) { step in
                        VStack {
                            Circle()
                                .fill(statusColor(for: jobState.stepStatuses[step] ?? .waiting))
                                .frame(width: 10, height: 10)
                            Text(step.rawValue.prefix(3))
                                .font(.system(size: 10))
                                .foregroundColor(theme.secondaryText)
                        }
                    }
                }
            }
            
            if let total = jobState.totalBytes, total > 0 {
                ProgressView(value: Double(jobState.bytesDone), total: Double(total))
                    .tint(Color(hex: "2B6BFF"))
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
