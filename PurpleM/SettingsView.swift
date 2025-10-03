//
//  SettingsView.swift
//  PurpleM
//
//  应用设置页面 - 增强版AI配置
//

import SwiftUI

// AI模式已统一为增强版，不再需要枚举

// 设置管理器
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // AI模式已固定为增强版，不再需要切换
    
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
    
    // 流式响应始终启用，无需设置
    
    private init() {
        // 加载保存的设置
        
        self.enableNotifications = UserDefaults.standard.bool(forKey: "enableNotifications")
        self.enableAutoSave = UserDefaults.standard.bool(forKey: "enableAutoSave")
        
        // 流式响应始终启用
    }
}

// 通知名称扩展（AI模式切换已移除）

struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @Environment(\.presentationMode) var presentationMode
    // AI模式信息已移除
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
                            
                            // AI状态显示
                            GlassmorphicCard {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.mysticPink)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("增强版AI")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.crystalWhite)
                                        
                                        Text("集成知识库、情绪识别、场景管理")
                                            .font(.system(size: 12))
                                            .foregroundColor(.moonSilver.opacity(0.8))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                .padding(.vertical, 8)
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
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "waveform")
                                            .font(.system(size: 20))
                                            .foregroundColor(.mysticPink)
                                        Text("流式响应")
                                            .font(.system(size: 16))
                                            .foregroundColor(.crystalWhite)
                                        Spacer()
                                        Text("已启用")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.starGold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(Color.starGold.opacity(0.2))
                                            )
                                    }
                                    Text("AI回复将逐字显示，提供流畅的对话体验")
                                        .font(.system(size: 12))
                                        .foregroundColor(.moonSilver.opacity(0.8))
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
                                        Text("增强版")
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
                                    // 版本号
                                    HStack {
                                        Text("版本")
                                            .font(.system(size: 14))
                                            .foregroundColor(.moonSilver)
                                        Spacer()
                                        Text("1.0.0")
                                            .font(.system(size: 14))
                                            .foregroundColor(.crystalWhite)
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
                        
                        // 知识库管理按钮（不起眼的样式）
                        VStack(spacing: 10) {
                            Divider()
                                .background(Color.moonSilver.opacity(0.1))
                                .padding(.horizontal)
                            
                            Button(action: {
                                showBookUpload = true
                            }) {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 14))
                                    Text("知识库管理")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(.moonSilver.opacity(0.5))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.05))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 10)
                        
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

// AI模式信息视图已移除 - 使用统一的增强版AI

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