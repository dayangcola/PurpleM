//
//  SettingsView.swift
//  PurpleM
//
//  应用设置页面 - 包含AI模式切换等设置项
//

import SwiftUI

// AI模式枚举
enum AIMode: String, CaseIterable {
    case standard = "标准版"
    case enhanced = "增强版"
    
    var description: String {
        switch self {
        case .standard:
            return "基础对话功能，快速响应"
        case .enhanced:
            return "情绪识别、场景管理、智能记忆（测试中）"
        }
    }
    
    var icon: String {
        switch self {
        case .standard:
            return "sparkle"
        case .enhanced:
            return "sparkles"
        }
    }
}

// 设置管理器
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var aiMode: AIMode {
        didSet {
            UserDefaults.standard.set(aiMode.rawValue, forKey: "aiMode")
            // 通知AI服务切换
            NotificationCenter.default.post(name: .aiModeChanged, object: aiMode)
        }
    }
    
    @Published var enableNotifications: Bool {
        didSet {
            UserDefaults.standard.set(enableNotifications, forKey: "enableNotifications")
        }
    }
    
    @Published var enableAutoSave: Bool {
        didSet {
            UserDefaults.standard.set(enableAutoSave, forKey: "enableAutoSave")
        }
    }
    
    // 新增：流式响应设置
    @Published var enableStreaming: Bool {
        didSet {
            UserDefaults.standard.set(enableStreaming, forKey: "enableStreaming")
        }
    }
    
    // 新增：智能流式检测（根据场景自动决定）
    @Published var smartStreamingDetection: Bool {
        didSet {
            UserDefaults.standard.set(smartStreamingDetection, forKey: "smartStreamingDetection")
        }
    }
    
    private init() {
        // 加载保存的设置
        let savedMode = UserDefaults.standard.string(forKey: "aiMode") ?? AIMode.standard.rawValue
        self.aiMode = AIMode(rawValue: savedMode) ?? .standard
        
        self.enableNotifications = UserDefaults.standard.bool(forKey: "enableNotifications")
        self.enableAutoSave = UserDefaults.standard.bool(forKey: "enableAutoSave")
        
        // 流式响应默认开启
        self.enableStreaming = UserDefaults.standard.object(forKey: "enableStreaming") as? Bool ?? true
        // 智能检测默认开启
        self.smartStreamingDetection = UserDefaults.standard.object(forKey: "smartStreamingDetection") as? Bool ?? true
    }
}

// 通知名称扩展
extension Notification.Name {
    static let aiModeChanged = Notification.Name("aiModeChanged")
}

struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showAIModeInfo = false
    @State private var showBookUpload = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // AI助手设置
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "brain")
                                    .foregroundColor(.starGold)
                                Text("AI助手设置")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.crystalWhite)
                            }
                            
                            // AI模式选择
                            GlassmorphicCard {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("AI模式")
                                            .font(.system(size: 16))
                                            .foregroundColor(.crystalWhite)
                                        
                                        Spacer()
                                        
                                        Button(action: { showAIModeInfo = true }) {
                                            Image(systemName: "info.circle")
                                                .foregroundColor(.moonSilver.opacity(0.7))
                                        }
                                    }
                                    
                                    // 模式选择器
                                    ForEach(AIMode.allCases, id: \.self) { mode in
                                        Button(action: {
                                            withAnimation(.spring()) {
                                                settingsManager.aiMode = mode
                                            }
                                        }) {
                                            HStack(spacing: 12) {
                                                // 选中指示器
                                                Circle()
                                                    .stroke(Color.starGold, lineWidth: 2)
                                                    .frame(width: 20, height: 20)
                                                    .overlay(
                                                        Circle()
                                                            .fill(Color.starGold)
                                                            .frame(width: 12, height: 12)
                                                            .opacity(settingsManager.aiMode == mode ? 1 : 0)
                                                    )
                                                
                                                // 模式图标和文字
                                                Image(systemName: mode.icon)
                                                    .foregroundColor(.mysticPink)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(mode.rawValue)
                                                        .font(.system(size: 15, weight: .medium))
                                                        .foregroundColor(.crystalWhite)
                                                    
                                                    Text(mode.description)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.moonSilver.opacity(0.8))
                                                        .lineLimit(2)
                                                }
                                                
                                                Spacer()
                                                
                                                // 测试标签
                                                if mode == .enhanced {
                                                    Text("Beta")
                                                        .font(.system(size: 10, weight: .medium))
                                                        .foregroundColor(.starGold)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(
                                                            Capsule()
                                                                .fill(Color.starGold.opacity(0.2))
                                                        )
                                                }
                                            }
                                            .padding(.vertical, 8)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        if mode != AIMode.allCases.last {
                                            Divider()
                                                .background(Color.moonSilver.opacity(0.2))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // 通知设置
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "bell")
                                    .foregroundColor(.starGold)
                                Text("通知设置")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.crystalWhite)
                            }
                            
                            GlassmorphicCard {
                                Toggle(isOn: $settingsManager.enableNotifications) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("运势提醒")
                                            .font(.system(size: 16))
                                            .foregroundColor(.crystalWhite)
                                        Text("重要日期和运势变化时通知")
                                            .font(.system(size: 12))
                                            .foregroundColor(.moonSilver.opacity(0.8))
                                    }
                                }
                                .tint(.mysticPink)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 流式响应设置（新增）
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                    .foregroundColor(.starGold)
                                Text("对话体验")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.crystalWhite)
                            }
                            
                            GlassmorphicCard {
                                VStack(spacing: 15) {
                                    Toggle(isOn: $settingsManager.enableStreaming) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("流式响应")
                                                .font(.system(size: 16))
                                                .foregroundColor(.crystalWhite)
                                            Text("逐字显示AI回复，获得更流畅的对话体验")
                                                .font(.system(size: 12))
                                                .foregroundColor(.moonSilver.opacity(0.8))
                                        }
                                    }
                                    .tint(.mysticPink)
                                    
                                    if settingsManager.enableStreaming {
                                        Divider()
                                            .background(Color.moonSilver.opacity(0.2))
                                        
                                        Toggle(isOn: $settingsManager.smartStreamingDetection) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 4) {
                                                    Text("智能检测")
                                                        .font(.system(size: 16))
                                                        .foregroundColor(.crystalWhite)
                                                    
                                                    Text("推荐")
                                                        .font(.system(size: 10, weight: .medium))
                                                        .foregroundColor(.starGold)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(
                                                            Capsule()
                                                                .fill(Color.starGold.opacity(0.2))
                                                        )
                                                }
                                                Text("仅在命盘解读和运势分析时使用流式")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.moonSilver.opacity(0.8))
                                            }
                                        }
                                        .tint(.mysticPink)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // 数据管理
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "icloud")
                                    .foregroundColor(.starGold)
                                Text("数据管理")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.crystalWhite)
                            }
                            
                            GlassmorphicCard {
                                Toggle(isOn: $settingsManager.enableAutoSave) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("自动保存")
                                            .font(.system(size: 16))
                                            .foregroundColor(.crystalWhite)
                                        Text("自动保存聊天记录和星盘数据")
                                            .font(.system(size: 12))
                                            .foregroundColor(.moonSilver.opacity(0.8))
                                    }
                                }
                                .tint(.mysticPink)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 调试信息（仅测试版显示）
                        #if DEBUG
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "hammer")
                                    .foregroundColor(.starGold)
                                Text("开发者选项")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.crystalWhite)
                            }
                            
                            GlassmorphicCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("当前AI模式:")
                                        Text(settingsManager.aiMode.rawValue)
                                            .foregroundColor(.starGold)
                                    }
                                    .font(.system(size: 14))
                                    .foregroundColor(.crystalWhite)
                                    
                                    Button("清除所有缓存") {
                                        // TODO: 实现清除缓存
                                        UserDefaults.standard.removeObject(forKey: "ChatHistory")
                                    }
                                    .font(.system(size: 14))
                                    .foregroundColor(.red.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal)
                        #endif
                        
                        // 隐藏的知识库管理入口
                        VStack(alignment: .leading, spacing: 15) {
                            // 版本信息（表面上看起来很普通）
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.moonSilver.opacity(0.5))
                                Text("关于")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.crystalWhite)
                            }
                            
                            GlassmorphicCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    // 版本号（长按触发上传）
                                    HStack {
                                        Text("版本")
                                            .font(.system(size: 14))
                                            .foregroundColor(.moonSilver)
                                        Spacer()
                                        Text("1.0.0")
                                            .font(.system(size: 14))
                                            .foregroundColor(.crystalWhite)
                                    }
                                    .contentShape(Rectangle())
                                    .onLongPressGesture(minimumDuration: 2.0) {
                                        // 长按2秒触发
                                        showBookUpload = true
                                    }
                                    
                                    Divider()
                                        .background(Color.moonSilver.opacity(0.2))
                                    
                                    // 版权信息
                                    Text("© 2024 紫微星语")
                                        .font(.system(size: 12))
                                        .foregroundColor(.moonSilver.opacity(0.6))
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationBarTitle("设置", displayMode: .inline)
            .navigationBarItems(
                trailing: Button("完成") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.starGold)
            )
        }
        .sheet(isPresented: $showAIModeInfo) {
            AIModeInfoView()
        }
        .sheet(isPresented: $showBookUpload) {
            NavigationView {
                SimplePDFUploaderView()
            }
        }
    }
}

// MARK: - 隐藏的PDF上传界面
struct SimplePDFUploaderView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var showFilePicker = false
    @State private var isProcessing = false
    @State private var statusMessage = ""
    @StateObject private var uploader = KnowledgeUploader()
    
    var body: some View {
        ZStack {
            AnimatedBackground()
            
            VStack(spacing: 30) {
                Text("📚 知识库管理")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.crystalWhite)
                
                Text("（内部功能，请谨慎使用）")
                    .font(.caption)
                    .foregroundColor(.moonSilver.opacity(0.6))
                
                GlassmorphicCard {
                    VStack(spacing: 20) {
                        SimplePDFUploaderButton()
                        
                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundColor(.moonSilver)
                                .padding()
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: 400)
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitle("知识库", displayMode: .inline)
        .navigationBarItems(
            trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.starGold)
        )
    }
}

// AI模式详细说明视图
struct AIModeInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 标准版说明
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkle")
                                    .foregroundColor(.starGold)
                                Text("标准版")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.crystalWhite)
                            }
                            
                            Text("稳定可靠的基础AI助手")
                                .font(.system(size: 14))
                                .foregroundColor(.moonSilver)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                FeatureRow(icon: "checkmark.circle", text: "快速响应")
                                FeatureRow(icon: "checkmark.circle", text: "基础命理解答")
                                FeatureRow(icon: "checkmark.circle", text: "星盘分析")
                                FeatureRow(icon: "checkmark.circle", text: "运势咨询")
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                        )
                        
                        // 增强版说明
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.mysticPink)
                                Text("增强版")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.crystalWhite)
                                
                                Text("Beta")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.starGold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.starGold.opacity(0.2))
                                    )
                            }
                            
                            Text("智能化的全新AI体验")
                                .font(.system(size: 14))
                                .foregroundColor(.moonSilver)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                FeatureRow(icon: "star.circle", text: "情绪识别：理解你的心情")
                                FeatureRow(icon: "star.circle", text: "场景管理：自动切换对话模式")
                                FeatureRow(icon: "star.circle", text: "记忆系统：记住你的偏好")
                                FeatureRow(icon: "star.circle", text: "主动提醒：重要日期提醒")
                                FeatureRow(icon: "star.circle", text: "智能推荐：个性化问题建议")
                            }
                            
                            Text("⚠️ 测试版功能可能不稳定")
                                .font(.system(size: 12))
                                .foregroundColor(.orange.opacity(0.8))
                                .padding(.top, 8)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                        )
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationBarTitle("AI模式说明", displayMode: .inline)
            .navigationBarItems(
                trailing: Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.starGold)
            )
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.starGold.opacity(0.8))
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.crystalWhite.opacity(0.9))
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}